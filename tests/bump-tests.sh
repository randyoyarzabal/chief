#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Version Bump Tests
#
# Runs __chief.bump (release and next-dev) against a scratch copy of the
# project and asserts the resulting VERSION, badges, and release notes.
# The real checkout and the user's config are never touched.
#
# Badge contract under test:
#   Download Release / Stable -> latest released version (never -dev)
#   Dev Branch                -> in-progress dev version (always --dev)
########################################################################

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_DIR="${TMPDIR:-/tmp}/chief-bump-tests-$$"

declare -i TOTAL_TESTS=0
declare -i PASSED_TESTS=0
declare -i FAILED_TESTS=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED_TESTS+=1; }
log_error()   { echo -e "${RED}[FAIL]${NC} $1"; FAILED_TESTS+=1; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Assert that a file contains (or does not contain) a fixed string
assert_contains() {
    local file="$1" needle="$2" label="$3"
    TOTAL_TESTS+=1
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
        log_success "$label"
    else
        log_error "$label (expected '$needle' in $(basename "$file"))"
    fi
}

assert_not_contains() {
    local file="$1" needle="$2" label="$3"
    TOTAL_TESTS+=1
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
        log_error "$label (did not expect '$needle' in $(basename "$file"))"
    else
        log_success "$label"
    fi
}

assert_file_exists() {
    local file="$1" label="$2"
    TOTAL_TESTS+=1
    if [[ -f "$file" ]]; then log_success "$label"; else log_error "$label (missing $file)"; fi
}

# Build an isolated copy of the project with a known starting version.
# $1 = starting version to write into VERSION and badges (e.g. v9.8.0-dev)
make_scratch() {
    local start_version="$1"
    local copy="$TEMP_DIR/chief"
    rm -rf "$copy"
    mkdir -p "$TEMP_DIR"

    # Only the files the bump touches, plus what chief_library.sh needs to source.
    mkdir -p "$copy/docs" "$copy/release-notes" "$copy/libs/core" "$copy/templates"
    cp "$PROJECT_ROOT/VERSION" "$copy/VERSION"
    cp "$PROJECT_ROOT/README.md" "$copy/README.md"
    cp "$PROJECT_ROOT/docs/index.md" "$copy/docs/index.md"
    cp "$PROJECT_ROOT/docs/getting-started.md" "$copy/docs/getting-started.md" 2>/dev/null || true
    cp "$PROJECT_ROOT/libs/core/chief_library.sh" "$copy/libs/core/chief_library.sh"
    cp -R "$PROJECT_ROOT/libs/core/plugins" "$copy/libs/core/plugins"
    cp "$PROJECT_ROOT/templates/chief_config_template.sh" "$copy/config.sh"

    # Normalise to a synthetic version so the test does not depend on the repo's real version
    local current
    current="$(grep -o 'CHIEF_VERSION="[^"]*"' "$copy/VERSION" | cut -d'"' -f2)"
    local stable="${start_version%-dev}"
    sed -i.bak "s/${current//./\\.}/${start_version}/g" "$copy/VERSION" "$copy/README.md" "$copy/docs/index.md" "$copy/docs/getting-started.md" 2>/dev/null
    # Badges: rewrite to the intended starting meanings
    sed -i.bak \
        -e "s|Download%20Release-v[0-9][0-9.]*\(--dev\)\{0,1\}-|Download%20Release-${stable}-|g" \
        -e "s|Stable-v[0-9][0-9.]*\(--dev\)\{0,1\}-|Stable-${stable}-|g" \
        -e "s|Dev%20Branch-v[0-9][0-9.]*\(--dev\)\{0,1\}-|Dev%20Branch-${start_version//-/--}-|g" \
        "$copy/README.md"
    sed -i.bak "s|Download-Release%20v[0-9][0-9.]*\(--dev\)\{0,1\}-|Download-Release%20${stable}-|g" "$copy/docs/index.md"
    find "$copy" -name "*.bak" -delete

    # A dev release-notes file for the release transform to consume
    printf '# Chief %s Release Notes\n\n## What'"'"'s New\n\n- test\n' "$start_version" > "$copy/release-notes/${start_version}.md"
    echo "$copy"
}

# Run __chief.bump inside the scratch copy. Never touches the real checkout.
run_bump() {
    local copy="$1"; shift
    CHIEF_PATH="$copy" CHIEF_CONFIG="$copy/config.sh" bash -c '
        source "$CHIEF_PATH/VERSION"
        source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
        __chief.bump "$@"
    ' _ "$@" </dev/null >"$TEMP_DIR/bump.log" 2>&1
    local rc=$?
    if [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]]; then sed 's/^/    /' "$TEMP_DIR/bump.log"; fi
    return $rc
}

badges() { grep -o 'badge/[^)]*svg' "$1" | tr '\n' ' '; }

test_release_bump() {
    log_info "release: v9.8.0-dev -> v9.8.0"
    local copy; copy="$(make_scratch v9.8.0-dev)"

    TOTAL_TESTS+=1
    if run_bump "$copy" release --skip-tests; then
        log_success "release bump exit code 0"
    else
        log_error "release bump failed (see log below)"; sed 's/^/    /' "$TEMP_DIR/bump.log" | tail -20
    fi

    assert_contains     "$copy/VERSION"   'CHIEF_VERSION="v9.8.0"'          "VERSION updated to release"
    assert_not_contains "$copy/VERSION"   'v9.8.0-dev'                        "VERSION has no -dev suffix"
    assert_contains     "$copy/README.md" 'Download%20Release-v9.8.0-blue'    "Download Release badge = released version"
    assert_contains     "$copy/README.md" 'Stable-v9.8.0-green'               "Stable badge = released version"
    assert_contains     "$copy/README.md" 'Dev%20Branch-v9.9.0--dev-orange'   "Dev Branch badge = next minor dev"
    assert_not_contains "$copy/README.md" 'v9.8.0-dev'                        "README has no stray -dev version"
    assert_contains     "$copy/docs/index.md" 'Download-Release%20v9.8.0-green' "docs/index.md badge = released version"
    assert_file_exists  "$copy/release-notes/v9.8.0.md"                       "release notes renamed to final version"
    TOTAL_TESTS+=1
    if [[ ! -f "$copy/release-notes/v9.8.0-dev.md" ]]; then
        log_success "dev release notes file removed"
    else
        log_error "dev release notes file still present"
    fi
    assert_contains     "$copy/config.sh" 'CHIEF_CFG_UPDATE_BRANCH="main"'   "config tracks main after release"
    [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]] && echo "    badges: $(badges "$copy/README.md")"
    echo ""
}

test_next_dev_bump() {
    log_info "next-dev: v9.8.0 -> v9.9.0-dev"
    local copy; copy="$(make_scratch v9.8.0)"
    # make_scratch writes a Dev Branch badge of v9.8.0; a released README would show the *next* dev.
    # Either way next-dev must land on v9.9.0--dev.

    TOTAL_TESTS+=1
    if run_bump "$copy" next-dev; then
        log_success "next-dev bump exit code 0"
    else
        log_error "next-dev bump failed (see log below)"; sed 's/^/    /' "$TEMP_DIR/bump.log" | tail -20
    fi

    assert_contains     "$copy/VERSION"   'CHIEF_VERSION="v9.9.0-dev"'        "VERSION updated to next dev"
    assert_contains     "$copy/README.md" 'Download%20Release-v9.8.0-blue'    "Download Release badge still = last release"
    assert_contains     "$copy/README.md" 'Stable-v9.8.0-green'               "Stable badge still = last release"
    assert_contains     "$copy/README.md" 'Dev%20Branch-v9.9.0--dev-orange'   "Dev Branch badge = new dev version"
    assert_not_contains "$copy/README.md" 'Download%20Release-v9.9.0'         "Download Release badge not polluted with dev"
    assert_not_contains "$copy/README.md" 'Stable-v9.9.0'                     "Stable badge not polluted with dev"
    assert_contains     "$copy/docs/index.md" 'Download-Release%20v9.8.0-green' "docs/index.md badge still = last release"
    assert_contains     "$copy/config.sh" 'CHIEF_CFG_UPDATE_BRANCH="dev"'    "config tracks dev after next-dev"
    [[ ${CHIEF_TEST_VERBOSE:-0} -eq 1 ]] && echo "    badges: $(badges "$copy/README.md")"
    echo ""
}

test_release_idempotent() {
    log_info "release twice: second run must be a no-op"
    local copy; copy="$(make_scratch v9.8.0-dev)"
    run_bump "$copy" release --skip-tests
    local before; before="$(cat "$copy/README.md" "$copy/VERSION" "$copy/docs/index.md")"
    TOTAL_TESTS+=1
    # Second run: current version is now v9.8.0 (no -dev) so release mode should refuse or no-op
    run_bump "$copy" release --skip-tests || true
    local after; after="$(cat "$copy/README.md" "$copy/VERSION" "$copy/docs/index.md")"
    if [[ "$before" == "$after" ]]; then
        log_success "second release run changed nothing"
    else
        log_error "second release run modified files"
        diff <(echo "$before") <(echo "$after") | head -10 | sed 's/^/    /'
    fi
    echo ""
}

main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}        VERSION BUMP TESTS${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    mkdir -p "$TEMP_DIR"

    test_release_bump
    test_next_dev_bump
    test_release_idempotent

    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       VERSION BUMP SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
    [[ $FAILED_TESTS -gt 0 ]] && echo -e "${RED}Failed:${NC} $FAILED_TESTS"
    echo ""
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL VERSION BUMP TESTS PASSED!${NC}"; return 0
    else
        echo -e "${RED}❌ $FAILED_TESTS VERSION BUMP TEST(S) FAILED${NC}"; return 1
    fi
}

show_help() {
    echo "Chief Test Suite - Version Bump Tests"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo "  -h, --help     Show this help"
    echo "  -v, --verbose  Show bump output and resulting badges"
    echo ""
    echo "Runs __chief.bump release / next-dev on a scratch copy and checks VERSION,"
    echo "README and docs/index.md badges, release-notes renaming, and config branch."
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -v|--verbose) export CHIEF_TEST_VERBOSE=1; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

main "$@"
