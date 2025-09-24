#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Main Test Runner
# 
# This script runs the complete test suite for the Chief project.
# It can be run locally or in GitHub Actions CI/CD pipeline.
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
TEST_DIR="$SCRIPT_DIR"
TEMP_DIR="${TMPDIR:-/tmp}/chief-tests-$$"

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

# Test runner function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "Running: $test_name"
    
    if eval "$test_command" 2>/dev/null; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Print banner
print_banner() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}         CHIEF TEST SUITE${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Project Root:${NC} $PROJECT_ROOT"
    echo -e "${BLUE}Test Directory:${NC} $TEST_DIR"
    echo -e "${BLUE}Temp Directory:${NC} $TEMP_DIR"
    echo ""
}

# Print summary
print_summary() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}           TEST SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Test Suites Run:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Suites Passed:${NC} $PASSED_TESTS"
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${RED}Suites Failed:${NC} $FAILED_TESTS"
    fi
    echo ""
    echo -e "${YELLOW}Note:${NC} Individual test counts are shown in each suite's detailed summary above"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TEST SUITES PASSED!${NC}"
        return 0
    else
        echo -e "${RED}❌ $FAILED_TESTS TEST SUITE(S) FAILED${NC}"
        return 1
    fi
}

# Main execution
main() {
    print_banner
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Check for required tools
    log_info "Checking for required tools..."
    
    local required_tools=("bash" "shellcheck")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and try again"
        exit 1
    fi
    
    log_info "All required tools found"
    echo ""
    
    # Run test suites
    log_info "Starting test execution..."
    echo ""
    
    local suite_failures=0
    
    # 1. Syntax Tests
    if [[ -f "$TEST_DIR/syntax-tests.sh" ]]; then
        log_info "Running syntax validation tests..."
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        if "$TEST_DIR/syntax-tests.sh"; then
            log_success "Syntax validation tests"
        else
            log_error "Syntax validation tests"
            suite_failures=$((suite_failures + 1))
        fi
        echo ""
    fi
    
    # 2. Source/Loading Tests
    if [[ -f "$TEST_DIR/source-tests.sh" ]]; then
        log_info "Running source/loading tests..."
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        if "$TEST_DIR/source-tests.sh"; then
            log_success "Source/loading tests"
        else
            log_error "Source/loading tests"
            suite_failures=$((suite_failures + 1))
        fi
        echo ""
    fi
    
    # 3. Plugin Tests
    if [[ -f "$TEST_DIR/plugin-tests.sh" ]]; then
        log_info "Running plugin-specific tests..."
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        if "$TEST_DIR/plugin-tests.sh"; then
            log_success "Plugin-specific tests"
        else
            log_error "Plugin-specific tests"
            suite_failures=$((suite_failures + 1))
        fi
        echo ""
    fi
    
    # 4. Integration Tests
    if [[ -f "$TEST_DIR/integration-tests.sh" ]]; then
        log_info "Running integration tests..."
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        if "$TEST_DIR/integration-tests.sh"; then
            log_success "Integration tests"
        else
            log_error "Integration tests"
            suite_failures=$((suite_failures + 1))
        fi
        echo ""
    fi
    
    # Print final summary
    print_summary
}

# Help function
show_help() {
    echo "Chief Test Suite - Main Test Runner"
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
    echo "This script runs the complete test suite for the Chief project."
    echo "Individual test scripts can also be run separately:"
    echo "  ./tests/syntax-tests.sh     - Bash syntax validation"
    echo "  ./tests/source-tests.sh     - Script loading validation"
    echo "  ./tests/plugin-tests.sh     - Plugin-specific tests"
    echo "  ./tests/integration-tests.sh - End-to-end functionality"
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
