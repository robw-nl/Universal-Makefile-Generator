#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# @file makefile_gen.sh
# @brief Modular, State-Cached, Self-Healing Build Generator for C Projects.
# -----------------------------------------------------------------------------
set -uo pipefail

# --- Global Configuration ---
PROJECT_NAME=$(basename "$(dirname "$PWD")")
PKG_CONFIG=${PKG_CONFIG:-pkg-config}
STATE_FILE=".source/.makefile_state"
LEDGER_FILE=".source/daily_ledger.md"
LEDGER_DATE_FILE=".source/.ledger_date"
TMP_MAKEFILE=""
CANDIDATE_HASH=""

##
# @brief Cleans up temporary files on exit or interruption.
##
cleanup_temp() {
    [[ -n "$TMP_MAKEFILE" && -f "$TMP_MAKEFILE" ]] && rm -f "$TMP_MAKEFILE"
}
trap cleanup_temp EXIT INT TERM

declare -A LIB_MAP=()
declare -A DIRECT_LIB_MAP=()
declare -A PKG_EXISTS_MAP=()

# Global State Variables
RAW_INCLUDES=""
UNIQUE_PKGS=""
UNIQUE_DIRECT=""
dC_THREAD_FLAG=""
CFLAGS_STR=""
LDLIBS_STR=""
CPPCHECK_EXTRAS=""

# --- Functions ---

##
# @brief Initializes associative arrays with built-in defaults, then overlays
#        global and local .cbt_dict files if present.
##
init_maps() {
    # Built-in fallback mappings for container / clean-room environments
    LIB_MAP=(
        ["gtk"]="gtk4"
        ["gdk"]="gtk4"
        ["gsk"]="gtk4"
        ["glib"]="glib-2.0"
        ["glib-object"]="gobject-2.0"
        ["gio"]="gio-2.0"
        ["gmodule"]="gmodule-2.0"
        ["graphene"]="graphene-gobject-1.0"
        ["cairo"]="cairo"
        ["pango"]="pango"
        ["pangocairo"]="pangocairo"
        ["gdk-pixbuf"]="gdk-pixbuf-2.0"
        ["avcodec"]="libavcodec"
        ["avformat"]="libavformat"
        ["avutil"]="libavutil"
        ["swscale"]="libswscale"
        ["swresample"]="libswresample"
        ["samplerate"]="samplerate"
        ["rubberband-c"]="rubberband"
        ["rubberband"]="rubberband"
        ["sndfile"]="sndfile"
        ["jack"]="jack"
        ["fftw3"]="fftw3"
        ["archive"]="libarchive"
        ["archive_entry"]="libarchive"
        ["vulkan"]="vulkan"
        ["asoundlib"]="alsa"
        ["pulse"]="libpulse"
        ["SDL"]="sdl2"
        ["SDL2"]="sdl2"
    )

    DIRECT_LIB_MAP=(
        ["math"]="-lm"
        ["complex"]="-lm"
        ["fenv"]="-lm"
        ["tgmath"]="-lm"
        ["pthread"]="-lpthread"
        ["dlfcn"]="-ldl"
        ["mman"]="-lrt"
        ["shm"]="-lrt"
    )

    local GLOBAL_DICT="$HOME/.config/cbt/cbt_dict"
    local dict key val

    for dict in "$GLOBAL_DICT" ".cbt_dict"; do
        if [[ -f "$dict" ]]; then
            while IFS='=' read -r key val || [[ -n "$key" ]]; do
                [[ -z "$key" || "$key" == \#* ]] && continue
                if [[ "$val" == -* ]]; then
                    DIRECT_LIB_MAP["$key"]="$val"
                else
                    LIB_MAP["$key"]="$val"
                fi
            done < "$dict"
        fi
    done
}

##
# @brief Scans project for source files and unique #include directives in a single awk pass.
##
scan_dependencies() {
    RAW_INCLUDES=$(awk -F'[<">]' '
        /^[[:space:]]*#[[:space:]]*include[[:space:]]*[<"]/ {
            inc = $2
            sub(/\r$/, "", inc)
            sub(/\.h$/, "", inc)
            if (inc != "") print inc
        }
    ' ./*.c ./*.h 2>/dev/null | sort -u)
}

##
# @brief Evaluates project and OS/container state before heavy pkg-config resolution.
# @return 0 if cached state is valid and outputs exist (fast-path skip), 1 if rebuild needed.
##
check_state() {
    local SRCS
    SRCS=$(printf '%s ' ./*.c resources/*.gresource.xml 2>/dev/null)

    local CBT_PRESENT="0"
    [[ -f "ledger.mk" ]] && CBT_PRESENT="1"

    local DEPS_CONTENT="none"
    [[ -f ".cbt_deps" ]] && DEPS_CONTENT=$(<".cbt_deps")

    local DICT_CONTENT="none"
    [[ -f ".cbt_dict" ]] && DICT_CONTENT=$(<".cbt_dict")

    local GLOBAL_DICT_CONTENT="none"
    [[ -f "$HOME/.config/cbt/cbt_dict" ]] && GLOBAL_DICT_CONTENT=$(<"$HOME/.config/cbt/cbt_dict")

    local ENV_ID="unknown"
    [[ -f "/etc/os-release" ]] && ENV_ID=$(<"/etc/os-release")

    local SCRIPT_MTIME
    SCRIPT_MTIME=$(stat -c%Y "$0" 2>/dev/null || echo "0")

    local STATE_STRING="ENV:${ENV_ID}|SRCS:${SRCS}|INC:${RAW_INCLUDES}|CBT:${CBT_PRESENT}|DEPS:${DEPS_CONTENT}|DICT:${DICT_CONTENT}|GDICT:${GLOBAL_DICT_CONTENT}|SCRIPT:${SCRIPT_MTIME}"
    CANDIDATE_HASH=$(printf '\%s' "$STATE_STRING" | md5sum | awk '{print $1}')

    if [[ -f "$STATE_FILE" && -f "makefile" && -f "compile_flags.txt" ]]; then
        local SAVED_HASH
        SAVED_HASH=$(<"$STATE_FILE")
        if [[ "$CANDIDATE_HASH" == "$SAVED_HASH" ]]; then
            return 0
        fi
    fi
    return 1
}

##
# @brief Saves the verified state hash after successful makefile generation.
##
commit_state() {
    mkdir -p .source || return 1
    [[ -n "$CANDIDATE_HASH" ]] && printf '%s\n' "$CANDIDATE_HASH" > "$STATE_FILE"
}

##
# @brief Maps raw includes to system packages using a single cached pkg-config dump
#        and pure Bash string manipulation (zero loop subshells).
##
resolve_libraries() {
    local pkg_name
    while IFS=' ' read -r pkg_name _; do
        [[ -n "$pkg_name" ]] && PKG_EXISTS_MAP["$pkg_name"]=1
    done < <($PKG_CONFIG --list-all 2>/dev/null)

    local -A seen_pkgs=()
    local -A seen_direct=()
    local -a valid_pkgs_arr=()
    local -a direct_libs_arr=()
    local entry header prefix_dir lib_key dir_key lib dep

    for entry in $RAW_INCLUDES; do
        header="${entry##*/}"
        prefix_dir="${entry%%/*}"
        lib_key="${header,,}"
        dir_key="${prefix_dir,,}"

        case "$entry" in
            libavcodec/*)    lib="libavcodec" ;;
            libavformat/*)   lib="libavformat" ;;
            libavutil/*)     lib="libavutil" ;;
            libswscale/*)    lib="libswscale" ;;
            libswresample/*) lib="libswresample" ;;
            *)
                if [[ -n "${LIB_MAP[$lib_key]+x}" ]]; then
                    lib="${LIB_MAP[$lib_key]}"
                elif [[ "$prefix_dir" != "$entry" && -n "${LIB_MAP[$dir_key]+x}" ]]; then
                    lib="${LIB_MAP[$dir_key]}"
                else
                    lib="$lib_key"
                fi
                ;;
        esac

        if [[ -n "${PKG_EXISTS_MAP[$lib]+x}" ]] || $PKG_CONFIG --exists "$lib" 2>/dev/null; then
            PKG_EXISTS_MAP["$lib"]=1
            if [[ -z "${seen_pkgs[$lib]+x}" ]]; then
                seen_pkgs["$lib"]=1
                valid_pkgs_arr+=("$lib")
            fi
        elif [[ -n "${DIRECT_LIB_MAP[$lib_key]+x}" ]]; then
            local dlib="${DIRECT_LIB_MAP[$lib_key]}"
            if [[ -z "${seen_direct[$dlib]+x}" ]]; then
                seen_direct["$dlib"]=1
                direct_libs_arr+=("$dlib")
            fi
            [[ "$lib_key" == "pthread" ]] && dC_THREAD_FLAG="-pthread"
        fi
    done

    if [[ -f ".cbt_deps" ]]; then
        local explicit_deps
        explicit_deps=$(<".cbt_deps")
        for dep in $explicit_deps; do
            if [[ -n "${PKG_EXISTS_MAP[$dep]+x}" ]] || $PKG_CONFIG --exists "$dep" 2>/dev/null; then
                PKG_EXISTS_MAP["$dep"]=1
                if [[ -z "${seen_pkgs[$dep]+x}" ]]; then
                    seen_pkgs["$dep"]=1
                    valid_pkgs_arr+=("$dep")
                fi
            else
                if [[ -z "${seen_direct[$dep]+x}" ]]; then
                    seen_direct["$dep"]=1
                    direct_libs_arr+=("$dep")
                fi
            fi
        done
    fi

    if (( ${#valid_pkgs_arr[@]} > 0 )); then
        readarray -t sorted_pkgs < <(printf '%s\n' "${valid_pkgs_arr[@]}" | sort -u)
        UNIQUE_PKGS="${sorted_pkgs[*]}"
    fi

    if (( ${#direct_libs_arr[@]} > 0 )); then
        readarray -t sorted_direct < <(printf '%s\n' "${direct_libs_arr[@]}" | sort -u)
        UNIQUE_DIRECT="${sorted_direct[*]}"
    fi
}

##
# @brief Self-heals the CBT tracking environment if missing.
##
bootstrap_cbt() {
    if [[ ! -d ".source" || ! -f "ledger.mk" || ! -f ".source/commit_ledger.awk" ]]; then
        echo "Bootstrapping CBT Tracking Environment..."
        mkdir -p .source .source_cache

        cat << 'EOF' > .source/.gitignore
*
EOF

        cat << 'AWK_EOF' > .source/commit_ledger.awk
BEGIN {
    "date +%H:%M:%S" | getline cur_time; close("date +%H:%M:%S")
    print "\n## Transaction: " tx_id " | Time: " cur_time
    if (task != "") { print "**Task:** " task }
}
/^--- / {
    file = $0;
    sub(/^--- \.source_cache\//, "", file);
    sub(/[ \t]+.*$/, "", file);

    n = split(file, parts, ".");
    ext = parts[n];
    if (ext == "c" || ext == "h") lang = "c";
    else if (ext == "sh") lang = "bash";
    else if (ext == "xml" || ext == "ui") lang = "xml";
    else lang = "text";

    next;
}
/^\+\+\+ / { next; }
/^@@ / {
    if (in_chunk) flush();
    in_chunk = 1; old_buf = ""; new_buf = "";

    func_ctx = "";
    idx = index($0, " @@ ");
    if (idx > 0) {
        func_ctx = substr($0, idx + 4);
        sub(/^[ \t]+/, "", func_ctx);
    }

    header = "\n### File: " file;
    if (func_ctx != "") header = header " | In: `" func_ctx "`";
    print header;

    next;
}
{
    if (!in_chunk) next;
    char = substr($0, 1, 1);
    line = substr($0, 2);
    if (char == " ") { old_buf = old_buf line "\n"; new_buf = new_buf line "\n"; }
    else if (char == "-") { old_buf = old_buf line "\n"; }
    else if (char == "+") { new_buf = new_buf line "\n"; }
}
END { if (in_chunk) flush(); }
function flush() {
    print "**--- OLD CODE ---**\n```" lang "\n" old_buf "```";
    print "**--- NEW CODE ---**\n```" lang "\n" new_buf "```";
}
AWK_EOF

        cat << 'LEDGER_EOF' > ledger.mk
# -----------------------------------------------------------------------------
# CBT Ledger Tracking Module
# -----------------------------------------------------------------------------
CBT_EXCLUDES = --exclude='.source*' --exclude='*.o' --exclude='*.d' --exclude='resources.c' --exclude='$(TARGET)*' --exclude='*.tmp' --exclude='*.log' --exclude='makefile' --exclude='ledger.mk' --exclude='compile_flags.txt' --exclude='.cbt_task'

snapshot_prep:
	@mkdir -p .source .source_cache
	@TMP_DIFF="/tmp/qjams_pending.diff"; \
	if [ -z "$$(ls -A .source_cache 2>/dev/null)" ]; then \
		echo "--- Initializing source cache (skipping initial diff) ---"; \
		rsync -a --delete $(CBT_EXCLUDES) ./ .source_cache/; \
		rm -f "$$TMP_DIFF"; \
	else \
		diff -U 5 -p -rN $(CBT_EXCLUDES) .source_cache/ ./ > "$$TMP_DIFF" || true; \
	fi

commit_ledger:
	@LEDGER=".source/daily_ledger.md"; \
	TMP_DIFF="/tmp/qjams_pending.diff"; \
	if [ -s "$$TMP_DIFF" ]; then \
		echo "--- Code changes verified. Committing to $$LEDGER ---"; \
		TX_ID="CBT-$$(date +%Y%m%d-%H%M%S)"; \
		TASK_VAL=""; \
		if [ -f .cbt_task ]; then TASK_VAL="$$(cat .cbt_task | xargs)"; fi; \
		awk -v tx_id="$$TX_ID" -v task="$$TASK_VAL" -f .source/commit_ledger.awk "$$TMP_DIFF" >> "$$LEDGER"; \
		rm -f "$$TMP_DIFF"; \
		rsync -a --delete $(CBT_EXCLUDES) ./ .source_cache/; \
	fi

.PHONY: snapshot_prep commit_ledger
LEDGER_EOF
    fi
}

##
# @brief Resets the code-change ledger once per local calendar day on first execution.
##
reset_daily_ledger() {
    mkdir -p .source || return 1
    local TODAY
    printf -v TODAY '%(%Y%m%d)T' -1

    # Fast check before acquiring flock subshell
    if [[ -f "$LEDGER_DATE_FILE" && "$(<"$LEDGER_DATE_FILE")" == "$TODAY" ]]; then
        return 0
    fi

    (
        if command -v flock >/dev/null 2>&1; then
            flock -x 9 || exit 1
        fi

        local LAST_RESET=""
        [[ -f "$LEDGER_DATE_FILE" ]] && LAST_RESET=$(<"$LEDGER_DATE_FILE")

        if [[ "$LAST_RESET" != "$TODAY" ]]; then
            local TMP_LEDGER
            TMP_LEDGER=$(mktemp ".source/.daily_ledger.XXXXXX") || exit 1
            if : > "$TMP_LEDGER" && mv -f "$TMP_LEDGER" "$LEDGER_FILE"; then
                printf '%s\n' "$TODAY" > "$LEDGER_DATE_FILE"
            else
                rm -f "$TMP_LEDGER"
                exit 1
            fi
        fi
    ) 9> ".source/.ledger.lock"
}

##
# @brief Outputs the compile commands configuration for Clangd/Kate only when changed.
##
generate_compile_flags() {
    echo "Generating compile_flags.txt for Kate/clangd..."
    {
        echo "-Wall"
        echo "-Wextra"
        printf '%s\n' $CFLAGS_STR
    } > compile_flags.txt
}

##
# @brief Executes pkg-config once, generates candidate makefile, and updates if changed.
##
generate_makefile() {
    local CFLAGS_AUTO=""
    local LDLIBS_AUTO=""

    if [[ -n "$UNIQUE_PKGS" ]]; then
        CFLAGS_AUTO=$($PKG_CONFIG --cflags $UNIQUE_PKGS 2>/dev/null)
        LDLIBS_AUTO=$($PKG_CONFIG --libs $UNIQUE_PKGS 2>/dev/null)
    fi

    read -r CFLAGS_STR <<< "$CFLAGS_AUTO"
    read -r LDLIBS_STR <<< "$LDLIBS_AUTO $UNIQUE_DIRECT"

    CPPCHECK_EXTRAS=""
    local lib
    for lib in sdl2 opengl; do
        if [[ "${LDLIBS_STR,,}" == *"$lib"* ]]; then
            CPPCHECK_EXTRAS+=" --library=$lib"
        fi
    done

    local CBT_INCLUDE=""
    local CBT_HOOK=""
    if [[ -f "ledger.mk" ]]; then
        CBT_INCLUDE="-include ledger.mk"
        CBT_HOOK="@\$(MAKE) --no-print-directory snapshot_prep commit_ledger"
    fi

    mkdir -p .source || return 1
    TMP_MAKEFILE=$(mktemp ".source/.makefile.tmp.XXXXXX") || return 1

cat <<EOF > "$TMP_MAKEFILE" || return 1
# -----------------------------------------------------------------------------
# @file makefile
# @brief Multi-tier build system supporting Native (AVX-512) and Universal (v3) binaries.
# -----------------------------------------------------------------------------
CC ?= clang
PKG_CONFIG ?= pkg-config
BASE_FLAGS = -Wall -Wextra -MMD -MP $dC_THREAD_FLAG $CFLAGS_STR
TARGET ?= $PROJECT_NAME
DEBUG_TARGET = \$(TARGET)_debug
OPTIMIZED_TARGET = \$(TARGET)_optimized
DEFAULT_TARGET = \$(TARGET)_default
LDLIBS = $LDLIBS_STR

# DYNAMIC FILE LISTS (With Auto-Detected Resources)
SRCS = \$(filter-out resources.c,\$(wildcard *.c))
TMP_DIR = /tmp/\$(TARGET)_objs
DEPS = \$(patsubst %.c,\$(TMP_DIR)/%.d,\$(SRCS))

# Conditionally configure resource variables if the XML file exists
GRESOURCE_XML = \$(wildcard resources/*.gresource.xml)
ifneq (\$(GRESOURCE_XML),)
    RES_OBJ = \$(TMP_DIR)/resources.o
    RES_CLEAN = resources.c
else
    RES_OBJ =
    RES_CLEAN =
endif

OBJS = \$(patsubst %.c,\$(TMP_DIR)/%.o,\$(SRCS)) \$(RES_OBJ)

# Default: compile optimized native binary for local development
all: optimized

$CBT_INCLUDE

debug: CFLAGS = \$(BASE_FLAGS) -g -O0 -DDEBUG_MODE
debug: clean_objs \$(DEBUG_TARGET)

optimized: CFLAGS = \$(BASE_FLAGS) -O3 -march=native -flto
optimized: LDFLAGS = -s
optimized: clean_objs \$(OPTIMIZED_TARGET)

default: CFLAGS = \$(BASE_FLAGS) -O3 -march=x86-64-v3 -flto
default: LDFLAGS = -s
default: clean_objs \$(DEFAULT_TARGET)

both: optimized default

define STRIP_HOOK
	@if command -v objcopy >/dev/null 2>&1; then \
		echo "Nuking ISA metadata via objcopy..."; \
		objcopy --remove-section=.note.gnu.property \$@; \
	fi
	@if [ "\$(CC)" = "clang" ] || [ "\$(CC)" = "gcc" ]; then \
		echo "Applying stealth strip..."; \
		strip \$@ 2>/dev/null || true; \
	fi
endef

\$(DEBUG_TARGET): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(OBJS) -o \$@ \$(LDLIBS)
	$CBT_HOOK
	@echo "--- Debug Build Successful: '\$@' is ready ---"

\$(OPTIMIZED_TARGET): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(LDFLAGS) \$(OBJS) -o \$@ \$(LDLIBS)
	$CBT_HOOK
	\$(STRIP_HOOK)
	@echo "--- Optimized Build Successful: '\$@' is ready ---"

\$(DEFAULT_TARGET): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(LDFLAGS) \$(OBJS) -o \$@ \$(LDLIBS)
	$CBT_HOOK
	\$(STRIP_HOOK)
	@echo "--- Default Build Successful: '\$@' is ready ---"

-include \$(DEPS)

ifneq (\$(GRESOURCE_XML),)
# RESOURCE COMPILATION
UI_FILES = \$(shell find resources -type f -name '*.ui' -o -name '*.png' 2>/dev/null)

resources.c: \$(GRESOURCE_XML) \$(UI_FILES)
	glib-compile-resources \$(GRESOURCE_XML) --target=resources.c --generate-source --sourcedir=resources

\$(TMP_DIR)/resources.o: resources.c
	@mkdir -p \$(TMP_DIR)
	\$(CC) \$(CFLAGS) -c \$< -o \$@
endif

\$(TMP_DIR)/resources.o: resources.c

\$(TMP_DIR)/%.o: %.c
	@mkdir -p \$(TMP_DIR)
	\$(CC) \$(CFLAGS) -c \$< -o \$@

clean:
	rm -f \$(DEBUG_TARGET) \$(OPTIMIZED_TARGET) \$(DEFAULT_TARGET) \$(RES_CLEAN)
	rm -rf \$(TMP_DIR)

clean_objs:
	@rm -rf \$(TMP_DIR)

rebuild: clean all

check:
	@echo "--- Running Static Analysis ---"
	cppcheck --enable=all --suppress=missingIncludeSystem --inconclusive $CPPCHECK_EXTRAS ./

.PHONY: all clean rebuild debug optimized default both clean_objs check
EOF

    if [[ -f "makefile" ]] && cmp -s "$TMP_MAKEFILE" "makefile"; then
        rm -f "$TMP_MAKEFILE"
        TMP_MAKEFILE=""
        [[ ! -f "compile_flags.txt" ]] && generate_compile_flags
        return 0
    fi

    echo "Build environment changed. Generating Makefile for $PROJECT_NAME..."
    echo "  🔎 Resolving Pkg-Config: $UNIQUE_PKGS"
    mv -f "$TMP_MAKEFILE" "makefile" || return 1
    TMP_MAKEFILE=""
    generate_compile_flags
}

# --- Main Execution Flow ---
bootstrap_cbt
reset_daily_ledger
scan_dependencies

if ! check_state; then
    init_maps
    resolve_libraries
    if ! generate_makefile; then
        echo "❌ Error: makefile_gen.sh failed to generate makefile." >&2
        exit 1
    fi
    commit_state
fi
