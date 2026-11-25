#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - Config defaults and upgrade behavior
#
#   - Core plugins: one rule ("loaded unless in CHIEF_CFG_PLUGINS_DISABLED_CORE");
#     the template ships aws/openshift/vault disabled, older configs keep them on.
#   - SSH keys: CHIEF_CFG_SSH_LOAD_KEYS switches auto-load; the keys path defaults to ~/.ssh;
#     older configs that only set CHIEF_CFG_SSH_KEYS_PATH keep auto-loading.
#   - Update branch: "auto" (default) follows the checkout's branch; a name pins it.
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

# Update branch: "auto" follows the checkout; a branch name pins it.
REPO="$(mktemp -d "${TMPDIR:-/tmp}/chief-branch-test.XXXXXX")"
cp "$PROJECT_ROOT/VERSION" "$REPO/VERSION"
(cd "$REPO" && git init -q -b main && git -c user.name=t -c user.email=t@e -c commit.gpgsign=false add -A \
   && git -c user.name=t -c user.email=t@e -c commit.gpgsign=false commit -qm base && git branch dev) >/dev/null 2>&1
branch_is() { # <label> <checkout> <config-value|-unset-> <expected>
    local label="$1" ref="$2" cfg="$3" want="$4" got
    git -C "$REPO" checkout -q "$ref" 2>/dev/null
    got="$(CHIEF_PATH="$REPO" bash -c '
        source "'"$PROJECT_ROOT"'/libs/core/chief_library.sh" >/dev/null 2>&1
        if [[ "$1" == -unset- ]]; then unset CHIEF_CFG_UPDATE_BRANCH; else CHIEF_CFG_UPDATE_BRANCH="$1"; fi
        __chief_update_branch' _ "$cfg" 2>/dev/null)"
    if [[ "$got" == "$want" ]]; then echo -e "${GREEN}[PASS]${NC} $label"; PASS=$((PASS + 1))
    else echo -e "${RED}[FAIL]${NC} $label (got '$got', wanted '$want')"; FAIL=$((FAIL + 1)); fi
}
branch_is "auto follows dev checkout"        dev  auto     dev
branch_is "auto follows main checkout"       main auto     main
branch_is "empty setting means auto"         dev  ""       dev
branch_is "unset setting means auto"         dev  -unset-  dev
branch_is "pinned main wins over checkout"   dev  main     main
branch_is "detached checkout falls back to main" "$(git -C "$REPO" rev-parse HEAD)" auto main
rm -rf "$REPO"
expect "template: update branch is auto"   0 "$TEMPLATE" '[[ "$CHIEF_CFG_UPDATE_BRANCH" == auto ]]'

# Stale-version hint: the banner notes when the files on disk changed since Chief loaded.
STALE="$(mktemp -d "${TMPDIR:-/tmp}/chief-stale-test.XXXXXX")"
cp "$PROJECT_ROOT/VERSION" "$STALE/VERSION"
stale_out() { # <loaded-version> -> hint output
    CHIEF_PATH="$STALE" bash -c '
        source "'"$PROJECT_ROOT"'/libs/core/chief_library.sh" >/dev/null 2>&1
        CHIEF_VERSION="$1"; __chief_stale_hint' _ "$1" 2>/dev/null
}
on_disk="$(grep -o 'CHIEF_VERSION="[^"]*"' "$STALE/VERSION" | cut -d'"' -f2)"
check_out() { # <label> <expect-hint:yes|no> <output>
    if [[ "$2" == yes && "$3" == *"chief.reload"* ]] || [[ "$2" == no && -z "$3" ]]; then
        echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1))
    else echo -e "${RED}[FAIL]${NC} $1 (output: '$3')"; FAIL=$((FAIL + 1)); fi
}
check_out "stale hint when disk version differs" yes "$(stale_out v0.0.1)"
check_out "no hint when versions match"          no  "$(stale_out "$on_disk")"
rm -rf "$STALE"

# chief.config-set says when a setting only takes effect in a new terminal.
CFGDIR="$(mktemp -d "${TMPDIR:-/tmp}/chief-cfgset-test.XXXXXX")"
cfgset_out() { # <name> <value> -> chief.config-set output, against a throwaway config
    printf 'CHIEF_CFG_BANNER=false\nCHIEF_CFG_HINTS=false\nCHIEF_CFG_PROMPT=false\nCHIEF_CFG_MULTILINE_PROMPT=false\nCHIEF_CFG_PLUGINS_TYPE=local\nCHIEF_CFG_CONFIG_UPDATE_BACKUP=false\n' > "$CFGDIR/config.sh"
    NO_COLOR=1 CHIEF_PATH="$PROJECT_ROOT" CHIEF_CONFIG="$CFGDIR/config.sh" bash -c '
        source "$CHIEF_CONFIG"; source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
        chief.config-set -y "$1" "$2"' _ "$1" "$2" </dev/null 2>&1
}
note_is() { # <label> <expect:yes|no> <output>
    # yes: note shown, no reload (it couldn't apply the change). no: no note, normal reload.
    if [[ "$2" == yes && "$3" == *"Open a new terminal"* && "$3" != *"Reloading Chief configuration"* && "$3" == *"Confirmed:"* ]] \
       || [[ "$2" == no && "$3" != *"Note:"* && "$3" == *"Configuration reloaded successfully"* && "$3" == *"Confirmed:"* ]]; then
        echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1))
    else echo -e "${RED}[FAIL]${NC} $1 (output: '$3')"; FAIL=$((FAIL + 1)); fi
}
note_is "config-set prompt: no reload, says to open a new terminal" yes "$(cfgset_out prompt true)"
note_is "config-set multiline_prompt: reloads, no note (applies now)" no  "$(cfgset_out multiline_prompt true)"
out="$(cfgset_out hints true)"
if [[ "$out" != *"local: "* && "$out" == *"Confirmed: CHIEF_CFG_HINTS"* ]]; then
    echo -e "${GREEN}[PASS]${NC} config-set: runs cleanly (no shell errors from its help text)"; PASS=$((PASS + 1))
else echo -e "${RED}[FAIL]${NC} config-set printed a shell error (output: '$out')"; FAIL=$((FAIL + 1)); fi
out="$(cfgset_out ssh_load_keys true)"
if [[ "$out" == *"chief.ssh_load-keys"* && "$out" != *"Reloading Chief configuration"* ]]; then
    echo -e "${GREEN}[PASS]${NC} config-set ssh_load_keys: points to chief.ssh_load-keys"; PASS=$((PASS + 1))
else echo -e "${RED}[FAIL]${NC} config-set ssh_load_keys (output: '$out')"; FAIL=$((FAIL + 1)); fi
rm -rf "$CFGDIR"

# Banner indicators: which, in what order, how many lines, and the compact style.
banner_out() { # <env assignments...> -> banner text (no color)
    env NO_COLOR=1 CHIEF_PATH="$PROJECT_ROOT" CHIEF_CFG_PLUGINS_TYPE=remote CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=false "$@" bash -c '
        source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1; __chief.banner' </dev/null 2>/dev/null
}
bcheck() { # <label> <0|1 result>
    if [[ "$2" == 0 ]]; then echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1))
    else echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); fi
}
out="$(banner_out)"
bcheck "banner default: plugins then tracking, 5 lines" "$( [[ "$out" == *"plugins:"*"tracking:"* && $(wc -l <<<"$out") -eq 5 ]]; echo $?)"
bcheck "banner plugins: counts and 'manual update', no red 'disabled'" "$( grep -q 'plugins: [0-9]* on.* · git, manual update' <<<"$out" && ! grep -q 'disabled' <<<"$out"; echo $?)"
out="$(banner_out CHIEF_CFG_BANNER_INDICATORS="tracking")"
bcheck "banner indicators=tracking: no plugins line" "$( [[ "$out" == *"tracking:"* && "$out" != *"plugins:"* ]]; echo $?)"
out="$(banner_out CHIEF_CFG_BANNER_INDICATORS="")"
bcheck "banner indicators empty: logo and version only" "$( [[ "$out" != *"plugins:"* && "$out" != *"tracking:"* && $(wc -l <<<"$out") -eq 5 ]]; echo $?)"
out="$(banner_out CHIEF_CFG_BANNER_SHOW_PLUGINS=false)"
bcheck "banner: legacy BANNER_SHOW_PLUGINS=false still hides plugins" "$( [[ "$out" != *"plugins:"* && "$out" == *"tracking:"* ]]; echo $?)"
out="$(banner_out CHIEF_CFG_ALIAS=cf CHIEF_CFG_BANNER_INDICATORS="alias plugins tracking plugins tracking")"
bcheck "banner: 5 indicators still 5 lines, extras share the last line" "$( [[ $(wc -l <<<"$out") -eq 5 && "$(sed -n 1p <<<"$out")" == *"alias: cf"* && "$(sed -n 4p <<<"$out")" == *"plugins:"*" · "*"tracking:"* ]]; echo $?)"
out="$(banner_out CHIEF_CFG_BANNER_STYLE=compact)"
bcheck "banner compact: small logo, indicators beside it, version under it" "$( [[ "$(head -1 <<<"$out")" == *"┌─┐"* && "$out" == *"plugins:"* && "$(tail -1 <<<"$out")" == v* && $(wc -l <<<"$out") -eq 4 ]]; echo $?)"

# chief.config-update must not turn the template's commented examples into real settings
# (CHIEF_CFG_PLUGINS_GIT_PATH has three "#   CHIEF_CFG_PLUGINS_GIT_PATH=..." examples).
DUPDIR="$(mktemp -d "${TMPDIR:-/tmp}/chief-dup-test.XXXXXX")"
cfgupdate() { # <config file>
    NO_COLOR=1 CHIEF_PATH="$PROJECT_ROOT" CHIEF_CONFIG="$1" bash -c '
        source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
        chief.config-update --force --no-backup >/dev/null 2>&1' </dev/null
}
gitpath_counts() { echo "$(grep -c '^CHIEF_CFG_PLUGINS_GIT_PATH=' "$1") active, $(grep -c '^#   CHIEF_CFG_PLUGINS_GIT_PATH=' "$1") examples"; }
cp "$PROJECT_ROOT/templates/chief_config_template.sh" "$DUPDIR/healthy.sh"
sed -i.bak 's|^CHIEF_CFG_PLUGINS_GIT_PATH=""|CHIEF_CFG_PLUGINS_GIT_PATH="deep/folder"|' "$DUPDIR/healthy.sh"
cfgupdate "$DUPDIR/healthy.sh"; cfgupdate "$DUPDIR/healthy.sh"
got="$(gitpath_counts "$DUPDIR/healthy.sh")"
if [[ "$got" == "1 active, 3 examples" ]] && grep -q '^CHIEF_CFG_PLUGINS_GIT_PATH="deep/folder"$' "$DUPDIR/healthy.sh"; then
    echo -e "${GREEN}[PASS]${NC} config-update: template examples stay comments, no duplicated settings (run twice)"; PASS=$((PASS + 1))
else echo -e "${RED}[FAIL]${NC} config-update duplicated a setting (got: $got)"; FAIL=$((FAIL + 1)); fi
# A config already damaged by the old bug (4 copies, examples gone) is repaired.
grep -v '^#   CHIEF_CFG_PLUGINS_GIT_PATH=' "$DUPDIR/healthy.sh" | awk '{print} /^CHIEF_CFG_PLUGINS_GIT_PATH=/{print; print; print}' > "$DUPDIR/broken.sh"
cfgupdate "$DUPDIR/broken.sh"
got="$(gitpath_counts "$DUPDIR/broken.sh")"
if [[ "$got" == "1 active, 3 examples" ]] && grep -q '^CHIEF_CFG_PLUGINS_GIT_PATH="deep/folder"$' "$DUPDIR/broken.sh"; then
    echo -e "${GREEN}[PASS]${NC} config-update: repairs a config with duplicated settings, keeping the value"; PASS=$((PASS + 1))
else echo -e "${RED}[FAIL]${NC} config-update didn't repair duplicates (got: $got)"; FAIL=$((FAIL + 1)); fi
rm -rf "$DUPDIR"

echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
