#!/bin/bash
# update name for your project
# you may have to update some code for your specific situations
# in the for entry in $RAW_INCLUDES; do loop

PROJECT_NAME="pacman"

# --- DYNAMIC DISCOVERY (including folders) ---
RAW_INCLUDES=$(grep -h "#include" *.c 2>/dev/null | tr -d '\r' | awk -F'[<">]' '{print $2}' | sed 's/\.h//g')

LDLIBS_AUTO=""

for entry in $RAW_INCLUDES; do
    lib=$(echo "$entry" | cut -d'/' -f1 | tr '[:upper:]' '[:lower:]')
    echo "🔎 Checking: $lib"

    if pkg-config --exists "$lib" 2>/dev/null; then
        LDLIBS_AUTO="$LDLIBS_AUTO $(pkg-config --libs "$lib")"
        if [[ "$lib" == "sdl2" ]]; then
            echo "   -> Adding SDL2 helper extensions"
            LDLIBS_AUTO="$LDLIBS_AUTO -lSDL2_image -lSDL2_mixer -lSDL2_ttf"
        fi
    elif [[ "$lib" == "alsa" ]]; then
        echo "   -> Mapping alsa to -lasound"
        LDLIBS_AUTO="$LDLIBS_AUTO -lasound"
    elif [[ "$lib" == "raylib" ]]; then
        LDLIBS_AUTO="$LDLIBS_AUTO -lraylib -lGL -lm -lpthread -ldl -lrt -lX11"
    fi
done

grep -qi "math.h" *.c 2>/dev/null && LDLIBS_AUTO="$LDLIBS_AUTO -lm"
LDLIBS_STR=$(echo "$LDLIBS_AUTO" | xargs -n1 | sort -u | xargs)

# --- GENERATE MAKEFILE ---
cat <<EOF > makefile
CC = clang
BASE_FLAGS = -Wall -Wextra -MMD -MP
TARGET = $PROJECT_NAME
DEBUG_TARGET = \$(TARGET)_debug
RELEASE_TARGET = \$(TARGET)_release
LDLIBS = $LDLIBS_STR

# DYNAMIC FILE LISTS
SRCS = \$(wildcard *.c)
OBJS = \$(SRCS:.c=.o)
DEPS = \$(SRCS:.c=.d)

# DEFAULT TARGET: Standard Binary
all: CFLAGS = \$(BASE_FLAGS) -O2
all: clean_objs \$(TARGET)

# DEBUG TARGET: Fixed to include DEBUG_MODE definition
debug: CFLAGS = \$(BASE_FLAGS) -g -O0 -DDEBUG_MODE
debug: clean_objs \$(DEBUG_TARGET)

# RELEASE TARGET: Lean and Mean
release: CFLAGS = \$(BASE_FLAGS) -O3 -march=znver4 -mtune=znver4 -flto
release: LDFLAGS = -s
release: clean_objs \$(RELEASE_TARGET)
	@echo "--- Archiving Production Binary ---"
	@mkdir -p /home/rob/Files/C/production_binaries/system_metrics/
	@cp \$(RELEASE_TARGET) /home/rob/Files/C/production_binaries/system_metrics/
	@echo "--- Production Archive Updated (Not Started) ---"

# Rule for Standard Binary
\$(TARGET): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(OBJS) -o \$(TARGET) \$(LDLIBS)
	@rm -f \$(OBJS) \$(DEPS)
	@echo "--- Standard Build Successful: '\$(TARGET)' preserved ---"

# Rule for Debug Binary
\$(DEBUG_TARGET): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(OBJS) -o \$(DEBUG_TARGET) \$(LDLIBS)
	@rm -f \$(OBJS) \$(DEPS)
	@echo "--- Debug Build Successful: '\$(DEBUG_TARGET)' preserved ---"

# Rule for Release Binary
\$(RELEASE_TARGET): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(LDFLAGS) \$(OBJS) -o \$(RELEASE_TARGET) \$(LDLIBS)
	@rm -f \$(OBJS) \$(DEPS)
	@echo "--- Release Build Successful: '\$(RELEASE_TARGET)' is lean and mean ---"

-include \$(DEPS)

%.o: %.c
	\$(CC) \$(CFLAGS) -c $< -o \$@

# CLEANUP
clean:
	rm -f \$(TARGET) \$(DEBUG_TARGET) \$(RELEASE_TARGET) \$(OBJS) \$(DEPS)

clean_objs:
	@rm -f \$(OBJS) \$(DEPS)

rebuild: clean all

.PHONY: all clean rebuild debug release clean_objs
EOF

echo "✅ Smart Makefile generated for $PROJECT_NAME"
echo "👉 Linker Flags: $LDLIBS_STR"
