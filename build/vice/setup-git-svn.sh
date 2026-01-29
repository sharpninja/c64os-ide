#!/bin/bash
#
# setup-git-svn.sh
#
# Setup git-svn mirror and pull VICE source code from SourceForge SVN
# Applies patches after successful checkout
#
# Usage: ./setup-git-svn.sh [--clean] [--verbose]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VICE_GIT_DIR="$PROJECT_ROOT/third_party/vice"
VICE_DIR="$VICE_GIT_DIR/vice"
PATCH_DIR="$SCRIPT_DIR"
SVN_REPO="https://svn.code.sf.net/p/vice-emu/code/trunk"
GIT_SVN_AUTHOR="vice-emu=VICE Emulator Team <info@vice-emu.org>"

# Options
CLEAN=0
VERBOSE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

show_help() {
    cat << EOF
Usage: ./setup-git-svn.sh [OPTIONS]

Options:
    --clean     Remove existing git-svn mirror and start fresh
    --verbose   Show detailed output
    --help      Show this help message

Description:
    This script sets up a git-svn mirror of the VICE emulator source code
    from SourceForge and applies necessary patches for C64OS IDE builds.

    If the mirror already exists, it will be updated using 'git svn fetch'.
    If --clean is specified, the existing mirror will be removed and recreated.

Examples:
    # Initial setup (will take several minutes)
    ./setup-git-svn.sh

    # Update existing mirror
    ./setup-git-svn.sh --verbose

    # Clean and rebuild mirror
    ./setup-git-svn.sh --clean

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

log_info "VICE git-svn Setup Script"
log_info "Project Root: $PROJECT_ROOT"

# Check if git is available
if ! command -v git &> /dev/null; then
    log_error "Git is not installed or not in PATH"
    exit 1
fi

GIT_VERSION=$(git --version)
log_info "Found: $GIT_VERSION"

# Check if git-svn is available
if ! git svn --version &> /dev/null; then
    log_warning "git-svn is NOT available on this system"
    log_info "Checking for cached VICE source..."
    
    if [ -d "$VICE_DIR" ]; then
        log_success "Using cached VICE source at: $VICE_DIR"
        log_info "Applying patches to cached source..."
        
        PATCH_SCRIPT="$PATCH_DIR/apply_vice_patches.sh"
        if [ -f "$PATCH_SCRIPT" ]; then
            if chmod +x "$PATCH_SCRIPT" && "$PATCH_SCRIPT" $([ "$VERBOSE" -eq 1 ] && echo "--verbose"); then
                log_success "Patches applied successfully to cached source"
                log_success "VICE setup complete (using cache)"
                exit 0
            else
                log_error "Failed to apply patches to cached source"
                exit 1
            fi
        else
            log_error "Patch script not found: $PATCH_SCRIPT"
            exit 1
        fi
    else
        log_error "git-svn is not available and no cached VICE source found"
        log_error "Install git-svn using your package manager:"
        log_error "  Ubuntu/Debian: sudo apt-get install git-svn"
        log_error "  macOS: brew install git-svn"
        log_error "  Fedora: sudo dnf install perl-Git-SVN"
        exit 1
    fi
fi

# Create third_party directory if needed
if [ ! -d "$PROJECT_ROOT/third_party" ]; then
    log_info "Creating third_party directory..."
    mkdir -p "$PROJECT_ROOT/third_party"
fi

# Handle --clean flag
if [ "$CLEAN" -eq 1 ]; then
    if [ -d "$VICE_GIT_DIR" ]; then
        log_warning "Removing existing git-svn mirror at: $VICE_GIT_DIR"
        rm -rf "$VICE_GIT_DIR"
        log_success "Removed existing mirror"
    fi
fi

# Initialize or update git-svn mirror
if [ ! -d "$VICE_GIT_DIR" ]; then
    log_info "Initializing git-svn mirror from: $SVN_REPO"
    log_info "This may take several minutes on first run..."

    cd "$PROJECT_ROOT/third_party"

    # Clone from SVN with git-svn
    # Note: Only pull trunk to avoid excessive download
    START_TIME=$(date +%s)

    if git svn clone -s \
        -A "$GIT_SVN_AUTHOR" \
        -q \
        "$SVN_REPO" \
        vice; then

        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))

        log_success "Git-SVN mirror initialized successfully"
        log_info "Initial clone took: $((DURATION / 60)) minutes $((DURATION % 60)) seconds"
    else
        log_error "Failed to initialize git-svn mirror"
        exit 1
    fi
else
    log_info "Git-SVN mirror already exists at: $VICE_GIT_DIR"
    log_info "Updating from SVN..."

    cd "$VICE_GIT_DIR"

    START_TIME=$(date +%s)

    if git svn fetch -q; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))

        log_success "Git-SVN update completed"
        log_info "Fetch took: $DURATION seconds"
    else
        log_error "Failed to update git-svn mirror"
        exit 1
    fi
fi

# Verify VICE directory exists
if [ ! -d "$VICE_DIR" ]; then
    log_error "VICE source directory not found at: $VICE_DIR"
    exit 1
fi

log_success "VICE source available at: $VICE_DIR"

# Apply patches
log_info "Applying VICE patches..."

PATCH_SCRIPT="$PATCH_DIR/apply_vice_patches.sh"
if [ ! -f "$PATCH_SCRIPT" ]; then
    log_error "Patch application script not found: $PATCH_SCRIPT"
    exit 1
fi

if chmod +x "$PATCH_SCRIPT" && "$PATCH_SCRIPT" $([ "$VERBOSE" -eq 1 ] && echo "--verbose"); then
    log_success "Patches applied successfully"
else
    log_error "Failed to apply patches"
    exit 1
fi

log_success "VICE git-svn setup complete!"
log_info "Source code: $VICE_DIR"
log_info "Next steps: Run the build script"
log_info "  Windows: .\\build.cmd BuildVice --Platform Windows"
log_info "  Linux:   ./build.sh BuildVice --Platform Linux"
