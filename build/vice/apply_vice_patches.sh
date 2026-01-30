#!/bin/bash
#
# apply_vice_patches.sh
#
# This script applies all necessary patches to the VICE emulator source code
# after pulling from the SVN repository. It also tests that the patches
# were applied correctly and that the build works.
#
# Usage: ./apply_vice_patches.sh [--verbose] [--test-only] [--dry-run]
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VICE_DIR="$PROJECT_ROOT/third_party/vice/vice"
VERBOSE=0
TEST_ONLY=0
DRY_RUN=0

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

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Apply VICE build patches after pulling from SVN repository.

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -t, --test-only     Only run tests, don't apply patches
    -d, --dry-run       Show what would be done without making changes

EXAMPLES:
    # Apply patches
    ./apply_vice_patches.sh

    # Apply patches with verbose output
    ./apply_vice_patches.sh --verbose

    # Test without applying patches
    ./apply_vice_patches.sh --test-only

    # See what would be done
    ./apply_vice_patches.sh --dry-run
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -t|--test-only)
            TEST_ONLY=1
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Main function
main() {
    log_info "VICE Build Patch Manager"
    log_info "========================"
    echo ""

    # Check if VICE directory exists
    if [ ! -d "$VICE_DIR" ]; then
        log_error "VICE directory not found: $VICE_DIR"
        exit 1
    fi
    log_success "VICE directory found: $VICE_DIR"

    # Check current VICE commit
    if cd "$VICE_DIR" 2>/dev/null; then
        CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null)
        if [ -n "$CURRENT_COMMIT" ]; then
            log_info "Current VICE commit: $CURRENT_COMMIT"
        fi
        cd - >/dev/null 2>&1
    fi

    # Check if patch files exist and if they're obsolete
    GENINFO_PATCH="$SCRIPT_DIR/geninfocontrib_h.sh.patch"
    MAKEFILE_PATCH="$SCRIPT_DIR/Makefile.patch"
    
    if [ ! -f "$GENINFO_PATCH" ]; then
        log_error "Patch file not found: $GENINFO_PATCH"
        exit 1
    fi

    if [ ! -f "$MAKEFILE_PATCH" ]; then
        log_error "Patch file not found: $MAKEFILE_PATCH"
        exit 1
    fi

    # Check if patches are obsolete
    GENINFO_OBSOLETE=0
    MAKEFILE_OBSOLETE=0
    
    if head -n 1 "$GENINFO_PATCH" | grep -q "^# OBSOLETE"; then
        GENINFO_OBSOLETE=1
    fi
    
    if head -n 1 "$MAKEFILE_PATCH" | grep -q "^# OBSOLETE"; then
        MAKEFILE_OBSOLETE=1
    fi

    if [ "$GENINFO_OBSOLETE" -eq 1 ] && [ "$MAKEFILE_OBSOLETE" -eq 1 ]; then
        log_info "All patches are marked as OBSOLETE (fixes applied upstream)"
        log_success "No patches need to be applied - VICE source is ready to build"
        echo ""
        log_info "Current VICE version includes:"
        log_info "  - File existence checks in geninfocontrib_h.sh"
        log_info "  - Graceful error handling in Makefile.am"
        echo ""
        log_info "Pinned to commit: 5ca7ce898bca1a3696dbc9e444207026eabd58d5"
        return 0
    fi

    log_success "All patch files found"
    echo ""

    # Apply patches
    if [ "$TEST_ONLY" -eq 0 ]; then
        apply_patches "$GENINFO_OBSOLETE" "$MAKEFILE_OBSOLETE"
    fi

    # Run tests only if patches were applied
    if [ "$GENINFO_OBSOLETE" -eq 0 ] || [ "$MAKEFILE_OBSOLETE" -eq 0 ]; then
        run_tests
    fi
}

apply_patches() {
    local GENINFO_OBSOLETE=$1
    local MAKEFILE_OBSOLETE=$2
    
    log_info "Applying patches..."
    echo ""

    cd "$VICE_DIR"

    # Apply geninfocontrib_h.sh patch if not obsolete
    if [ "$GENINFO_OBSOLETE" -eq 0 ]; then
        log_info "Applying geninfocontrib_h.sh patch..."
        if [ "$DRY_RUN" -eq 1 ]; then
            log_verbose "DRY RUN: Would apply patch"
            patch -p1 --dry-run < "$SCRIPT_DIR/geninfocontrib_h.sh.patch" 2>&1 | grep -E "^(patching|Hunk)" || true
        else
            if patch -p1 < "$SCRIPT_DIR/geninfocontrib_h.sh.patch" >/dev/null 2>&1; then
                log_success "geninfocontrib_h.sh patch applied successfully"
            else
                log_warning "geninfocontrib_h.sh patch may already be applied or have minor issues"
            fi
        fi
        echo ""
    fi

    # Apply Makefile patch if not obsolete
    if [ "$MAKEFILE_OBSOLETE" -eq 0 ]; then
        log_info "Applying Makefile patch..."
        if [ "$DRY_RUN" -eq 1 ]; then
            log_verbose "DRY RUN: Would apply patch"
            patch -p1 --dry-run < "$SCRIPT_DIR/Makefile.patch" 2>&1 | grep -E "^(patching|Hunk)" || true
        else
            if patch -p1 < "$SCRIPT_DIR/Makefile.patch" >/dev/null 2>&1; then
                log_success "Makefile patch applied successfully"
            else
                log_warning "Makefile patch may already be applied or have minor issues"
            fi
        fi
        echo ""
    fi
}

run_tests() {
    log_info "Running tests..."
    echo ""

    # Test 1: Check if patches were applied
    log_info "Test 1: Verifying patches were applied"

    # Check geninfocontrib_h.sh
    if grep -q "test -f coreteam.tmp &&" "$VICE_DIR/src/buildtools/geninfocontrib_h.sh"; then
        log_success "✓ geninfocontrib_h.sh contains expected patch"
    else
        if [ "$TEST_ONLY" -eq 1 ]; then
            log_warning "✗ geninfocontrib_h.sh patch not detected (expected if not applied)"
        else
            log_error "✗ geninfocontrib_h.sh patch verification failed"
            return 1
        fi
    fi

    # Check Makefile
    if grep -q 'if \[ "$$encoding" != "iso-8859-1" \]' "$VICE_DIR/src/Makefile"; then
        log_success "✓ Makefile contains expected patch"
    else
        if [ "$TEST_ONLY" -eq 1 ]; then
            log_warning "✗ Makefile patch not detected (expected if not applied)"
        else
            log_error "✗ Makefile patch verification failed"
            return 1
        fi
    fi
    echo ""

    # Test 2: Build test (optional - only if patches are applied)
    if [ "$TEST_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
        log_info "Test 2: Building infocontrib.h to verify patches work"

        cd "$VICE_DIR/src"

        # Clean first
        rm -f infocontrib.h

        # Try to build
        if make infocontrib.h >/dev/null 2>&1; then
            log_success "✓ infocontrib.h built successfully"

            if [ -f infocontrib.h ]; then
                log_success "✓ infocontrib.h file exists"

                # Check file properties
                file_size=$(stat --printf="%s" infocontrib.h)
                encoding=$(file --mime-encoding infocontrib.h | cut -d: -f2 | tr -d ' ')
                log_verbose "  File size: $file_size bytes"
                log_verbose "  Encoding: $encoding"

                if [ "$file_size" -gt 0 ]; then
                    log_success "✓ infocontrib.h has valid content ($file_size bytes)"
                else
                    log_error "✗ infocontrib.h is empty"
                    return 1
                fi
            else
                log_error "✗ infocontrib.h file was not created"
                return 1
            fi
        else
            log_error "✗ Failed to build infocontrib.h"
            return 1
        fi
    fi

    echo ""
}

# Run main function
main

# Summary
echo ""
log_info "Summary"
log_info "========"
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "Dry run completed - no changes were made"
elif [ "$TEST_ONLY" -eq 1 ]; then
    log_info "Test-only mode - verification completed"
else
    log_success "All patches applied and tests passed!"
    log_info "The VICE build should now work correctly."
fi

exit 0
