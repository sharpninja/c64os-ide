#!/usr/bin/env bash
#
# Run the built x64sc from the VICE source tree (no install required).
# Uses -directory so ROMs, keymaps, shaders, and GTK resources are found.
#
# Usage: ./run-x64sc.sh [x64sc options...]
#
# Optional env vars:
#   VICE_QUIET=1   - Use dummy sound and reduce log noise (for WSL/headless-friendly runs)
#   VICE_DEBUG=1   - Pass -debug for verbose logs
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VICE_ROOT="${SCRIPT_DIR}/../../third_party/vice/vice"
VICE_SRC="${VICE_ROOT}/src"
VICE_DATA="${VICE_ROOT}/data"
X64SC="${VICE_SRC}/x64sc"

if [ ! -x "$X64SC" ]; then
    echo "Error: x64sc not found or not executable: $X64SC" >&2
    echo "Build VICE first (e.g. from ${VICE_ROOT}: ./autogen.sh && ./configure && make -j\$(nproc))" >&2
    exit 1
fi

if [ ! -d "$VICE_DATA/C64" ]; then
    echo "Error: VICE data directory not found: $VICE_DATA" >&2
    exit 1
fi

# Base: data directory so ROMs, keymaps, shaders, GTK resources are found
EXTRA_OPTS=()

# Reduce runtime errors on WSL / environments without ALSA or /dev/input
if [ -n "${VICE_QUIET:-}" ]; then
    EXTRA_OPTS+=(-sounddev dummy)
    EXTRA_OPTS+=(-loglimit 0)
fi

# Optional debug logging
if [ -n "${VICE_DEBUG:-}" ]; then
    EXTRA_OPTS+=(-debug)
fi

exec "$X64SC" -directory "$VICE_DATA" "${EXTRA_OPTS[@]}" "$@"
