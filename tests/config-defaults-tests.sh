#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Config defaults and upgrade behavior
#
#   - Core plugins: one rule ("loaded unless in CHIEF_CFG_PLUGINS_DISABLED_CORE");
#     the template ships aws/openshift/vault disabled, older configs keep them on.
#   - SSH keys: CHIEF_CFG_SSH_LOAD_KEYS switches auto-load; the keys path defaults to ~/.ssh;
#     older configs that only set CHIEF_CFG_SSH_KEYS_PATH keep auto-loading.
########################################################################

set -uo pipefail
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

# Evaluate <expr> in a shell with the library loaded and the given config lines applied.
# Usage: expect <label> <want-exit-code> <config-lines> <expr>
expect() {
    local label="$1" want="$2" cfg="$3" expr="$4" got
    CHIEF_PATH="$PROJECT_ROOT" CHIEF_CONFIG=/dev/null bash -c '
        source "$CHIEF_PATH/VERSION"
        source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
        unset CHIEF_CFG_SSH_LOAD_KEYS CHIEF_CFG_SSH_KEYS_PATH
        eval "$1"; eval "$2"' _ "$cfg" "$expr" >/dev/null 2>&1
    got=$?
    if [[ $got -eq $want ]]; then echo -e "${GREEN}[PASS]${NC} $label"; PASS=$((PASS + 1))
    else echo -e "${RED}[FAIL]${NC} $label (exit $got, wanted $want)"; FAIL=$((FAIL + 1)); fi
}

TEMPLATE="source '$PROJECT_ROOT/templates/chief_config_template.sh'"

echo -e "${CYAN}CONFIG DEFAULTS TESTS${NC}"
expect "template: aws off by default"            0 "$TEMPLATE" "__chief_plugin_disabled core aws"
expect "template: vault off by default"          0 "$TEMPLATE" "__chief_plugin_disabled core vault"
expect "template: git on by default"             1 "$TEMPLATE" "__chief_plugin_disabled core git"
expect "older config (empty list): aws stays on" 1 'CHIEF_CFG_PLUGINS_DISABLED_CORE=""' "__chief_plugin_disabled core aws"
expect "template has no ENABLED_CORE setting"    1 "" "grep -q PLUGINS_ENABLED_CORE '$PROJECT_ROOT/templates/chief_config_template.sh'"

expect "keys path defaults to ~/.ssh"            0 "" '[[ "$(__chief_ssh_keys_path)" == "$HOME/.ssh" ]]'
expect "keys path override honored"              0 'CHIEF_CFG_SSH_KEYS_PATH=/tmp/k' '[[ "$(__chief_ssh_keys_path)" == /tmp/k ]]'
expect "template: SSH auto-load off"             1 "$TEMPLATE" "__chief_ssh_autoload_on"
expect "switch on: auto-load"                    0 'CHIEF_CFG_SSH_LOAD_KEYS=true' "__chief_ssh_autoload_on"
expect "switch off wins over a set path"         1 'CHIEF_CFG_SSH_LOAD_KEYS=false; CHIEF_CFG_SSH_KEYS_PATH=/tmp/k' "__chief_ssh_autoload_on"
expect "older config with only a path: auto-load" 0 'CHIEF_CFG_SSH_KEYS_PATH=/tmp/k' "__chief_ssh_autoload_on"
expect "older config with neither: no auto-load" 1 "" "__chief_ssh_autoload_on"

echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
