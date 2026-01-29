#!/bin/bash
#
# download-roms.sh
#
# Downloads VICE ROM files from asig/vice-roms GitHub repository
# and places them in the VICE build output directory
#
# Usage: ./download-roms.sh [options]

set -e

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VICE_PATH="${SCRIPT_DIR}/../../third_party/vice/vice"
FORCE=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
VICE ROM Downloader
===================

Downloads VICE ROM files from asig/vice-roms GitHub repository.

Usage:
    ./download-roms.sh [options]

Options:
    -p, --path <path>    Path to VICE source directory (default: ../../third_party/vice/vice)
    -f, --force          Force re-download even if ROMs already exist
    -h, --help           Show this help message

Examples:
    ./download-roms.sh
    ./download-roms.sh --force
    ./download-roms.sh --path /path/to/vice

ROM Repository: https://github.com/asig/vice-roms
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--path)
            VICE_PATH="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=1
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check if VICE path exists
if [ ! -d "$VICE_PATH" ]; then
    error "VICE path not found: $VICE_PATH"
    error "Please specify a valid path with -p or --path"
    exit 1
fi

DATA_DIR="${VICE_PATH}/data"
ROMS_DIR="${DATA_DIR}/ROMS"
TEMP_DIR=$(mktemp -d -t vice-roms-XXXXXX)

info "VICE ROM Downloader"
info "==================="
echo ""
info "VICE path: $VICE_PATH"
info "Data directory: $DATA_DIR"
info "ROMs directory: $ROMS_DIR"
echo ""

# Check if ROMs already exist
if [ -d "$ROMS_DIR" ] && [ $FORCE -eq 0 ]; then
    info "ROMs directory already exists: $ROMS_DIR"
    ROM_COUNT=$(find "$ROMS_DIR" -type f | wc -l)
    info "Found $ROM_COUNT ROM files"
    warning "Use --force to re-download"
    exit 0
fi

# Create data directory if it doesn't exist
if [ ! -d "$DATA_DIR" ]; then
    info "Creating data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
fi

# Download the ROMs repository
REPO_URL="https://github.com/asig/vice-roms/archive/refs/heads/master.zip"
ZIP_FILE="${TEMP_DIR}/vice-roms.zip"

info "Downloading ROMs from: $REPO_URL"
echo "This may take a moment..."

if command -v wget &> /dev/null; then
    wget -q --show-progress -O "$ZIP_FILE" "$REPO_URL"
elif command -v curl &> /dev/null; then
    curl -L -# -o "$ZIP_FILE" "$REPO_URL"
else
    error "Neither wget nor curl found. Please install one of them."
    rm -rf "$TEMP_DIR"
    exit 1
fi

success "Download complete"
FILE_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
info "File size: $FILE_SIZE"

# Extract the archive
info "Extracting archive..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# Find the extracted directory
EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "vice-roms*" | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    error "Could not find extracted ROMs directory"
    rm -rf "$TEMP_DIR"
    exit 1
fi

info "Extracted to: $EXTRACTED_DIR"

# Copy ROMs to VICE data directory
info "Copying ROMs to: $ROMS_DIR"

if [ -d "$ROMS_DIR" ] && [ $FORCE -eq 1 ]; then
    info "Removing existing ROMs directory..."
    rm -rf "$ROMS_DIR"
fi

# Copy the entire directory structure
cp -r "$EXTRACTED_DIR" "$ROMS_DIR"

# Count the ROMs
ROM_COUNT=$(find "$ROMS_DIR" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$ROMS_DIR" | cut -f1)

success "ROMs installed successfully!"
echo ""
info "Statistics:"
echo "  Total ROM files: $ROM_COUNT"
echo "  Total size: $TOTAL_SIZE"
echo ""
info "ROM systems available:"

# List ROM directories
find "$ROMS_DIR" -maxdepth 1 -type d -not -path "$ROMS_DIR" | while read -r dir; do
    DIR_NAME=$(basename "$dir")
    FILE_COUNT=$(find "$dir" -type f | wc -l)
    echo "  - $DIR_NAME: $FILE_COUNT files"
done

echo ""
success "Done! VICE emulators can now use these ROMs."

# Clean up temp directory
info "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo ""
info "To use the ROMs with VICE emulators:"
echo "  Run the emulator from: ${VICE_PATH}/src/"
echo "  Example: ${VICE_PATH}/src/x64sc"
