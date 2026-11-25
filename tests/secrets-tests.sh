#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
########################################################################
# Chief Test Suite - secrets plugin tests
#
# Re-keying with chief.secrets_file-edit --rekey, for both backends:
#   - GPG (skipped when gpg is not installed)
#   - Ansible Vault (skipped when ansible-vault is not installed)
# Uses password files only (no prompts), a throwaway GNUPGHOME, and a
# scratch directory, so it never touches the user's keys or secrets.
########################################################################

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0
SKIPPED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; SKIPPED=$((SKIPPED + 1)); }

WORK="$(mktemp -d)"
export GNUPGHOME="$WORK/gnupg"
mkdir -p "$GNUPGHOME" && chmod 700 "$GNUPGHOME"
cleanup() {
  command -v gpgconf >/dev/null 2>&1 && gpgconf --kill gpg-agent >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

printf 'old-secret-pass\n' > "$WORK/old.pass"
printf 'new-secret-pass\n' > "$WORK/new.pass"
printf 'wrong-pass\n' > "$WORK/wrong.pass"
PLAIN=$'export DEMO_TOKEN="it'"'"'s a secret"\nfunction demo.hello() { echo hi; }'

# Run chief.secrets_file-edit with the given env/args in a clean shell.
# Usage: run_edit <env assignments...> -- <args...>
run_edit() {
  local envs=()
  while [[ $# -gt 0 && $1 != "--" ]]; do envs+=("$1"); shift; done
  shift
  # ${envs[@]+...}: an empty array is "unbound" under set -u in Bash < 4.4.
  env NO_COLOR=1 CHIEF_PATH="$PROJECT_ROOT" ${envs[@]+"${envs[@]}"} "$BASH" --norc --noprofile -c '
    source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
    source "$CHIEF_PATH/libs/core/plugins/secrets_chief-plugin.sh"
    chief.secrets_file-edit "$@"
  ' _ "$@" </dev/null 2>&1
}

# Decrypt a GPG file with a password file in a separate GNUPGHOME (no cached passphrase).
gpg_plain() {
  local home; home="$(mktemp -d "$WORK/verify.XXXXXX")"; chmod 700 "$home"
  GNUPGHOME="$home" gpg --batch --quiet --passphrase-file "$2" --decrypt "$1" 2>/dev/null
  local rc=$?
  GNUPGHOME="$home" gpgconf --kill gpg-agent >/dev/null 2>&1
  return $rc
}

echo -e "${BLUE}[INFO]${NC} Secrets plugin tests (bash ${BASH_VERSION})"

# --- Argument checks (no backend needed) -------------------------------
out="$(run_edit -- "$WORK/nope.secrets" --rekey)"
if [[ $? -ne 0 ]] && grep -q "Nothing to re-key" <<<"$out"; then
  pass "--rekey on a missing file fails with a clear message"
else
  fail "--rekey on a missing file; got: $out"
fi

out="$(run_edit -- "$WORK/nope.secrets" --new-password-file="$WORK/new.pass")"
if [[ $? -ne 0 ]] && grep -q "only works with --rekey" <<<"$out"; then
  pass "--new-password-file without --rekey is rejected"
else
  fail "--new-password-file without --rekey; got: $out"
fi

# --- GPG ---------------------------------------------------------------
if command -v gpg >/dev/null 2>&1; then
  f="$WORK/gpg.secrets"
  printf '%s\n' "$PLAIN" | gpg --batch --yes --armor --passphrase-file "$WORK/old.pass" --symmetric --cipher-algo AES256 -o "$f" 2>/dev/null
  chmod 640 "$f"

  out="$(run_edit CHIEF_SECRETS_PASSWORD_FILE="$WORK/old.pass" -- "$f" --rekey --new-password-file="$WORK/new.pass")"
  rc=$?
  if [[ $rc -eq 0 ]] && grep -q "re-keyed (gpg)" <<<"$out" && [[ "$(gpg_plain "$f" "$WORK/new.pass")" == "$PLAIN" ]]; then
    pass "GPG: re-key keeps the content, readable with the new password"
  else
    fail "GPG: re-key (rc=$rc); got: $out"
  fi

  if ! gpg_plain "$f" "$WORK/old.pass" >/dev/null; then
    pass "GPG: the old password no longer opens the file"
  else
    fail "GPG: the old password still opens the file"
  fi

  mode="$(stat -c '%a' "$f" 2>/dev/null || stat -f '%Lp' "$f")"
  if [[ "$mode" == "640" ]]; then
    pass "GPG: file permissions are kept (640)"
  else
    fail "GPG: expected mode 640 after re-key, got $mode"
  fi

  if grep -q "still holds the old password" <<<"$out"; then
    pass "GPG: reminds you to update CHIEF_SECRETS_PASSWORD_FILE"
  else
    fail "GPG: expected a password-file reminder; got: $out"
  fi

  before="$(cat "$f")"
  out="$(run_edit CHIEF_SECRETS_PASSWORD_FILE="$WORK/wrong.pass" -- "$f" --rekey --new-password-file="$WORK/old.pass")"
  rc=$?
  leftovers="$(ls "$WORK" | grep -c '\.rekey\.')"
  if [[ $rc -ne 0 ]] && [[ "$(cat "$f")" == "$before" ]] && [[ $leftovers -eq 0 ]] && grep -q "Nothing changed" <<<"$out"; then
    pass "GPG: a wrong current password fails and leaves the file untouched"
  else
    fail "GPG: wrong password (rc=$rc, leftovers=$leftovers); got: $out"
  fi
else
  skip "GPG re-key tests (gpg not installed)"
fi

# --- Ansible Vault -----------------------------------------------------
if command -v ansible-vault >/dev/null 2>&1; then
  f="$WORK/ansible.secrets"
  printf '%s\n' "$PLAIN" > "$f"
  ANSIBLE_VAULT_PASSWORD_FILE="$WORK/old.pass" ansible-vault encrypt "$f" >/dev/null 2>&1

  out="$(run_edit ANSIBLE_VAULT_PASSWORD_FILE="$WORK/old.pass" -- "$f" --rekey --new-password-file="$WORK/new.pass")"
  rc=$?
  if [[ $rc -eq 0 ]] && grep -q "re-keyed (ansible-vault)" <<<"$out" \
     && [[ "$(ANSIBLE_VAULT_PASSWORD_FILE="$WORK/new.pass" ansible-vault view "$f" 2>/dev/null)" == "$PLAIN" ]]; then
    pass "Ansible Vault: re-key keeps the content, readable with the new password"
  else
    fail "Ansible Vault: re-key (rc=$rc); got: $out"
  fi

  if ! ANSIBLE_VAULT_PASSWORD_FILE="$WORK/old.pass" ansible-vault view "$f" >/dev/null 2>&1; then
    pass "Ansible Vault: the old password no longer opens the file"
  else
    fail "Ansible Vault: the old password still opens the file"
  fi

  before="$(cat "$f")"
  out="$(run_edit ANSIBLE_VAULT_PASSWORD_FILE="$WORK/wrong.pass" -- "$f" --rekey --new-password-file="$WORK/old.pass")"
  rc=$?
  if [[ $rc -ne 0 ]] && [[ "$(cat "$f")" == "$before" ]] && grep -q "wrong vault password" <<<"$out"; then
    pass "Ansible Vault: a wrong current password fails and leaves the file untouched"
  else
    fail "Ansible Vault: wrong password (rc=$rc); got: $out"
  fi
else
  skip "Ansible Vault re-key tests (ansible-vault not installed)"
fi

echo ""
echo "Secrets tests: ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
[[ $FAILED -eq 0 ]]
