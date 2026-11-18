#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Bash version warning tests
#
# Verifies __chief_check_bash_version warns on Bash < 4, stays silent on
# Bash >= 4, and honors CHIEF_CFG_BASH_WARN=false. Uses the
# CHIEF_TEST_BASH_VERSINFO_MAJOR hook so it runs the same on any bash.
########################################################################

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }

echo -e "${BLUE}[INFO]${NC} Bash version warning tests (running under bash ${BASH_VERSION})"

# Source only the library, in a throwaway shell state, with color/NO_COLOR off for stable matching.
run_check() {
  # $1 = simulated major, $2 = CHIEF_CFG_BASH_WARN value (or empty for unset)
  NO_COLOR=1 CHIEF_PATH="$PROJECT_ROOT" CHIEF_CONFIG="/dev/null" \
    CHIEF_TEST_BASH_VERSINFO_MAJOR="$1" CHIEF_CFG_BASH_WARN="${2-}" \
    bash -c '
      [[ -z "$CHIEF_CFG_BASH_WARN" ]] && unset CHIEF_CFG_BASH_WARN
      source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
      __chief_check_bash_version
      echo "rc=$?" >&2
    ' 2>&1
}

out="$(run_check 3 "")"
if grep -q "Chief needs Bash 4.0+" <<<"$out" && grep -q "rc=0" <<<"$out"; then
  pass "warns (and returns 0) on Bash 3"
else
  fail "expected warning and rc=0 on Bash 3; got: $out"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  if grep -q "brew install bash\|already installed at" <<<"$out" && grep -q "bash_profile" <<<"$out"; then
    pass "macOS guidance mentions Homebrew bash and ~/.bash_profile"
  else
    fail "macOS guidance missing; got: $out"
  fi
fi

out="$(run_check 5 "")"
if ! grep -q "Chief needs Bash 4.0+" <<<"$out" && grep -q "rc=0" <<<"$out"; then
  pass "silent on Bash 5"
else
  fail "expected no warning on Bash 5; got: $out"
fi

out="$(run_check 3 "false")"
if ! grep -q "Chief needs Bash 4.0+" <<<"$out" && grep -q "rc=0" <<<"$out"; then
  pass "CHIEF_CFG_BASH_WARN=false silences the warning"
else
  fail "expected CHIEF_CFG_BASH_WARN=false to silence the warning; got: $out"
fi

echo ""
echo "Bash version tests: ${PASSED} passed, ${FAILED} failed"
[[ $FAILED -eq 0 ]]
