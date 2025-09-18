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

# Test git repository health
test_git_repository() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing git repository"
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        log_warning "Git not available, skipping repository test"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_warning "Not in a git repository, skipping git tests"
        return 0
    fi
    
    # Check for common git issues
    local issues=()
    
    # Check if there are any untracked important files
    local untracked_important=()
    while IFS= read -r file; do
        if [[ "$file" == "chief.sh" ]] || [[ "$file" == "libs/"* ]] || [[ "$file" == "tools/"* ]]; then
            untracked_important+=("$file")
        fi
    done < <(git ls-files --others --exclude-standard 2>/dev/null || true)
    
    if [[ ${#untracked_important[@]} -gt 0 ]]; then
        issues+=("untracked important files: ${untracked_important[*]}")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_success "Git repository OK"
        return 0
    else
        log_warning "Git repository issues: ${issues[*]}"
        return 0  # Don't fail on git warnings
    fi
}

# Test README and documentation
test_documentation() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing documentation"
    fi
    
    local doc_files=(
        "$PROJECT_ROOT/README.md"
        "$PROJECT_ROOT/docs/index.md"
    )
    
    local found_docs=0
    for doc in "${doc_files[@]}"; do
        if [[ -f "$doc" ]]; then
            found_docs=$((found_docs + 1))
        fi
    done
    
    if [[ $found_docs -gt 0 ]]; then
        log_success "Documentation OK ($found_docs file(s) found)"
        return 0
    else
        log_warning "No documentation files found"
        return 0  # Don't fail on missing docs
    fi
}

# Test a simulated chief.sh lib-only loading with full environment
test_full_environment() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing full environment simulation"
    fi
    
    # Create a complete test environment
    local test_script="$TEMP_DIR/test_full_env.sh"
    
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -e

project_root="$1"

# Set up complete Chief environment
export CHIEF_PATH="$project_root"
export CHIEF_CONFIG="$project_root/templates/chief_config_template.sh"

# Test that we can source the config template
if ! source "$CHIEF_CONFIG" >/dev/null 2>&1; then
    echo "Failed to source config template"
    exit 1
fi

# Override problematic config settings for testing
export CHIEF_CFG_BANNER=false
export CHIEF_CFG_VERBOSE=false
export CHIEF_CFG_HINTS=false
export CHIEF_CFG_AUTOCHECK_UPDATES=false
export CHIEF_CFG_COLORED_LS=false

# Test that we can source chief.sh in lib-only mode
if ! source "$CHIEF_PATH/chief.sh" --lib-only >/dev/null 2>&1; then
    echo "Failed to source chief.sh in lib-only mode"
    exit 1
fi

echo "Full environment test successful"
exit 0
EOF
    
    chmod +x "$test_script"
    
    # Run the test with timeout using background process and kill
    local test_pid
    local timeout_seconds=30
    
    # Start the test in background
    bash "$test_script" "$PROJECT_ROOT" 2>/dev/null &
    test_pid=$!
    
    # Wait for completion or timeout
    local count=0
    while [[ $count -lt $timeout_seconds ]]; do
        if ! kill -0 "$test_pid" 2>/dev/null; then
            # Process has completed
            wait "$test_pid"
            local exit_code=$?
            if [[ $exit_code -eq 0 ]]; then
                log_success "Full environment simulation OK"
                return 0
            else
                log_error "Full environment simulation FAILED (exit code: $exit_code)"
                return 1
            fi
        fi
        sleep 1
        count=$((count + 1))
    done
    
    # Timeout reached - kill the process
    if kill -0 "$test_pid" 2>/dev/null; then
        kill -TERM "$test_pid" 2>/dev/null || true
        sleep 2
        kill -KILL "$test_pid" 2>/dev/null || true
        wait "$test_pid" 2>/dev/null || true
    fi
    
    log_error "Full environment simulation TIMED OUT after ${timeout_seconds} seconds"
    echo -e "${RED}This suggests a hang during plugin loading or configuration${NC}"
    return 1
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
    test_directory_structure
    test_core_files
    test_version_file
    test_install_script
    test_uninstall_script
    test_git_repository
    test_documentation
    test_full_environment
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       INTEGRATION TEST SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
    echo -e "${RED}Failed:${NC} $FAILED_TESTS"
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
    echo "  - Installation script functionality"
    echo "  - Git repository health"
    echo "  - Documentation presence"
    echo "  - Full environment simulation"
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
