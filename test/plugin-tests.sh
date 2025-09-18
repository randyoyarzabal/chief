#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Plugin-Specific Tests
# 
# This script tests plugin-specific functionality and behavior.
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
TEMP_DIR="${TMPDIR:-/tmp}/chief-plugin-tests-$$"

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

# Test if plugin follows naming conventions
test_plugin_naming() {
    local plugin_file="$1"
    local filename="$(basename "$plugin_file")"
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing naming: $filename"
    fi
    
    if [[ "$filename" =~ ^[a-zA-Z0-9_]+_chief-plugin\.sh$ ]]; then
        log_success "Naming convention OK: $filename"
        return 0
    else
        log_error "Naming convention FAILED: $filename (should match *_chief-plugin.sh)"
        return 1
    fi
}

# Test if plugin has proper shebang and header
test_plugin_structure() {
    local plugin_file="$1"
    local plugin_name="$(basename "$plugin_file" _chief-plugin.sh)"
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing structure: $plugin_name"
    fi
    
    local has_shebang=false
    local has_execution_block=false
    local line_count=0
    
    while IFS= read -r line && [[ $line_count -lt 30 ]]; do
        ((line_count++))
        
        # Check for shebang in first few lines
        if [[ $line_count -le 3 && "$line" =~ ^#!/.*bash ]]; then
            has_shebang=true
        fi
        
        # Check for execution blocking
        if [[ "$line" =~ \$0.*BASH_SOURCE.*0 ]] && [[ "$line" =~ echo.*Error ]]; then
            has_execution_block=true
        fi
        
    done < "$plugin_file"
    
    local errors=()
    if [[ "$has_shebang" != "true" ]]; then
        errors+=("missing bash shebang")
    fi
    if [[ "$has_execution_block" != "true" ]]; then
        errors+=("missing execution blocking")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        log_success "Structure OK: $plugin_name"
        return 0
    else
        log_error "Structure FAILED: $plugin_name (${errors[*]})"
        return 1
    fi
}

# Test if plugin defines functions with proper naming
test_plugin_functions() {
    local plugin_file="$1"
    local plugin_name="$(basename "$plugin_file" _chief-plugin.sh)"
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing functions: $plugin_name"
    fi
    
    # Look for function definitions in the plugin
    local functions=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z0-9_\.]+)\(\) ]] || 
           [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_\.]+)\(\)[[:space:]]*\{ ]]; then
            local func_name="${BASH_REMATCH[1]}"
            functions+=("$func_name")
        fi
    done < "$plugin_file"
    
    # Also look for alias definitions
    local aliases=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*alias[[:space:]]+([a-zA-Z0-9_\.]+)= ]]; then
            local alias_name="${BASH_REMATCH[1]}"
            aliases+=("$alias_name")
        fi
    done < "$plugin_file"
    
    local total_definitions=$((${#functions[@]} + ${#aliases[@]}))
    
    if [[ $total_definitions -eq 0 ]]; then
        log_warning "No functions/aliases found: $plugin_name"
        return 0
    fi
    
    # Check if functions/aliases follow naming convention (should start with plugin name or chief.)
    local bad_names=()
    for func in "${functions[@]}"; do
        if [[ ! "$func" =~ ^(chief\.|${plugin_name}\.) ]]; then
            bad_names+=("function $func")
        fi
    done
    
    for alias in "${aliases[@]}"; do
        if [[ ! "$alias" =~ ^(chief\.|${plugin_name}\.) ]]; then
            bad_names+=("alias $alias")
        fi
    done
    
    if [[ ${#bad_names[@]} -eq 0 ]]; then
        log_success "Function naming OK: $plugin_name ($total_definitions definitions)"
        return 0
    else
        log_error "Function naming FAILED: $plugin_name (bad names: ${bad_names[*]})"
        return 1
    fi
}

# Test if plugin can be loaded and unloaded cleanly
test_plugin_load_unload() {
    local plugin_file="$1"
    local plugin_name="$(basename "$plugin_file" _chief-plugin.sh)"
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing load/unload: $plugin_name"
    fi
    
    # Create a test script for plugin load/unload
    local test_script="$TEMP_DIR/test_plugin_load.sh"
    
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

plugin_file="$1"
plugin_name="$2"

# Mock Chief environment
export CHIEF_PATH="/mock/chief/path"
export CHIEF_CONFIG="/mock/chief/config"
export CHIEF_PLUGIN_NAME="$plugin_name"

# Mock color variables
export CHIEF_COLOR_RED='\033[0;31m'
export CHIEF_COLOR_GREEN='\033[0;32m'
export CHIEF_COLOR_YELLOW='\033[1;33m'
export CHIEF_COLOR_BLUE='\033[0;34m'
export CHIEF_COLOR_CYAN='\033[0;36m'
export CHIEF_NO_COLOR='\033[0m'
export NC='\033[0m'

# Mock functions
__print() { return 0; }
__debug() { return 0; }

# Capture functions before loading
functions_before=$(declare -F | cut -d' ' -f3 | sort)

# Load the plugin (suppress output)
source "$plugin_file" >/dev/null 2>&1 || exit 1

# Capture functions after loading
functions_after=$(declare -F | cut -d' ' -f3 | sort)

# Check if new functions were added
new_functions=$(comm -13 <(echo "$functions_before") <(echo "$functions_after"))

if [[ -n "$new_functions" ]]; then
    echo "Plugin loaded successfully and added functions: $new_functions"
else
    echo "Plugin loaded but no new functions detected"
fi

exit 0
EOF
    
    chmod +x "$test_script"
    
    # Run the test
    if output=$(bash "$test_script" "$plugin_file" "$plugin_name" 2>&1); then
        log_success "Load/unload OK: $plugin_name"
        if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 && -n "$output" ]]; then
            echo "  $output"
        fi
        return 0
    else
        log_error "Load/unload FAILED: $plugin_name"
        echo -e "${RED}Error details:${NC}"
        echo "$output" | head -5 | sed 's/^/  /'
        return 1
    fi
}

# Test Python plugin dependencies if Python plugins exist
test_python_dependencies() {
    local python_plugin="$PROJECT_ROOT/libs/core/plugins/python_chief-plugin.sh"
    local python_dir="$PROJECT_ROOT/libs/core/plugins/python"
    
    if [[ ! -f "$python_plugin" ]]; then
        return 0  # Skip if no Python plugin
    fi
    
    ((TOTAL_TESTS++))
    
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then
        log_info "Testing Python dependencies"
    fi
    
    if [[ -d "$python_dir" ]]; then
        # Check if Python files are valid syntax
        local python_files=()
        while IFS= read -r -d '' file; do
            python_files+=("$file")
        done < <(find "$python_dir" -name "*.py" -type f -print0 2>/dev/null || true)
        
        if [[ ${#python_files[@]} -gt 0 ]]; then
            local python_errors=()
            for py_file in "${python_files[@]}"; do
                if ! python3 -m py_compile "$py_file" 2>/dev/null; then
                    python_errors+=("$(basename "$py_file")")
                fi
            done
            
            if [[ ${#python_errors[@]} -eq 0 ]]; then
                log_success "Python dependencies OK (${#python_files[@]} files)"
                return 0
            else
                log_error "Python dependencies FAILED (${python_errors[*]})"
                return 1
            fi
        else
            log_warning "Python plugin exists but no .py files found"
            return 0
        fi
    else
        log_warning "Python plugin exists but python/ directory not found"
        return 0
    fi
}

# Main execution
main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}        PLUGIN-SPECIFIC TESTS${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Find all plugin files
    log_info "Discovering plugin files..."
    local plugin_files=()
    while IFS= read -r -d '' file; do
        plugin_files+=("$file")
    done < <(find "$PROJECT_ROOT/libs/core/plugins" -name "*_chief-plugin.sh" -type f -print0 2>/dev/null || true)
    
    if [[ ${#plugin_files[@]} -eq 0 ]]; then
        log_warning "No plugin files found to test"
        echo ""
        echo -e "${YELLOW}⚠️  NO PLUGIN TESTS RUN${NC}"
        return 0
    fi
    
    log_info "Found ${#plugin_files[@]} plugin file(s) to test"
    echo ""
    
    # Test each plugin
    for plugin_file in "${plugin_files[@]}"; do
        local plugin_name="$(basename "$plugin_file" _chief-plugin.sh)"
        
        # Test plugin naming conventions
        test_plugin_naming "$plugin_file"
        
        # Test plugin structure
        test_plugin_structure "$plugin_file"
        
        # Test plugin function naming
        test_plugin_functions "$plugin_file"
        
        # Test plugin loading/unloading
        test_plugin_load_unload "$plugin_file"
    done
    
    echo ""
    
    # Test Python dependencies if applicable
    test_python_dependencies
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}         PLUGIN TEST SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Plugins Tested:${NC} ${#plugin_files[@]}"
    echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
    echo -e "${RED}Failed:${NC} $FAILED_TESTS"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL PLUGIN TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}❌ $FAILED_TESTS PLUGIN TEST(S) FAILED${NC}"
        return 1
    fi
}

# Show help
show_help() {
    echo "Chief Test Suite - Plugin-Specific Tests"
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
    echo "This script tests plugin-specific functionality including:"
    echo "  - Naming conventions"
    echo "  - Plugin structure (shebang, execution blocking)"
    echo "  - Function/alias naming conventions"
    echo "  - Load/unload behavior"
    echo "  - Python dependencies (if applicable)"
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
