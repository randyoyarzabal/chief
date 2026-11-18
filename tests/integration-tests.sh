#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Integration Tests
# 
# This script tests end-to-end functionality and integration scenarios.
########################################################################

set -e

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
TEMP_DIR="${TMPDIR:-/tmp}/chief-integration-tests-$$"

# Test counters - ensure they're properly initialized
declare -i TOTAL_TESTS=0
declare -i PASSED_TESTS=0
declare -i FAILED_TESTS=0

# Cleanup function
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test installation script dry run
test_install_script() {
    local install_script="$PROJECT_ROOT/tools/install.sh"
    
    if [[ ! -f "$install_script" ]]; then
        log_warning "Install script not found, skipping test"
        return 0
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing install script help"
    fi
    
    # Test that install script shows help without errors
    if "$install_script" --help >/dev/null 2>&1; then
        log_success "Install script help OK"
        return 0
    else
        log_error "Install script help FAILED"
        return 1
    fi
}

# Test uninstall script if it exists
test_uninstall_script() {
    local uninstall_script="$PROJECT_ROOT/tools/uninstall.sh"
    
    if [[ ! -f "$uninstall_script" ]]; then
        log_warning "Uninstall script not found, skipping test"
        return 0
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing uninstall script help"
    fi
    
    # Test that uninstall script shows help without errors
    if "$uninstall_script" --help >/dev/null 2>&1; then
        log_success "Uninstall script help OK"
        return 0
    else
        log_error "Uninstall script help FAILED"
        return 1
    fi
}

# Test that VERSION file exists and is valid
test_version_file() {
    local version_file="$PROJECT_ROOT/VERSION"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing VERSION file"
    fi
    
    if [[ ! -f "$version_file" ]]; then
        log_error "VERSION file not found"
        return 1
    fi
    
    # Test that VERSION file can be sourced
    if source "$version_file" 2>/dev/null; then
        # Check for required variables
        if [[ -n "${CHIEF_VERSION:-}" ]]; then
            log_success "VERSION file OK (version: ${CHIEF_VERSION})"
            return 0
        else
            log_error "VERSION file missing CHIEF_VERSION variable"
            return 1
        fi
    else
        log_error "VERSION file cannot be sourced"
        return 1
    fi
}

# Test that required directories exist
test_directory_structure() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing directory structure"
    fi
    
    local required_dirs=(
        "$PROJECT_ROOT/libs"
        "$PROJECT_ROOT/libs/core"
        "$PROJECT_ROOT/libs/core/plugins"
        "$PROJECT_ROOT/templates"
        "$PROJECT_ROOT/tools"
    )
    
    local missing_dirs=()
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing_dirs+=("${dir#$PROJECT_ROOT/}")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -eq 0 ]]; then
        log_success "Directory structure OK"
        return 0
    else
        log_error "Directory structure FAILED (missing: ${missing_dirs[*]})"
        return 1
    fi
}

# Test that core files exist
test_core_files() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing core files"
    fi
    
    local required_files=(
        "$PROJECT_ROOT/chief.sh"
        "$PROJECT_ROOT/libs/core/chief_library.sh"
        "$PROJECT_ROOT/templates/chief_config_template.sh"
        "$PROJECT_ROOT/tools/install.sh"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("${file#$PROJECT_ROOT/}")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        log_success "Core files OK"
        return 0
    else
        log_error "Core files FAILED (missing: ${missing_files[*]})"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}        INTEGRATION TESTS${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    log_info "Running integration tests..."
    echo ""
    
    # Run integration tests
    # (chief.sh --lib-only loading is covered by source-tests.sh; not repeated here)
    test_directory_structure
    test_core_files
    test_version_file
    test_install_script
    test_uninstall_script
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       INTEGRATION TEST SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${RED}Failed:${NC} $FAILED_TESTS"
    fi
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL INTEGRATION TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}❌ $FAILED_TESTS INTEGRATION TEST(S) FAILED${NC}"
        return 1
    fi
}

# Show help
show_help() {
    echo "Chief Test Suite - Integration Tests"
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
    echo "This script tests end-to-end functionality and integration scenarios:"
    echo "  - Directory structure"
    echo "  - Core file presence"
    echo "  - VERSION file validity"
    echo "  - Installation and uninstall script help"
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
