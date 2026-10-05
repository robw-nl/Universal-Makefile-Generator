#!/bin/bash
# makefile_gen.sh - Universal Hybrid Version (Optimized)

# 1. DYNAMIC PROJECT DISCOVERY
PROJECT_NAME=$(basename "$(dirname "$PWD")")
PKG_CONFIG=${PKG_CONFIG:-pkg-config}

echo "Generating universal Makefile for: $PROJECT_NAME"

declare -A LIB_MAP=(
    ["sdl_mixer"]="SDL2_mixer"
    ["sdl_image"]="SDL2_image"
    ["sdl_ttf"]="SDL2_ttf"
    ["sdl"]="sdl2"
    ["asoundlib"]="alsa"
    ["xlib"]="x11"
    ["xutil"]="x11"
    ["wayland-client"]="wayland-client"
    ["turbojpeg"]="libturbojpeg"
    ["sndfile"]="sndfile"
    ["gtk"]="gtk4"
    ["avcodec"]="libavcodec"
    ["avformat"]="libavformat"
    ["avutil"]="libavutil"
    ["swscale"]="libswscale"
    ["swresample"]="libswresample"
    ["jack"]="jack"
    ["samplerate"]="samplerate"
    ["rubberband-c"]="rubberband fftw3f"
    ["archive"]="libarchive"
)

declare -A DIRECT_LIB_MAP=(
    ["math"]="-lm"
    ["pthread"]="-pthread"
    ["dl"]="-ldl"
    ["rt"]="-lrt"
)

RAW_INCLUDES=$(grep -h "#include" *.c *.h 2>/dev/null | tr -d '\r' | awk -F'[<">]' '{print $2}' | sed 's/\.h//g' | sort -u)

VALID_PKGS=""
DIRECT_LIBS=""
dC_THREAD_FLAG=""

# Pass 1: Collect valid libraries without generating flags yet
for entry in $RAW_INCLUDES; do
    header=$(basename "$entry")
    lib_key=$(echo "$header" | tr '[:upper:]' '[:lower:]')

    if echo "$entry" | grep -q "libavutil/"; then
        lib="libavutil"
    else
        lib=${LIB_MAP[$lib_key]:-$lib_key}
    fi

    if $PKG_CONFIG --exists "$lib" 2>/dev/null; then
        VALID_PKGS="$VALID_PKGS $lib"
    elif [ -n "${DIRECT_LIB_MAP[$lib_key]+isset}" ]; then
        DIRECT_LIBS="$DIRECT_LIBS ${DIRECT_LIB_MAP[$lib_key]}"
        [ "$lib_key" = "pthread" ] && dC_THREAD_FLAG="-pthread"
    fi
done

# Pass 2: Deduplicate the lists
UNIQUE_PKGS=$(echo "$VALID_PKGS" | tr ' ' '\n' | sort -u | xargs)
UNIQUE_DIRECT=$(echo "$DIRECT_LIBS" | tr ' ' '\n' | sort -u | xargs)

# Pass 3: Execute pkg-config exactly once to generate clean, native strings
echo "  🔎 Resolving Pkg-Config: $UNIQUE_PKGS"
CFLAGS_AUTO=$($PKG_CONFIG --cflags $UNIQUE_PKGS)
LDLIBS_AUTO=$($PKG_CONFIG --libs $UNIQUE_PKGS)

LDLIBS_STR=$(echo "$LDLIBS_AUTO $UNIQUE_DIRECT" | xargs)
CFLAGS_STR=$(echo "$CFLAGS_AUTO" | xargs)

CPPCHECK_EXTRAS=""
for lib in sdl2 opengl; do
    if echo "$LDLIBS_STR" | grep -qi "$lib"; then
        CPPCHECK_EXTRAS="$CPPCHECK_EXTRAS --library=$lib"
    fi
done

cat <<EOF > makefile
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
GRESOURCE_XML = \$(wildcard *.gresource.xml)
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

debug: CFLAGS = \$(BASE_FLAGS) -g -O0 -DDEBUG_MODE
debug: clean_objs \$(DEBUG_TARGET)

optimized: CFLAGS = \$(BASE_FLAGS) -O3 -march=native -flto
optimized: LDFLAGS = -s
optimized: clean_objs \$(OPTIMIZED_TARGET)

default: CFLAGS = \$(BASE_FLAGS) -O3 -march=x86-64-v3 -flto
default: LDFLAGS = -s
default: clean_objs \$(DEFAULT_TARGET)

both: optimized default

\$(DEBUG_TARGET): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(OBJS) -o \$(DEBUG_TARGET) \$(LDLIBS)
	@echo "--- Debug Build Successful: '\$(DEBUG_TARGET)' is ready ---"

\$(OPTIMIZED_TARGET): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(LDFLAGS) \$(OBJS) -o \$(OPTIMIZED_TARGET) \$(LDLIBS)
	@if command -v objcopy >/dev/null 2>&1; then \\
		echo "Nuking ISA metadata via objcopy..."; \\
		objcopy --remove-section=.note.gnu.property \$(OPTIMIZED_TARGET); \\
	fi
	@if [ "\$(CC)" = "clang" ] || [ "\$(CC)" = "gcc" ]; then \\
		echo "Applying stealth strip..."; \\
		strip \$(OPTIMIZED_TARGET) 2>/dev/null || true; \\
	fi
	@echo "--- Optimized Build Successful: '\$(OPTIMIZED_TARGET)' is ready ---"

\$(DEFAULT_TARGET): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(LDFLAGS) \$(OBJS) -o \$(DEFAULT_TARGET) \$(LDLIBS)
	@if command -v objcopy >/dev/null 2>&1; then \\
		echo "Nuking ISA metadata via objcopy..."; \\
		objcopy --remove-section=.note.gnu.property \$(DEFAULT_TARGET); \\
	fi
	@if [ "\$(CC)" = "clang" ] || [ "\$(CC)" = "gcc" ]; then \\
		echo "Applying stealth strip..."; \\
		strip \$(DEFAULT_TARGET) 2>/dev/null || true; \\
	fi
	@echo "--- Default Build Successful: '\$(DEFAULT_TARGET)' is ready ---"

-include \$(DEPS)

ifneq (\$(GRESOURCE_XML),)
# RESOURCE COMPILATION
# Dynamically crawls all directories to track .ui files for the dependency map
UI_FILES = \$(shell find . -type f -name '*.ui')

resources.c: \$(GRESOURCE_XML) \$(UI_FILES)
	glib-compile-resources \$(GRESOURCE_XML) --target=resources.c --generate-source

\$(TMP_DIR)/resources.o: resources.c
	@mkdir -p \$(TMP_DIR)
	\$(CC) \$(CFLAGS) -c \$< -o \$@
endif

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

echo "Generating compile_flags.txt for Kate/clangd..."
echo "-Wall" > compile_flags.txt
echo "-Wextra" >> compile_flags.txt
echo "$CFLAGS_STR" | tr ' ' '\n' | grep -v '^$' >> compile_flags.txt

echo "Smart Makefile generated for $PROJECT_NAME"
