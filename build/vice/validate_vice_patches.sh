#!/bin/bash
#
# validate_vice_patches.sh
#
# Validates that all VICE patch files are present and correct
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

main() {
    log_info "VICE Patch Files Validation"
    log_info "============================"
    echo ""

    local errors=0

    # Check for required files
    local required_files=(
        "README.md"
        "VICE_BUILD_PATCHES.md"
        "TRACKING.md"
        "geninfocontrib_h.sh.patch"
        "Makefile.patch"
        "apply_vice_patches.sh"
        "apply_vice_patches.ps1"
    )

    log_info "Checking for required files..."
    for file in "${required_files[@]}"; do
        local path="$SCRIPT_DIR/$file"
        if [ -f "$path" ]; then
            local size=$(stat --printf="%s" "$path")
            log_success "$file ($size bytes)"
        else
            log_error "$file - NOT FOUND"
            ((errors++))
        fi
    done
    echo ""

    # Validate patch files
    log_info "Validating patch file format..."

    if [ -f "$SCRIPT_DIR/geninfocontrib_h.sh.patch" ]; then
        if grep -q "^---.*geninfocontrib_h.sh" "$SCRIPT_DIR/geninfocontrib_h.sh.patch" && \
           grep -q "^+++.*geninfocontrib_h.sh" "$SCRIPT_DIR/geninfocontrib_h.sh.patch"; then
            log_success "geninfocontrib_h.sh.patch format valid"
        else
            log_error "geninfocontrib_h.sh.patch format invalid"
            ((errors++))
        fi
    fi

    if [ -f "$SCRIPT_DIR/Makefile.patch" ]; then
        if grep -q "^---.*Makefile" "$SCRIPT_DIR/Makefile.patch" && \
           grep -q "^+++.*Makefile" "$SCRIPT_DIR/Makefile.patch"; then
            log_success "Makefile.patch format valid"
        else
            log_error "Makefile.patch format invalid"
            ((errors++))
        fi
    fi
    echo ""

    # Validate patch content
    log_info "Validating patch content..."

    if grep -q "test -f coreteam.tmp &&" "$SCRIPT_DIR/geninfocontrib_h.sh.patch"; then
        log_success "geninfocontrib_h.sh.patch contains expected changes"
    else
        log_error "geninfocontrib_h.sh.patch missing expected changes"
        ((errors++))
    fi

    if grep -q 'encoding.*iso-8859-1.*us-ascii' "$SCRIPT_DIR/Makefile.patch"; then
        log_success "Makefile.patch contains expected changes"
    else
        log_error "Makefile.patch missing expected changes"
        ((errors++))
    fi
    echo ""

    # Validate documentation
    log_info "Validating documentation..."

    local docs=("README.md" "VICE_BUILD_PATCHES.md" "TRACKING.md")
    for doc in "${docs[@]}"; do
        local path="$SCRIPT_DIR/$doc"
        if [ -f "$path" ]; then
            local lines=$(wc -l < "$path")
            if [ "$lines" -gt 10 ]; then
                log_success "$doc ($lines lines)"
            else
                log_warn "$doc is very short ($lines lines)"
            fi
        fi
    done
    echo ""

    # Validate scripts
    log_info "Validating scripts..."

    if [ -f "$SCRIPT_DIR/apply_vice_patches.sh" ]; then
        if head -1 "$SCRIPT_DIR/apply_vice_patches.sh" | grep -q "^#!/bin/bash"; then
            log_success "apply_vice_patches.sh has correct shebang"
        else
            log_warn "apply_vice_patches.sh may not be executable"
        fi

        if grep -q "main()" "$SCRIPT_DIR/apply_vice_patches.sh"; then
            log_success "apply_vice_patches.sh has main function"
        else
            log_warn "apply_vice_patches.sh structure questionable"
        fi
    fi

    if [ -f "$SCRIPT_DIR/apply_vice_patches.ps1" ]; then
        if grep -q "function Main" "$SCRIPT_DIR/apply_vice_patches.ps1" || \
           grep -q "param(" "$SCRIPT_DIR/apply_vice_patches.ps1"; then
            log_success "apply_vice_patches.ps1 has function definitions"
        else
            log_warn "apply_vice_patches.ps1 structure questionable"
        fi
    fi
    echo ""

    # Summary
    log_info "Summary"
    log_info "======="
    if [ "$errors" -eq 0 ]; then
        log_success "All validations passed!"
        log_info "VICE patch files are ready for deployment."
        return 0
    else
        log_error "$errors validation(s) failed"
        log_warn "Please review errors above."
        return 1
    fi
}

main
exit $?
