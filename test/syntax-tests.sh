#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Syntax Validation Tests
# 
# This script validates bash syntax for all bash scripts in the project.
########################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test counters - ensure they're properly initialized
declare -i TOTAL_TESTS=0
declare -i PASSED_TESTS=0
declare -i FAILED_TESTS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test bash syntax
test_bash_syntax() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing syntax: $relative_path"
    fi
    
    if bash -n "$file" 2>/dev/null; then
        log_success "Syntax OK: $relative_path"
        return 0
    else
        log_error "Syntax FAILED: $relative_path"
        # Show the actual syntax error for debugging
        echo -e "${RED}Error details:${NC}"
        bash -n "$file" 2>&1 | sed 's/^/  /'
        return 1
    fi
}

# Test ShellCheck if available (informational only)
test_shellcheck() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    
    if ! command -v shellcheck >/dev/null 2>&1; then
        return 0  # Skip if shellcheck not available
    fi
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Running ShellCheck: $relative_path"
    fi
    
    # Run shellcheck with reasonable exclusions for this project
    # Note: This is informational only and doesn't affect test results
    if shellcheck -e SC1090,SC1091,SC2034,SC2154 "$file" >/dev/null 2>&1; then
        if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
            echo -e "${GREEN}  ShellCheck: No issues found${NC}"
        fi
        return 0
    else
        echo -e "${YELLOW}  ShellCheck: Found style suggestions (informational only)${NC}"
        if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
            shellcheck -e SC1090,SC1091,SC2034,SC2154 "$file" 2>&1 | head -5 | sed 's/^/    /'
        fi
        return 0  # Don't fail on shellcheck warnings
    fi
}

# Find all bash scripts
find_bash_scripts() {
    local scripts=()
    
    # Main scripts
    scripts+=("$PROJECT_ROOT/chief.sh")
    
    # Library files
    if [[ -f "$PROJECT_ROOT/libs/core/chief_library.sh" ]]; then
        scripts+=("$PROJECT_ROOT/libs/core/chief_library.sh")
    fi
    
    # Core plugin files (user plugins are intentionally excluded from syntax testing)
    while IFS= read -r -d '' file; do
        scripts+=("$file")
    done < <(find "$PROJECT_ROOT/libs/core/plugins" -name "*_chief-plugin.sh" -type f -print0 2>/dev/null || true)
    
    # Template files excluded (they're meant to be customized, not tested as-is)
    # Commented out: find "$PROJECT_ROOT/templates" -name "*.sh" -type f -print0
    
    # Tool scripts (still included in syntax tests since syntax validation is useful)
    while IFS= read -r -d '' file; do
        scripts+=("$file")
    done < <(find "$PROJECT_ROOT/tools" -name "*.sh" -type f -print0 2>/dev/null || true)
    
    # Git extra scripts
    while IFS= read -r -d '' file; do
        scripts+=("$file")
    done < <(find "$PROJECT_ROOT/libs/extras/git" -name "*.sh" -type f -print0 2>/dev/null || true)
    
    printf '%s\n' "${scripts[@]}"
}

# Main execution
main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}      SYNTAX VALIDATION TESTS${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    log_info "Discovering bash scripts in project..."
    
    local scripts=()
    while IFS= read -r line; do
        if [[ -f "$line" ]]; then
            scripts+=("$line")
        fi
    done < <(find_bash_scripts)
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        log_error "No bash scripts found to test"
        exit 1
    fi
    
    log_info "Found ${#scripts[@]} bash script(s) to validate"
    echo ""
    
    # Test each script
    local failed_files=()
    
    for script in "${scripts[@]}"; do
        if ! test_bash_syntax "$script"; then
            failed_files+=("$script")
        fi
        
        # Also run shellcheck if available (informational only)
        if command -v shellcheck >/dev/null 2>&1; then
            test_shellcheck "$script"
        fi
    done
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       SYNTAX VALIDATION SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Total Scripts:${NC} ${#scripts[@]}"
    echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
    echo -e "${RED}Failed:${NC} $FAILED_TESTS"
    echo ""
    
    if [[ ${#failed_files[@]} -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL SYNTAX TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}❌ Syntax errors found in ${#failed_files[@]} file(s):${NC}"
        for file in "${failed_files[@]}"; do
            echo -e "${RED}  - ${file#$PROJECT_ROOT/}${NC}"
        done
        return 1
    fi
}

# Show help
show_help() {
    echo "Chief Test Suite - Syntax Validation Tests"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  -v, --verbose Enable verbose output"
    echo ""
    echo "Environment Variables:"
    echo "  CHIEF_TEST_VERBOSE  Enable verbose output (same as -v)"
    echo ""
    echo "This script validates bash syntax for all bash scripts in the Chief project."
    echo "It uses 'bash -n' for syntax checking and optionally ShellCheck for static analysis."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            export CHIEF_TEST_VERBOSE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
