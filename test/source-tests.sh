#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Source/Loading Tests
# 
# This script tests that all bash scripts can be sourced properly
# without errors in isolated environments.
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
TEMP_DIR="${TMPDIR:-/tmp}/chief-source-tests-$$"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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
    ((PASSED_TESTS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test if a script can be sourced in isolation
test_source_script() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    local test_name="$2"
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing source: $test_name"
    fi
    
    # Create a test script that tries to source the file
    local test_script="$TEMP_DIR/test_source.sh"
    
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Capture any output or errors
exec 2>&1

# Try to source the file
source "$1" 2>/dev/null || exit 1

# Exit successfully if we get here
exit 0
EOF
    
    chmod +x "$test_script"
    
    # Run the test in a clean subshell
    if bash "$test_script" "$file" >/dev/null 2>&1; then
        log_success "Source OK: $test_name"
        return 0
    else
        log_error "Source FAILED: $test_name"
        # Show the actual error for debugging
        echo -e "${RED}Error details:${NC}"
        bash "$test_script" "$file" 2>&1 | head -10 | sed 's/^/  /'
        return 1
    fi
}

# Test plugin loading with mock environment
test_plugin_loading() {
    local plugin_file="$1"
    local plugin_name="$(basename "$plugin_file" _chief-plugin.sh)"
    local relative_path="${plugin_file#$PROJECT_ROOT/}"
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing plugin load: $plugin_name"
    fi
    
    # Create a mock environment for plugin testing
    local test_script="$TEMP_DIR/test_plugin.sh"
    
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock Chief environment variables and functions that plugins might expect
export CHIEF_PATH="/mock/chief/path"
export CHIEF_CONFIG="/mock/chief/config"
export CHIEF_PLUGIN_NAME="test_plugin"

# Mock color variables that plugins often use
export CHIEF_COLOR_RED='\033[0;31m'
export CHIEF_COLOR_GREEN='\033[0;32m'
export CHIEF_COLOR_YELLOW='\033[1;33m'
export CHIEF_COLOR_BLUE='\033[0;34m'
export CHIEF_COLOR_CYAN='\033[0;36m'
export CHIEF_NO_COLOR='\033[0m'
export NC='\033[0m'

# Mock common Chief functions that plugins might use
__print() { echo "[MOCK] $*"; }
__debug() { echo "[DEBUG] $*" >&2; }

# Redirect stdout to suppress plugin loading messages
exec 1>/dev/null

# Try to source the plugin
source "$1" 2>/dev/null || exit 1

# Exit successfully if we get here
exit 0
EOF
    
    chmod +x "$test_script"
    
    # Run the test in a clean subshell
    if bash "$test_script" "$plugin_file" 2>/dev/null; then
        log_success "Plugin load OK: $plugin_name"
        return 0
    else
        log_error "Plugin load FAILED: $plugin_name"
        # Show the actual error for debugging
        echo -e "${RED}Error details:${NC}"
        bash "$test_script" "$plugin_file" 2>&1 | head -10 | sed 's/^/  /'
        return 1
    fi
}

# Test template files
test_template_file() {
    local template_file="$1"
    local template_name="$(basename "$template_file")"
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing template: $template_name"
    fi
    
    # Create a test script for template validation
    local test_script="$TEMP_DIR/test_template.sh"
    
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock variables that templates might expect
export CHIEF_PLUGIN_NAME="test_plugin"
export CHIEF_PATH="/mock/chief/path"
export CHIEF_CONFIG="/mock/chief/config"

# For config template, we need to validate it as a config file
if [[ "$1" == *"config_template"* ]]; then
    # Just validate syntax for config template
    bash -n "$1" || exit 1
else
    # For other templates, try to source them
    source "$1" 2>/dev/null || exit 1
fi

exit 0
EOF
    
    chmod +x "$test_script"
    
    # Run the test in a clean subshell
    if bash "$test_script" "$template_file" >/dev/null 2>&1; then
        log_success "Template OK: $template_name"
        return 0
    else
        log_error "Template FAILED: $template_name"
        # Show the actual error for debugging
        echo -e "${RED}Error details:${NC}"
        bash "$test_script" "$template_file" 2>&1 | head -10 | sed 's/^/  /'
        return 1
    fi
}

# Test chief.sh with lib-only mode
test_chief_lib_only() {
    local chief_file="$PROJECT_ROOT/chief.sh"
    
    if [[ ! -f "$chief_file" ]]; then
        log_warning "chief.sh not found, skipping lib-only test"
        return 0
    fi
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing chief.sh --lib-only mode"
    fi
    
    # Create a test script for chief.sh lib-only mode
    local test_script="$TEMP_DIR/test_chief_lib.sh"
    
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Set required environment variables
export CHIEF_PATH="$(cd "$(dirname "$1")/.." && pwd)"
export CHIEF_CONFIG="$CHIEF_PATH/templates/chief_config_template.sh"

# Try to source chief.sh in lib-only mode
# Redirect output to suppress any loading messages
source "$1" --lib-only >/dev/null 2>&1 || exit 1

exit 0
EOF
    
    chmod +x "$test_script"
    
    # Run the test in a clean subshell
    if bash "$test_script" "$chief_file" 2>/dev/null; then
        log_success "Chief lib-only mode OK"
        return 0
    else
        log_error "Chief lib-only mode FAILED"
        # Show the actual error for debugging
        echo -e "${RED}Error details:${NC}"
        bash "$test_script" "$chief_file" 2>&1 | head -10 | sed 's/^/  /'
        return 1
    fi
}

# Main execution
main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       SOURCE/LOADING TESTS${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    log_info "Setting up test environment..."
    
    # Test chief.sh lib-only mode first
    test_chief_lib_only
    echo ""
    
    # Test plugin files
    log_info "Testing plugin files..."
    local plugin_files=()
    while IFS= read -r -d '' file; do
        plugin_files+=("$file")
    done < <(find "$PROJECT_ROOT/libs/core/plugins" -name "*_chief-plugin.sh" -type f -print0 2>/dev/null || true)
    
    if [[ ${#plugin_files[@]} -gt 0 ]]; then
        log_info "Found ${#plugin_files[@]} plugin file(s)"
        for plugin_file in "${plugin_files[@]}"; do
            test_plugin_loading "$plugin_file"
        done
    else
        log_warning "No plugin files found"
    fi
    echo ""
    
    # Test template files
    log_info "Testing template files..."
    local template_files=()
    while IFS= read -r -d '' file; do
        template_files+=("$file")
    done < <(find "$PROJECT_ROOT/templates" -name "*.sh" -type f -print0 2>/dev/null || true)
    
    if [[ ${#template_files[@]} -gt 0 ]]; then
        log_info "Found ${#template_files[@]} template file(s)"
        for template_file in "${template_files[@]}"; do
            test_template_file "$template_file"
        done
    else
        log_warning "No template files found"
    fi
    echo ""
    
    # Test tool scripts
    log_info "Testing tool scripts..."
    local tool_files=()
    while IFS= read -r -d '' file; do
        tool_files+=("$file")
    done < <(find "$PROJECT_ROOT/tools" -name "*.sh" -type f -print0 2>/dev/null || true)
    
    if [[ ${#tool_files[@]} -gt 0 ]]; then
        log_info "Found ${#tool_files[@]} tool script(s)"
        for tool_file in "${tool_files[@]}"; do
            test_source_script "$tool_file" "$(basename "$tool_file")"
        done
    else
        log_warning "No tool scripts found"
    fi
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}        SOURCE/LOADING SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
    echo -e "${RED}Failed:${NC} $FAILED_TESTS"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL SOURCE/LOADING TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}❌ $FAILED_TESTS SOURCE/LOADING TEST(S) FAILED${NC}"
        return 1
    fi
}

# Show help
show_help() {
    echo "Chief Test Suite - Source/Loading Tests"
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
    echo "This script tests that all bash scripts can be sourced properly"
    echo "without errors in isolated environments. It includes special handling"
    echo "for plugins, templates, and the main chief.sh script."
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
