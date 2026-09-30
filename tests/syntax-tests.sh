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

# ShellCheck at "error" severity is a real gate: errors fail the test.
# Warnings and style suggestions are shown only in verbose mode and never fail.
# SC1090/SC1091: dynamic/unfollowed source paths are expected in this project.
# --shell=bash: everything here is bash; vendored libs/extras files are sourced and have no shebang.
SHELLCHECK_EXCLUDES="SC1090,SC1091"
SHELLCHECK_OPTS_COMMON=(--shell=bash -e "$SHELLCHECK_EXCLUDES")

test_shellcheck() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"

    if ! command -v shellcheck >/dev/null 2>&1; then
        return 0  # Skipped entirely when shellcheck is not installed
    fi

    ((TOTAL_TESTS++))

    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Running ShellCheck: $relative_path"
    fi

    if shellcheck -S error "${SHELLCHECK_OPTS_COMMON[@]}" "$file" >/dev/null 2>&1; then
        log_success "ShellCheck OK: $relative_path"
        if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
            # Informational: show warnings/style hints without failing
            shellcheck -S warning --shell=bash -e "$SHELLCHECK_EXCLUDES,SC2034,SC2154" "$file" 2>&1 | head -10 | sed 's/^/    /'
        fi
        return 0
    else
        log_error "ShellCheck FAILED: $relative_path"
        echo -e "${RED}Error details:${NC}"
        shellcheck -S error "${SHELLCHECK_OPTS_COMMON[@]}" "$file" 2>&1 | head -20 | sed 's/^/  /'
        return 1
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

    # The test suite itself
    while IFS= read -r -d '' file; do
        scripts+=("$file")
    done < <(find "$PROJECT_ROOT/tests" -name "*.sh" -type f -print0 2>/dev/null || true)
    
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
    
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_warning "shellcheck not installed; static analysis skipped (bash -n only)"
    fi

    for script in "${scripts[@]}"; do
        if ! test_bash_syntax "$script"; then
            failed_files+=("$script")
        elif ! test_shellcheck "$script"; then
            failed_files+=("$script")
        fi
    done
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       SYNTAX VALIDATION SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Total Scripts:${NC} ${#scripts[@]}"
    echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${RED}Failed:${NC} $FAILED_TESTS"
    fi
    echo ""
    
    if [[ ${#failed_files[@]} -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL SYNTAX TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}❌ Syntax or ShellCheck errors found in ${#failed_files[@]} file(s):${NC}"
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
    echo "It uses 'bash -n' for syntax checking and, when installed, ShellCheck at"
    echo "error severity as a hard gate (warnings are shown only with -v and never fail)."
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
