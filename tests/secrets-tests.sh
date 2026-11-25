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
PLAIN=$'export DEMO_TOKEN="it\'s a secret"\nfunction demo.hello() { echo hi; }'

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

  # Quiet re-key: no success line, but the outdated-password-file warning still shows.
  cp "$WORK/new.pass" "$WORK/cur.pass"
  out="$(run_edit CHIEF_SECRETS_PASSWORD_FILE="$WORK/cur.pass" -- "$f" --rekey --new-password-file="$WORK/new.pass" --quiet)"
  if [[ $? -eq 0 ]] && ! grep -q "re-keyed" <<<"$out" && grep -q "still holds the old password" <<<"$out"; then
    pass "Quiet: --rekey --quiet hides success but keeps the warning"
  else
    fail "Quiet re-key; got: $out"
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

# --- Saved passwords ---------------------------------------------------
# Run Chief code with saved-password stores pointed at throwaway locations.
# Usage: run_chief <env assignments...> -- <shell code>
run_chief() {
  local envs=()
  while [[ $# -gt 0 && $1 != "--" ]]; do envs+=("$1"); shift; done
  shift
  env NO_COLOR=1 CHIEF_PATH="$PROJECT_ROOT" CHIEF_SECRETS_STORE_DIR="$WORK/store" \
    ${envs[@]+"${envs[@]}"} "$BASH" --norc --noprofile -c '
    source "$CHIEF_PATH/libs/core/chief_library.sh" >/dev/null 2>&1
    source "$CHIEF_PATH/libs/core/plugins/secrets_chief-plugin.sh"
    eval "$1"
  ' _ "$1" </dev/null 2>&1
}

if command -v gpg >/dev/null 2>&1 && command -v openssl >/dev/null 2>&1; then
  g="$WORK/saved-gpg.secrets"
  printf '%s\n' "$PLAIN" | gpg --batch --yes --armor --passphrase-file "$WORK/old.pass" --symmetric --cipher-algo AES256 -o "$g" 2>/dev/null

  # File store (no keychain).
  out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "__chief_secrets_store_put '$g' file <<<old-secret-pass && chief.secrets_file-load '$g' && echo \"token=\$DEMO_TOKEN\"")"
  if grep -q "token=it's a secret" <<<"$out" && ! grep -q "GPG password:" <<<"$out"; then
    pass "File store: load uses the saved password, no prompt"
  else
    fail "File store: load with saved password; got: $out"
  fi

  dmode="$(stat -c '%a' "$WORK/store" 2>/dev/null || stat -f '%Lp' "$WORK/store")"
  kmode="$(stat -c '%a' "$WORK/store/.key" 2>/dev/null || stat -f '%Lp' "$WORK/store/.key")"
  if [[ "$dmode" == "700" && "$kmode" == "600" ]] && ! grep -rq "old-secret-pass" "$WORK/store"; then
    pass "File store: folder 700, key 600, password not stored in clear text"
  else
    fail "File store: modes dir=$dmode key=$kmode, or clear text found"
  fi

  # --quiet: no success message, secrets still loaded; errors still shown.
  out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "chief.secrets_file-load '$g' --quiet; echo \"token=\$DEMO_TOKEN\"")"
  if [[ "$out" == "token=it's a secret" ]]; then
    pass "Quiet: load --quiet prints nothing and still loads the secrets"
  else
    fail "Quiet load; expected only the token line; got: $out"
  fi
  out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "chief.secrets_file-load -q '$WORK/missing.secrets'")"
  if grep -q "Secrets file does not exist" <<<"$out"; then
    pass "Quiet: errors still show with -q"
  else
    fail "Quiet error; got: $out"
  fi

  out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 CHIEF_SECRETS_PASSWORD_FILE="$WORK/wrong.pass" -- "chief.secrets_file-load '$g'")"
  if grep -q "wrong password" <<<"$out"; then
    pass "Precedence: CHIEF_SECRETS_PASSWORD_FILE wins over a saved password"
  else
    fail "Precedence: expected the env password file to be used; got: $out"
  fi

  out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "chief.secrets_password-status '$g'")"
  if grep -q "Password from: saved password (file store, obfuscated)" <<<"$out" && grep -q "none available (file store is the fallback): CHIEF_SECRETS_NO_KEYCHAIN=1 is set" <<<"$out"; then
    pass "Status: reports the file store as the password source, and why there's no keychain"
  else
    fail "Status: got: $out"
  fi

  # Re-key keeps the saved password in step.
  out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "chief.secrets_file-edit '$g' --rekey --new-password-file='$WORK/new.pass' && chief.secrets_file-load '$g' && echo \"token=\$DEMO_TOKEN\"")"
  if grep -q "Saved password updated" <<<"$out" && grep -q "token=it's a secret" <<<"$out"; then
    pass "Re-key: the saved password is updated to the new one"
  else
    fail "Re-key with a saved password; got: $out"
  fi

  # A saved password that no longer works gets a clear hint.
  run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "__chief_secrets_store_put '$g' file <<<old-secret-pass" >/dev/null
  out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "chief.secrets_file-load '$g'")"
  if grep -q "The saved password didn't work" <<<"$out"; then
    pass "Stale saved password: load fails with a hint to save or remove it"
  else
    fail "Stale saved password; got: $out"
  fi

  out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "chief.secrets_password-remove '$g'; chief.secrets_password-status '$g'")"
  if grep -q "Saved password removed" <<<"$out" && grep -q "Password from: prompt" <<<"$out" && [[ -z "$(ls "$WORK/store")" ]]; then
    pass "Remove: deletes the saved password; status falls back to prompt"
  else
    fail "Remove; got: $out"
  fi

  # Saving is interactive only: without a terminal it refuses (only checkable with no tty).
  if ! { : </dev/tty; } 2>/dev/null; then
    out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "chief.secrets_password-save '$g'")"
    if grep -q "needs a terminal" <<<"$out"; then
      pass "Save: refuses without a terminal (no piped passwords)"
    else
      fail "Save without a terminal; got: $out"
    fi
  else
    skip "Save-without-terminal check (this run has a terminal)"
  fi

  # macOS Keychain, in a throwaway keychain file.
  if [[ "$(uname -s)" == "Darwin" ]] && command -v security >/dev/null 2>&1; then
    kc="$WORK/test.keychain-db"
    security create-keychain -p chief-test "$kc" >/dev/null 2>&1 && security unlock-keychain -p chief-test "$kc" >/dev/null 2>&1
    out="$(run_chief CHIEF_SECRETS_KEYCHAIN="$kc" -- "__chief_secrets_store_put '$g' keychain <<<'new-secret-pass' && chief.secrets_password-status '$g' && chief.secrets_file-load '$g' && echo \"token=\$DEMO_TOKEN\"")"
    if grep -q "Password from: saved password (keychain)" <<<"$out" && grep -q "token=it's a secret" <<<"$out" && [[ -z "$(ls "$WORK/store")" ]]; then
      pass "macOS Keychain: load uses the saved password, nothing written to the file store"
    else
      fail "macOS Keychain; got: $out"
    fi
    out="$(run_chief CHIEF_SECRETS_KEYCHAIN="$kc" -- "chief.secrets_password-remove '$g'; __chief_secrets_store_where '$g' || true")"
    if grep -q "Saved password removed" <<<"$out" && ! grep -qx "keychain" <<<"$out"; then
      pass "macOS Keychain: remove deletes the entry"
    else
      fail "macOS Keychain remove; got: $out"
    fi
    security delete-keychain "$kc" >/dev/null 2>&1
  else
    skip "macOS Keychain tests (not macOS)"
  fi
else
  skip "Saved-password tests (need gpg and openssl)"
fi

# --- Load record: what this shell loaded, and how ---------------------
if command -v gpg >/dev/null 2>&1; then
  r="$WORK/record.secrets"
  printf '%s\n' "$PLAIN" | gpg --batch --yes --armor --passphrase-file "$WORK/old.pass" --symmetric --cipher-algo AES256 -o "$r" 2>/dev/null
  printf 'chief.secrets_file-load %q --quiet\n' "$r" > "$WORK/profile.sh"

  out="$(run_chief CHIEF_SECRETS_PASSWORD_FILE="$WORK/old.pass" -- "__chief_secrets_loaded_report; chief.secrets_file-load '$r' >/dev/null; __chief_secrets_loaded_report")"
  if grep -q "none loaded in this shell" <<<"$out" && grep -q "1 file(s) loaded" <<<"$out" \
     && grep -q "loaded manually at" <<<"$out" && grep -q "password: CHIEF_SECRETS_PASSWORD_FILE" <<<"$out"; then
    pass "Load record: a load typed at the prompt shows as manual, with its password source"
  else
    fail "Load record (manual); got: $out"
  fi

  out="$(run_chief CHIEF_SECRETS_PASSWORD_FILE="$WORK/old.pass" -- "source '$WORK/profile.sh'; __chief_secrets_loaded_report")"
  if grep -q "loaded automatically from .*profile.sh" <<<"$out" && grep -q "silent (--quiet)" <<<"$out"; then
    pass "Load record: a quiet load from a start-up file shows as automatic and silent"
  else
    fail "Load record (start-up file, quiet); got: $out"
  fi

  out="$(run_chief CHIEF_SECRETS_PASSWORD_FILE="$WORK/old.pass" -- "chief.secrets_file-load '$r' >/dev/null; source \"\$CHIEF_PATH/libs/core/plugins/secrets_chief-plugin.sh\"; chief.secrets_password-status '$r'")"
  if grep -q "This shell:   loaded manually" <<<"$out"; then
    pass "Load record: survives re-sourcing the plugin (chief.reload) and shows in password-status"
  else
    fail "Load record across reload / password-status; got: $out"
  fi

  # Banner "secrets" indicator: found at start-up, loaded/silent afterwards.
  out="$(run_chief CHIEF_SECRETS_FILE="$r" -- "__chief_starting=1 __chief_banner_secrets; echo; __chief_banner_secrets; echo; CHIEF_SECRETS_PASSWORD_FILE='$WORK/old.pass' source '$WORK/profile.sh'; __chief_banner_secrets")"
  if [[ "$(sed -n 1p <<<"$out")" == "secrets: found" && "$(sed -n 2p <<<"$out")" == "secrets: not loaded" && "$(sed -n 3p <<<"$out")" == "secrets: loaded, silent" ]]; then
    pass "Banner secrets indicator: found at start-up, not loaded, then loaded, silent"
  else
    fail "Banner secrets indicator; got: $out"
  fi

  out="$(run_chief CHIEF_SECRETS_PASSWORD_FILE="$WORK/old.pass" CHIEF_CFG_BANNER=false -- "source '$WORK/profile.sh'; chief.status")"
  if grep -q "Secrets: 1 file(s) loaded in this shell" <<<"$out" && grep -q "silent (--quiet)" <<<"$out"; then
    pass "chief.status: lists the loaded secrets file, including a silent load"
  else
    fail "chief.status secrets section; got: $out"
  fi
else
  skip "Load-record tests (need gpg)"
fi

if command -v ansible-vault >/dev/null 2>&1 && command -v openssl >/dev/null 2>&1; then
  a="$WORK/saved-ansible.secrets"
  printf '%s\n' "$PLAIN" > "$a"
  ANSIBLE_VAULT_PASSWORD_FILE="$WORK/old.pass" ansible-vault encrypt "$a" >/dev/null 2>&1
  out="$(run_chief CHIEF_SECRETS_NO_KEYCHAIN=1 -- "__chief_secrets_store_put '$a' file <<<old-secret-pass && chief.secrets_file-load '$a' && echo \"token=\$DEMO_TOKEN\"")"
  if grep -q "token=it's a secret" <<<"$out"; then
    pass "Ansible Vault: load uses the saved password (passed through a pipe)"
  else
    fail "Ansible Vault with saved password; got: $out"
  fi
else
  skip "Ansible Vault saved-password test (needs ansible-vault and openssl)"
fi

echo ""
echo "Secrets tests: ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
[[ $FAILED -eq 0 ]]
