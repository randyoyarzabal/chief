#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
########################################################################

# Chief Plugin File: secrets_chief-plugin.sh
# Author: Randy E. Oyarzabal
# Encrypted secrets file (bash env vars, functions, etc.) with Ansible Vault or GPG backend.
# Decrypt → source into current shell. Supports .chief_user-secrets / .chief_shared-secrets
# (and legacy .chief_*vault names with deprecation warnings).

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

# Resolve default secrets file: prefer new names, then legacy. Sets CHIEF_SECRETS_FILE if unset.
function __chief_secrets_resolve_default() {
  if [[ -n $CHIEF_SECRETS_FILE ]]; then
    return
  fi
  if [[ -f "$HOME/.chief_user-secrets" ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_user-secrets"
  elif [[ -f "$HOME/.chief_user-vault" ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_user-vault"
  else
    CHIEF_SECRETS_FILE="$HOME/.chief_user-secrets"
  fi
}

# Return 0 if file is Ansible Vault encrypted.
function __chief_secrets_is_ansible() {
  [[ -f "$1" ]] && grep -q '^\$ANSIBLE_VAULT;' "$1"
}

# Return 0 if file looks like GPG encrypted (armored).
function __chief_secrets_is_gpg() {
  [[ -f "$1" ]] && head -1 "$1" | grep -q '^-----BEGIN PGP'
}

# Detect backend: ansible, gpg, or empty if unknown.
function __chief_secrets_detect_backend() {
  local f="$1"
  if __chief_secrets_is_ansible "$f"; then
    echo "ansible"
    return
  fi
  if __chief_secrets_is_gpg "$f"; then
    echo "gpg"
    return
  fi
  # Binary GPG: gpg --list-packets recognizes encrypted data without password
  if [[ -f "$f" ]] && gpg --list-packets "$f" >/dev/null 2>&1; then
    echo "gpg"
    return
  fi
  echo ""
}

# Fail early (before any password prompt) when the gpg binary is missing, with an install hint.
# Without this, "command not found" was swallowed and reported as a wrong password.
function __chief_secrets_require_gpg() {
  command -v gpg >/dev/null 2>&1 && return 0
  local hint="Install GnuPG (the 'gpg' command)."
  case "$(uname -s)" in
    Darwin) hint="Install it with: brew install gnupg" ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        hint="Install it with: sudo apt-get install gnupg"
      elif command -v dnf >/dev/null 2>&1; then
        hint="Install it with: sudo dnf install gnupg2"
      elif command -v yum >/dev/null 2>&1; then
        hint="Install it with: sudo yum install gnupg2"
      elif command -v apk >/dev/null 2>&1; then
        hint="Install it with: sudo apk add gnupg"
      elif command -v pacman >/dev/null 2>&1; then
        hint="Install it with: sudo pacman -S gnupg"
      fi
      ;;
  esac
  echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} This is a GPG-encrypted secrets file but 'gpg' was not found in PATH." >&2
  echo -e "${CHIEF_COLOR_YELLOW}${hint}${CHIEF_NO_COLOR}" >&2
  return 1
}

# Report why a gpg operation failed, using gpg's own stderr (file path in $1, action in $2).
# Only blames the password when gpg actually says so; otherwise shows gpg's message.
function __chief_secrets_gpg_report() {
  local errf="$1" action="${2:-decrypt}" msg
  msg="$(grep -v '^[[:space:]]*$' "$errf" 2>/dev/null | tail -n 3)"
  if [[ "$msg" == *"bad session key"* || "$msg" == *"decryption failed"* || "$msg" == *"Bad passphrase"* || "$msg" == *"bad passphrase"* ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GPG $action failed: wrong password." >&2
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GPG $action failed (not necessarily the password)." >&2
    if [[ -n "$msg" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}gpg said:${CHIEF_NO_COLOR}" >&2
      printf '  %s\n' "$msg" >&2
    else
      echo -e "${CHIEF_COLOR_YELLOW}gpg produced no error output; check the file and your gpg setup (gpg --version).${CHIEF_NO_COLOR}" >&2
    fi
  fi
}

# Report why an ansible-vault operation failed, using ansible's own stderr (file path in $1, action in $2).
function __chief_secrets_ansible_report() {
  local errf="$1" action="${2:-decrypt}" msg
  msg="$(grep -v '^[[:space:]]*$' "$errf" 2>/dev/null | tail -n 3)"
  if [[ "$msg" == *"Decryption failed"* || "$msg" == *"Incorrect vault password"* || "$msg" == *"HMAC verification failed"* ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault $action failed: wrong vault password." >&2
  elif [[ "$msg" == *"no vault secrets"* || "$msg" == *"Vault password"*"not found"* ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault $action failed: no vault password was provided." >&2
    echo -e "${CHIEF_COLOR_YELLOW}Set ANSIBLE_VAULT_PASSWORD_FILE or run in an interactive terminal to be prompted.${CHIEF_NO_COLOR}" >&2
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault $action failed (not necessarily the password)." >&2
    if [[ -n "$msg" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}ansible-vault said:${CHIEF_NO_COLOR}" >&2
      printf '  %s\n' "$msg" >&2
    fi
  fi
}

# Print a success/progress message unless the caller (chief.secrets_file-load / -edit) runs
# with --quiet. Errors and warnings are never routed through here, so they always show.
function __chief_secrets_say() {
  [[ "${__chief_secrets_quiet:-false}" == "true" ]] && return 0
  echo -e "$@"
}

# Show deprecation warning for legacy file name (once per session).
function __chief_secrets_warn_legacy_file() {
  local base="$1"
  if [[ "$base" != ".chief_user-vault" && "$base" != ".chief_shared-vault" ]]; then
    return
  fi
  if [[ -n "${CHIEF_SECRETS_WARNED_LEGACY_FILE:-}" ]]; then
    return
  fi
  export CHIEF_SECRETS_WARNED_LEGACY_FILE=1
  echo -e "${CHIEF_COLOR_YELLOW}Deprecation:${CHIEF_NO_COLOR} .chief_*vault is deprecated; rename to .chief_*secrets (e.g. .chief_user-secrets, .chief_shared-secrets). Migration: mv $base ${base/-vault/-secrets} && export CHIEF_SECRETS_FILE=..." >&2
}

# Print a file's permission bits (e.g. 600). GNU stat first: BSD/macOS stat rejects -c, while
# GNU stat accepts -f (file-system mode) and would print the wrong thing.
function __chief_secrets_file_mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

# Prompt twice for a new password and store it in the variable named by $1.
# Fails (without setting it) when the password is empty or the two entries differ.
function __chief_secrets_read_new_password() {
  local p1 p2
  echo -e "${CHIEF_COLOR_CYAN}New GPG password:${CHIEF_NO_COLOR}" >&2
  read -rs p1 </dev/tty 2>/dev/null || read -rs p1
  echo >&2
  if [[ -z "$p1" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} The new password can't be empty. Nothing changed." >&2
    return 1
  fi
  echo -e "${CHIEF_COLOR_CYAN}Confirm new GPG password:${CHIEF_NO_COLOR}" >&2
  read -rs p2 </dev/tty 2>/dev/null || read -rs p2
  echo >&2
  if [[ "$p1" != "$p2" ]]; then
    unset p1 p2
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} The passwords don't match. Nothing changed." >&2
    return 1
  fi
  printf -v "$1" '%s' "$p1"
  unset p1 p2
}

# Change the password of an existing secrets file (Ansible Vault or GPG) without editing it.
# Usage: __chief_secrets_rekey <secrets_file> [new_password_file]
# The current password comes from ANSIBLE_VAULT_PASSWORD_FILE / CHIEF_SECRETS_PASSWORD_FILE
# or a prompt; the new one from new_password_file or a prompt (twice). On any failure the
# original file is left untouched.
# After a re-key, keep a saved password in step: replace it with the new one when known
# (<new_pw> non-empty), otherwise remove it, since it no longer opens the file.
# Usage: __chief_secrets_rekey_update_saved <secrets_file> <saved_where> [new_pw]
function __chief_secrets_rekey_update_saved() {
  local file="$1" where="$2" new_pw="$3"
  [[ -z "$where" ]] && return 0
  if [[ -n "$new_pw" ]] && __chief_secrets_store_put "$file" "$where" <<<"$new_pw"; then
    __chief_secrets_say "${CHIEF_COLOR_GREEN}Saved password updated${CHIEF_NO_COLOR} (${where} store)."
  else
    __chief_secrets_store_del "$file" >/dev/null 2>&1
    echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} The saved password was out of date and has been removed. Save the new one with ${CHIEF_COLOR_CYAN}chief.secrets_password-save $file${CHIEF_NO_COLOR}."
  fi
}

function __chief_secrets_rekey() {
  local secrets_file="$1" new_pw_file="$2" det saved_where new_known=""
  saved_where="$(__chief_secrets_store_where "$secrets_file")"
  if [[ -n "$new_pw_file" && -f "$new_pw_file" ]]; then
    IFS= read -r new_known < "$new_pw_file"
  fi
  if [[ -n "$new_pw_file" && ! -f "$new_pw_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} New password file not found: $new_pw_file" >&2
    return 1
  fi
  det="$(__chief_secrets_detect_backend "$secrets_file")"
  if [[ -z "$det" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Not a recognized encrypted file: $secrets_file (expected Ansible Vault or GPG)." >&2
    return 1
  fi

  if [[ "$det" == "ansible" ]]; then
    if ! command -v ansible-vault >/dev/null 2>&1; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault required. Install ansible-core." >&2
      return 1
    fi
    # ansible-vault reads the current password from ANSIBLE_VAULT_PASSWORD_FILE when set and
    # otherwise prompts; it prompts (twice) for the new one unless a file is given. Its output
    # stays visible (prompts) and is also captured to explain a failure.
    local errf spw args=(rekey)
    [[ -n "$new_pw_file" ]] && args+=(--new-vault-password-file "$new_pw_file")
    spw="$(__chief_secrets_saved_password_for "$secrets_file" ansible)"
    errf="$(mktemp)"
    if ! __chief_secrets_ansible_vault "$spw" "${args[@]}" "$secrets_file" 2> >(tee "$errf" >&2); then
      __chief_secrets_ansible_report "$errf" rekey
      [[ -n "$spw" ]] && __chief_secrets_saved_password_hint "$secrets_file"
      unset spw new_known
      rm -f "$errf"
      return 1
    fi
    unset spw
    rm -f "$errf"
    __chief_secrets_say "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file re-keyed (ansible-vault): $secrets_file"
    if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} ANSIBLE_VAULT_PASSWORD_FILE ($ANSIBLE_VAULT_PASSWORD_FILE) still holds the old password. Update it, or loading this file will fail."
    fi
    # ansible-vault prompted for the new password itself unless a file gave it.
    __chief_secrets_rekey_update_saved "$secrets_file" "$saved_where" "$new_known"
    unset new_known
    return 0
  fi

  # GPG: decrypt with the current password and pipe straight into a re-encrypt with the new
  # one, so the plaintext never touches the disk. Write to a temp file next to the original
  # and swap it in only after both steps succeed.
  __chief_secrets_require_gpg || return 1
  local old_pass="" new_pass="" dec_pw enc_pw out errd erre mode
  local from_saved=false
  if [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
    dec_pw=(--passphrase-file "$CHIEF_SECRETS_PASSWORD_FILE")
  else
    old_pass="$(__chief_secrets_saved_password_for "$secrets_file" gpg)"
    if [[ -n "$old_pass" ]]; then
      from_saved=true
    else
      echo -e "${CHIEF_COLOR_CYAN}Current GPG password:${CHIEF_NO_COLOR}" >&2
      read -rs old_pass </dev/tty 2>/dev/null || read -rs old_pass
      echo >&2
    fi
    dec_pw=(--passphrase-fd 3)
  fi
  if [[ -n "$new_pw_file" ]]; then
    enc_pw=(--passphrase-file "$new_pw_file")
  else
    __chief_secrets_read_new_password new_pass || { unset old_pass; return 1; }
    enc_pw=(--passphrase-fd 4)
  fi

  out="$(mktemp "${secrets_file}.rekey.XXXXXX")" || {
    unset old_pass new_pass
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Can't create a temporary file next to $secrets_file. Nothing changed." >&2
    return 1
  }
  errd="$(mktemp)"
  erre="$(mktemp)"
  gpg --batch "${dec_pw[@]}" --decrypt "$secrets_file" 2>"$errd" 3<<<"$old_pass" \
    | gpg --batch --yes --armor "${enc_pw[@]}" --symmetric --cipher-algo AES256 -o "$out" 2>"$erre" 4<<<"$new_pass"
  local rcs=("${PIPESTATUS[@]}")
  unset old_pass
  [[ -n "$new_pass" ]] && new_known="$new_pass"
  unset new_pass
  if [[ ${rcs[0]} -ne 0 ]]; then
    __chief_secrets_gpg_report "$errd" decrypt
    $from_saved && __chief_secrets_saved_password_hint "$secrets_file"
    echo -e "${CHIEF_COLOR_YELLOW}Nothing changed.${CHIEF_NO_COLOR}" >&2
    unset new_known
    rm -f "$out" "$errd" "$erre"
    return 1
  fi
  if [[ ${rcs[1]} -ne 0 ]]; then
    __chief_secrets_gpg_report "$erre" encrypt
    echo -e "${CHIEF_COLOR_YELLOW}Nothing changed.${CHIEF_NO_COLOR}" >&2
    unset new_known
    rm -f "$out" "$errd" "$erre"
    return 1
  fi
  rm -f "$errd" "$erre"
  mode="$(__chief_secrets_file_mode "$secrets_file")"
  mv -f "$out" "$secrets_file" || {
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Couldn't replace $secrets_file; the re-keyed copy is at $out" >&2
    return 1
  }
  [[ -n "$mode" ]] && chmod "$mode" "$secrets_file"
  __chief_secrets_say "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file re-keyed (gpg): $secrets_file"
  if [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} CHIEF_SECRETS_PASSWORD_FILE ($CHIEF_SECRETS_PASSWORD_FILE) still holds the old password. Update it, or loading this file will fail."
  fi
  __chief_secrets_rekey_update_saved "$secrets_file" "$saved_where" "$new_known"
  unset new_known
  return 0
}

########################################################################
# Secrets layers: shared, personal (both in the shared repo) and this host
########################################################################
# chief.secrets_file-load with no file loads every one that exists, in this order (a later file
# overrides an earlier one when both set the same variable):
#   shared    <shared folder>/.chief_shared-secrets      every host (and person) using the repo
#   personal  <shared folder>/users/<CHIEF_CFG_USER>/secrets   follows you; your own password
#   local     ~/.chief_user-secrets                      this host only; never leaves it
# The other commands take --shared / --personal / --local (or a path), and ask when it's unclear.

# Path of a layer's file (it may not exist yet). Returns 1 when the layer isn't available here.
function __chief_secrets_layer_file() {
  local dir
  case "$1" in
    shared)
      declare -F __chief_shared_dir >/dev/null || return 1
      dir="$(__chief_shared_dir)"
      [[ -n "$dir" ]] || return 1
      if [[ ! -f "$dir/.chief_shared-secrets" && -f "$dir/.chief_shared-vault" ]]; then
        printf '%s' "$dir/.chief_shared-vault"
      else
        printf '%s' "$dir/.chief_shared-secrets"
      fi
      ;;
    personal)
      declare -F __chief_user_dir >/dev/null || return 1
      dir="$(__chief_user_dir)" || return 1
      [[ -n "$dir" ]] || return 1
      printf '%s' "$dir/secrets"
      ;;
    local)
      if [[ ! -f "$HOME/.chief_user-secrets" && -f "$HOME/.chief_user-vault" ]]; then
        printf '%s' "$HOME/.chief_user-vault"
      else
        printf '%s' "$HOME/.chief_user-secrets"
      fi
      ;;
    *) return 1 ;;
  esac
}

# Why a layer isn't available, for error messages.
function __chief_secrets_layer_unavailable() {
  case "$1" in
    shared) echo "no shared plugins folder is configured (see chief.plugins-repo)" ;;
    personal)
      if [[ -z "${CHIEF_CFG_USER:-}" ]]; then
        echo "CHIEF_CFG_USER isn't set (chief.config-set user <name>)"
      else
        echo "it needs a shared plugins folder and a valid CHIEF_CFG_USER"
      fi
      ;;
  esac
}

# "layer<TAB>path" for each secrets file that exists, in load order. A CHIEF_SECRETS_FILE set to
# some other file is listed last as "custom".
function __chief_secrets_existing_layers() {
  local layer f seen="|"
  for layer in shared personal local; do
    f="$(__chief_secrets_layer_file "$layer")" || continue
    if [[ -f "$f" && "$seen" != *"|$f|"* ]]; then
      printf '%s\t%s\n' "$layer" "$f"
      seen+="$f|"
    fi
  done
  if [[ -n "${CHIEF_SECRETS_FILE:-}" && -f "${CHIEF_SECRETS_FILE}" && "$seen" != *"|${CHIEF_SECRETS_FILE}|"* ]]; then
    printf '%s\t%s\n' "custom" "$CHIEF_SECRETS_FILE"
  fi
}

# Which layer a file belongs to ("shared", "personal", "local" or "custom").
function __chief_secrets_layer_of() {
  local layer f
  for layer in shared personal local; do
    f="$(__chief_secrets_layer_file "$layer")" || continue
    [[ "$f" == "$1" ]] && { echo "$layer"; return 0; }
  done
  echo "custom"
}

# Pick the secrets file a command works on. Usage: __chief_secrets_pick_file <create|existing> [layer]
# With a layer, its file. Without: the only existing file, or ask (on the terminal) which layer.
# "create" may pick a layer whose file doesn't exist yet. Prints the path; messages go to stderr.
function __chief_secrets_pick_file() {
  local mode="$1" layer="$2" f why
  if [[ -n "$layer" ]]; then
    if ! f="$(__chief_secrets_layer_file "$layer")"; then
      why="$(__chief_secrets_layer_unavailable "$layer")"
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} No ${layer} secrets here: ${why}." >&2
      return 1
    fi
    printf '%s' "$f"
    return 0
  fi
  local lines=() choices=() line
  while IFS= read -r line; do lines+=("$line"); done < <(__chief_secrets_existing_layers)
  if [[ "$mode" == "existing" ]]; then
    if (( ${#lines[@]} == 0 )); then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} No secrets file found (shared, personal or this host). Create one with chief.secrets_file-edit." >&2
      return 1
    fi
    if (( ${#lines[@]} == 1 )); then
      printf '%s' "${lines[0]#*$'\t'}"
      return 0
    fi
    choices=("${lines[@]}")
  else
    if (( ${#lines[@]} == 1 )); then
      printf '%s' "${lines[0]#*$'\t'}"
      return 0
    fi
    for layer in shared personal local; do
      f="$(__chief_secrets_layer_file "$layer")" || continue
      choices+=("${layer}"$'\t'"${f}")
    done
  fi
  if ! { : </dev/tty; } 2>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Which secrets file? Pass --shared, --personal, --local or a path (no terminal to ask on)." >&2
    return 1
  fi
  local i=1 c label reply
  echo -e "${CHIEF_COLOR_CYAN}Which secrets file?${CHIEF_NO_COLOR}" >&2
  for c in "${choices[@]}"; do
    case "${c%%$'\t'*}" in
      shared) label="shared (every host using the repo; in a team repo, everyone)" ;;
      personal) label="personal (follows you to every host)" ;;
      local) label="this host only" ;;
      *) label="${c%%$'\t'*}" ;;
    esac
    [[ -f "${c#*$'\t'}" ]] || label+=", new"
    echo -e "  ${i}) ${label}: $(__chief_secrets_tilde "${c#*$'\t'}")" >&2
    i=$((i + 1))
  done
  echo -ne "Choose 1-$(( i - 1 )): " >&2
  read -r reply </dev/tty
  if [[ ! "$reply" =~ ^[0-9]+$ ]] || (( reply < 1 || reply >= i )); then
    echo -e "${CHIEF_COLOR_YELLOW}Cancelled.${CHIEF_NO_COLOR}" >&2
    return 1
  fi
  c="${choices[$((reply - 1))]}"
  printf '%s' "${c#*$'\t'}"
}

# After changing a secrets file in the shared repo (shared or personal), offer to commit and push.
function __chief_secrets_offer_commit() {
  local file="$1" layer
  layer="$(__chief_secrets_layer_of "$file")"
  [[ "$layer" == "shared" || "$layer" == "personal" ]] || return 0
  declare -F __chief_repo_offer_commit >/dev/null || return 0
  __chief_repo_offer_commit "$file" "secrets: update ${layer} secrets"
}

function chief.secrets_file-edit() {
  __chief_secrets_resolve_default
  if [[ -z $CHIEF_SECRETS_FILE ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_user-secrets"
  fi

  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--shared|--personal|--local|<file>] [--load] [--backend=gpg|ansible] [-q]
       $FUNCNAME [--shared|--personal|--local|<file>] --rekey [--new-password-file=PATH] [--load] [-q]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit/create a Bash shell secrets file (env vars, functions, etc.) encrypted with Ansible Vault or GPG.
Content is decrypted → edited → re-encrypted. Load means decrypt → source into current shell.

${CHIEF_COLOR_GREEN}Backends:${CHIEF_NO_COLOR}
- ansible-vault (ansible-core 2.9+), gpg (symmetric AES256). Backend chosen when creating; auto-detected when editing.

${CHIEF_COLOR_GREEN}Password (first match wins):${CHIEF_NO_COLOR}
1. Password file: ANSIBLE_VAULT_PASSWORD_FILE (Ansible Vault) or CHIEF_SECRETS_PASSWORD_FILE (GPG)
2. Saved password: macOS Keychain, Linux keyring, or obfuscated file
   (save it with chief.secrets_password-save; check with chief.secrets_password-status)
3. Prompt

${CHIEF_COLOR_GREEN}Which file (you choose; Chief never guesses):${CHIEF_NO_COLOR}
  --shared        <shared folder>/.chief_shared-secrets: every host (and person) using the repo
  --personal      <shared folder>/users/\$CHIEF_CFG_USER/secrets: follows you to every host
  --local         ~/.chief_user-secrets: this host only, never leaves it
  <file>          Any file by path
  (none)          The only one that exists, or Chief asks which. Editing a shared or personal file
                  offers to commit and push it so your other hosts get it.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  --load          Load (source) secrets into environment after editing
  --backend=...   For new files only: gpg or ansible (default: gpg if available, else ansible).
                  Once a file exists, backend is auto-detected; do not pass --backend for edit/load.
  --rekey         Change the password of an existing file (Ansible Vault or GPG) without
                  opening the editor. Asks for the current password (or reads the password
                  file above), then the new one twice. The file is unchanged if anything fails.
  --new-password-file=PATH
                  With --rekey: read the new password from PATH instead of prompting.
  -q, --quiet     No success or progress messages (errors and warnings still show).
                  Passed on to the load when used with --load.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -?, --help      Show this help

${CHIEF_COLOR_RED}⚠ SHARED REPO:${CHIEF_NO_COLOR} shared secrets can be opened by anyone with the repo and the password (in a
  team repo, everyone). Personal secrets are in the repo too, so anyone who can read it holds a copy
  of the encrypted file: use a long, unique password for it.
  Anything too sensitive for that belongs in --local.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME --personal                  # your secrets, on every host
  $FUNCNAME --shared --load
  $FUNCNAME ~/.my-secrets --backend=gpg
  $FUNCNAME --rekey                     # change the password of \$CHIEF_SECRETS_FILE
  $FUNCNAME ~/.my-secrets --rekey --new-password-file=~/.new-pass
"
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  local no_load=true secrets_file="" backend="" rekey=false new_pw_file="" layer=""
  local __chief_secrets_quiet=false
  local arg
  for arg in "$@"; do
    case "$arg" in
      --shared) layer=shared ;;
      --personal) layer=personal ;;
      --local) layer=local ;;
      --load) no_load=false ;;
      -q|--quiet) __chief_secrets_quiet=true ;;
      --backend=*) backend="${arg#--backend=}" ;;
      --rekey) rekey=true ;;
      --new-password-file=*) new_pw_file="${arg#--new-password-file=}"; new_pw_file="${new_pw_file/#\~/$HOME}" ;;
      -?|--help) ;;
      *) [[ -z "$secrets_file" ]] && secrets_file="$arg" ;;
    esac
  done

  if [[ -n "$secrets_file" && -n "$layer" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Give either a file or --${layer}, not both." >&2
    return 1
  fi
  if [[ -z "$secrets_file" ]]; then
    if $rekey; then
      secrets_file="$(__chief_secrets_pick_file existing "$layer")" || return 1
    else
      secrets_file="$(__chief_secrets_pick_file create "$layer")" || return 1
    fi
  fi

  # Resolve path
  if [[ "$secrets_file" != /* ]]; then
    secrets_file="$(realpath "$secrets_file" 2>/dev/null || echo "$(pwd)/$secrets_file")"
  fi

  # Deprecation: legacy file name
  __chief_secrets_warn_legacy_file "$(basename "$secrets_file")"

  if [[ -n "$new_pw_file" ]] && ! $rekey; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} --new-password-file only works with --rekey." >&2
    return 1
  fi

  # Re-key: change the password of an existing file, no editing.
  if $rekey; then
    if [[ -n "$backend" ]]; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} --backend is for new files; --rekey detects the backend of the existing file." >&2
      return 1
    fi
    if [[ ! -f "$secrets_file" ]]; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Nothing to re-key: $secrets_file does not exist." >&2
      return 1
    fi
    __chief_secrets_rekey "$secrets_file" "$new_pw_file" || return 1
    __chief_secrets_offer_commit "$secrets_file"
    if ! $no_load; then
      if $__chief_secrets_quiet; then chief.secrets_file-load "$secrets_file" --quiet; else chief.secrets_file-load "$secrets_file"; fi
    fi
    return 0
  fi

  # New file
  if [[ ! -f "$secrets_file" ]]; then
    if command -v gpg >/dev/null 2>&1 && [[ "$backend" != "ansible" ]]; then
      backend="${backend:-gpg}"
    else
      backend="${backend:-ansible}"
    fi
    if [[ "$backend" == "ansible" ]] && ! command -v ansible-vault >/dev/null 2>&1; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault required for --backend=ansible. Install ansible-core or use --backend=gpg."
      return 1
    fi
    if [[ "$backend" == "gpg" ]] && ! command -v gpg >/dev/null 2>&1; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} gpg required for --backend=gpg. Install gnupg or use --backend=ansible."
      return 1
    fi

    mkdir -p "$(dirname "$secrets_file")" || { echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Cannot create directory for $secrets_file"; return 1; }
    local editor="${EDITOR:-vi}" new_layer
    new_layer="$(__chief_secrets_layer_of "$secrets_file")"
    __chief_secrets_say "${CHIEF_COLOR_GREEN}Creating new secrets file:${CHIEF_NO_COLOR} $secrets_file (backend: $backend)"
    if [[ "$new_layer" == "personal" || "$new_layer" == "shared" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} This file goes in the shared repo, so everyone who can read the repo gets a copy of it, encrypted. Use a long, unique password: they can try to guess it offline." >&2
    fi
    # Write the plaintext in a private temp file, never next to the encrypted one (in a repo it
    # could otherwise be committed by accident if anything stopped halfway).
    local tmpf
    tmpf="$(mktemp)"
    $editor "$tmpf"
    if [[ ! -s "$tmpf" ]]; then
      rm -f "$tmpf"
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Nothing was saved in the editor. No file created."
      return 1
    fi
    if ! $no_load; then
      source "$tmpf" || true
    fi
    if [[ "$backend" == "ansible" ]]; then
      ansible-vault encrypt --output "$secrets_file" "$tmpf" || { rm -f "$tmpf"; return 1; }
    else
      if [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
        gpg --batch --yes --armor --passphrase-file "$CHIEF_SECRETS_PASSWORD_FILE" --symmetric --cipher-algo AES256 -o "$secrets_file" "$tmpf" || { rm -f "$tmpf"; return 1; }
      else
        gpg --yes --armor --symmetric --cipher-algo AES256 -o "$secrets_file" "$tmpf" || { rm -f "$tmpf"; return 1; }
      fi
    fi
    rm -f "$tmpf"
    __chief_secrets_say "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file created and encrypted."
    __chief_secrets_offer_commit "$secrets_file"
    if $no_load; then
      __chief_secrets_say "${CHIEF_COLOR_BLUE}Load with:${CHIEF_NO_COLOR} chief.secrets_file-load ${secrets_file:+$secrets_file}"
    fi
    return 0
  fi

  # Existing file: detect backend
  local det
  det="$(__chief_secrets_detect_backend "$secrets_file")"
  if [[ -z "$det" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Not a recognized encrypted file: $secrets_file (expected Ansible Vault or GPG)."
    return 1
  fi

  # Closing the editor without changes leaves the file alone: no re-encrypt, no commit offer.
  local unchanged=false before_sum
  if [[ "$det" == "ansible" ]]; then
    if ! command -v ansible-vault >/dev/null 2>&1; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault required. Install ansible-core."
      return 1
    fi
    local spw
    before_sum="$(cksum < "$secrets_file")"
    spw="$(__chief_secrets_saved_password_for "$secrets_file" ansible)"
    __chief_secrets_ansible_vault "$spw" edit "$secrets_file" || {
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault edit failed (see ansible-vault output above): $secrets_file" >&2
      [[ -n "$spw" ]] && __chief_secrets_saved_password_hint "$secrets_file"
      unset spw
      return 1
    }
    unset spw
    [[ "$(cksum < "$secrets_file")" == "$before_sum" ]] && unchanged=true
  else
    __chief_secrets_require_gpg || return 1
    local tmpf errf editor gpg_pass
    tmpf="$(mktemp)"
    errf="$(mktemp)"
    editor="${EDITOR:-vi}"
    if [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
      gpg --batch --passphrase-file "$CHIEF_SECRETS_PASSWORD_FILE" --decrypt "$secrets_file" > "$tmpf" 2>"$errf" || {
        __chief_secrets_gpg_report "$errf" decrypt
        rm -f "$tmpf" "$errf"
        return 1
      }
    else
      local from_saved=false
      gpg_pass="$(__chief_secrets_saved_password_for "$secrets_file" gpg)"
      if [[ -n "$gpg_pass" ]]; then
        from_saved=true
      else
        echo -e "${CHIEF_COLOR_CYAN}GPG password:${CHIEF_NO_COLOR}" >&2
        read -rs gpg_pass </dev/tty 2>/dev/null || read -rs gpg_pass
        echo >&2
      fi
      gpg --batch --passphrase-fd 0 --decrypt "$secrets_file" > "$tmpf" 2>"$errf" <<< "$gpg_pass" || {
        unset gpg_pass
        __chief_secrets_gpg_report "$errf" decrypt
        $from_saved && __chief_secrets_saved_password_hint "$secrets_file"
        rm -f "$tmpf" "$errf"
        return 1
      }
    fi
    rm -f "$errf"
    before_sum="$(cksum < "$tmpf")"
    "$editor" "$tmpf"
    if [[ "$(cksum < "$tmpf")" == "$before_sum" ]]; then
      unchanged=true
      unset gpg_pass
    elif [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
      errf="$(mktemp)"
      gpg --batch --yes --armor --passphrase-file "$CHIEF_SECRETS_PASSWORD_FILE" --symmetric --cipher-algo AES256 -o "$secrets_file" "$tmpf" 2>"$errf" || {
        __chief_secrets_gpg_report "$errf" encrypt
        rm -f "$tmpf" "$errf"
        return 1
      }
    else
      errf="$(mktemp)"
      gpg --batch --yes --armor --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "$secrets_file" "$tmpf" 2>"$errf" <<< "$gpg_pass" || {
        unset gpg_pass
        __chief_secrets_gpg_report "$errf" encrypt
        rm -f "$tmpf" "$errf"
        return 1
      }
      unset gpg_pass
    fi
    rm -f "$tmpf" "$errf"
  fi

  if $unchanged; then
    __chief_secrets_say "${CHIEF_COLOR_BLUE}No changes:${CHIEF_NO_COLOR} $secrets_file was left as it was."
  else
    __chief_secrets_offer_commit "$secrets_file"
  fi
  if $no_load; then
    $unchanged || __chief_secrets_say "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file edited (not loaded). Load with: chief.secrets_file-load ${secrets_file:+$secrets_file}"
  else
    if $__chief_secrets_quiet; then chief.secrets_file-load "$secrets_file" --quiet; else chief.secrets_file-load "$secrets_file"; fi
  fi
}

########################################################################
# Stored passwords: OS keychain, or an obfuscated file as a fallback
########################################################################
# Saved only interactively (chief.secrets_password-save), then used by load/edit/rekey so
# you aren't prompted. Order everywhere: explicit password file env var > stored > prompt.
#   macOS:  Keychain (security). The password reaches `security -i` on stdin, never argv.
#   Linux:  desktop keyring via secret-tool (libsecret), when a keyring service is running.
#   Else:   ~/.chief_secrets-store/<id>, AES-256 with a random key file kept next to it.
#           That is obfuscation, not protection from someone who can read your account.
# Entries are keyed by the secrets file's absolute path.
# Test hooks: CHIEF_SECRETS_KEYCHAIN (macOS keychain file), CHIEF_SECRETS_STORE_DIR,
#             CHIEF_SECRETS_NO_KEYCHAIN=1 (pretend no keychain).

CHIEF_SECRETS_STORE_SERVICE="chief-secrets"

# Absolute path of a secrets file (the key for stored passwords).
function __chief_secrets_abs_path() {
  local f="$1"
  if [[ "$f" != /* ]]; then
    f="$(realpath "$f" 2>/dev/null || echo "$(pwd)/$f")"
  fi
  echo "$f"
}

# Which OS keychain is usable: "macos", "linux" or "" (none).
function __chief_secrets_keychain_kind() {
  [[ "${CHIEF_SECRETS_NO_KEYCHAIN:-}" == "1" ]] && return 0
  if [[ "$(uname -s)" == "Darwin" ]] && command -v security >/dev/null 2>&1; then
    echo "macos"
    return 0
  fi
  if command -v secret-tool >/dev/null 2>&1; then
    # A lookup that finds nothing exits 1 quietly; without a keyring service it prints an error.
    local err
    err="$(secret-tool lookup service "${CHIEF_SECRETS_STORE_SERVICE}-probe" account probe 2>&1 >/dev/null)"
    [[ -z "$err" ]] && echo "linux"
  fi
}

function __chief_secrets_store_dir() {
  echo "${CHIEF_SECRETS_STORE_DIR:-$HOME/.chief_secrets-store}"
}

# Stable file name for a secrets file's entry in the fallback store.
function __chief_secrets_store_id() {
  printf '%s' "$1" | openssl dgst -sha256 | awk '{print $NF}'
}

# Escape a value for a double-quoted argument in `security -i`.
function __chief_secrets_sec_quote() {
  local v="${1//\\/\\\\}"
  printf '%s' "${v//\"/\\\"}"
}

# Store the password read from stdin for <secrets_file> in <store> (keychain|file).
function __chief_secrets_store_put() {
  local file="$1" store="$2" pw kind dir key id
  IFS= read -r pw
  if [[ "$store" == "keychain" ]]; then
    kind="$(__chief_secrets_keychain_kind)"
    if [[ "$kind" == "macos" ]]; then
      local kc=""
      [[ -n "${CHIEF_SECRETS_KEYCHAIN:-}" ]] && kc=" \"$(__chief_secrets_sec_quote "$CHIEF_SECRETS_KEYCHAIN")\""
      printf 'add-generic-password -U -s "%s" -a "%s" -l "%s" -w "%s"%s\n' \
        "$CHIEF_SECRETS_STORE_SERVICE" "$(__chief_secrets_sec_quote "$file")" \
        "$(__chief_secrets_sec_quote "Chief secrets: $file")" "$(__chief_secrets_sec_quote "$pw")" "$kc" \
        | security -i >/dev/null 2>&1
    elif [[ "$kind" == "linux" ]]; then
      printf '%s' "$pw" | secret-tool store --label="Chief secrets: $file" \
        service "$CHIEF_SECRETS_STORE_SERVICE" account "$file" >/dev/null 2>&1
    else
      unset pw
      return 1
    fi
  else
    command -v openssl >/dev/null 2>&1 || { unset pw; return 1; }
    dir="$(__chief_secrets_store_dir)"
    key="$dir/.key"
    ( umask 077; mkdir -p "$dir" ) || { unset pw; return 1; }
    chmod 700 "$dir"
    if [[ ! -s "$key" ]]; then
      ( umask 077; openssl rand -hex 32 > "$key" ) || { unset pw; return 1; }
    fi
    id="$(__chief_secrets_store_id "$file")"
    ( umask 077; printf '%s\n' "$pw" | openssl enc -aes-256-cbc -pbkdf2 -salt -a -pass "file:$key" -out "$dir/$id" ) || { unset pw; return 1; }
  fi
  unset pw
  # Read it back: `security -i` does not report failures through its exit code.
  [[ -n "$(__chief_secrets_store_get "$file" "$store")" ]]
}

# Print the stored password for <secrets_file>; optional <store> limits where to look.
# Returns 1 when none is stored.
function __chief_secrets_store_get() {
  local file="$1" only="${2:-}" kind pw dir id
  if [[ -z "$only" || "$only" == "keychain" ]]; then
    kind="$(__chief_secrets_keychain_kind)"
    if [[ "$kind" == "macos" ]]; then
      if [[ -n "${CHIEF_SECRETS_KEYCHAIN:-}" ]]; then
        pw="$(security find-generic-password -s "$CHIEF_SECRETS_STORE_SERVICE" -a "$file" -w "$CHIEF_SECRETS_KEYCHAIN" 2>/dev/null)"
      else
        pw="$(security find-generic-password -s "$CHIEF_SECRETS_STORE_SERVICE" -a "$file" -w 2>/dev/null)"
      fi
    elif [[ "$kind" == "linux" ]]; then
      pw="$(secret-tool lookup service "$CHIEF_SECRETS_STORE_SERVICE" account "$file" 2>/dev/null)"
    fi
    if [[ -n "$pw" ]]; then
      printf '%s' "$pw"
      return 0
    fi
  fi
  if [[ -z "$only" || "$only" == "file" ]]; then
    dir="$(__chief_secrets_store_dir)"
    id="$(__chief_secrets_store_id "$file" 2>/dev/null)"
    if [[ -n "$id" && -f "$dir/$id" && -f "$dir/.key" ]]; then
      pw="$(openssl enc -d -aes-256-cbc -pbkdf2 -a -pass "file:$dir/.key" -in "$dir/$id" 2>/dev/null)"
      if [[ -n "$pw" ]]; then
        printf '%s' "$pw"
        return 0
      fi
    fi
  fi
  return 1
}

# Where a password for <secrets_file> is stored: "keychain", "file" or "" (none).
function __chief_secrets_store_where() {
  if __chief_secrets_store_get "$1" keychain >/dev/null; then
    echo "keychain"
  elif __chief_secrets_store_get "$1" file >/dev/null; then
    echo "file"
  fi
}

# Remove the stored password for <secrets_file> from every store. Returns 1 if none existed.
function __chief_secrets_store_del() {
  local file="$1" kind found=1 dir id
  kind="$(__chief_secrets_keychain_kind)"
  if [[ "$kind" == "macos" ]]; then
    if [[ -n "${CHIEF_SECRETS_KEYCHAIN:-}" ]]; then
      security delete-generic-password -s "$CHIEF_SECRETS_STORE_SERVICE" -a "$file" "$CHIEF_SECRETS_KEYCHAIN" >/dev/null 2>&1 && found=0
    else
      security delete-generic-password -s "$CHIEF_SECRETS_STORE_SERVICE" -a "$file" >/dev/null 2>&1 && found=0
    fi
  elif [[ "$kind" == "linux" ]]; then
    if [[ -n "$(secret-tool lookup service "$CHIEF_SECRETS_STORE_SERVICE" account "$file" 2>/dev/null)" ]]; then
      secret-tool clear service "$CHIEF_SECRETS_STORE_SERVICE" account "$file" >/dev/null 2>&1 && found=0
    fi
  fi
  dir="$(__chief_secrets_store_dir)"
  id="$(__chief_secrets_store_id "$file" 2>/dev/null)"
  if [[ -n "$id" && -f "$dir/$id" ]]; then
    rm -f "$dir/$id" && found=0
  fi
  return $found
}

# Run ansible-vault <subcommand> [args...]; when <saved_pw> is non-empty, pass it through a
# pipe (--vault-password-file /dev/fd/N) so it is never written to disk.
# Usage: __chief_secrets_ansible_vault <saved_pw> <subcommand> [args...]
function __chief_secrets_ansible_vault() {
  local spw="$1"
  shift
  if [[ -n "$spw" ]]; then
    ansible-vault "$1" --vault-password-file <(printf '%s\n' "$spw") "${@:2}"
  else
    ansible-vault "$@"
  fi
}

# The saved password for <secrets_file>, unless the backend's password file env var is set
# (that one wins). Prints nothing when there is none to use.
function __chief_secrets_saved_password_for() {
  local file="$1" det="$2"
  if [[ "$det" == "ansible" && -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
    return 0
  fi
  if [[ "$det" == "gpg" && -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" && -f "${CHIEF_SECRETS_PASSWORD_FILE}" ]]; then
    return 0
  fi
  __chief_secrets_store_get "$(__chief_secrets_abs_path "$file")"
}

function __chief_secrets_saved_password_hint() {
  echo -e "${CHIEF_COLOR_YELLOW}The saved password didn't work${CHIEF_NO_COLOR} (the file's password may have changed). Save the right one with ${CHIEF_COLOR_CYAN}chief.secrets_password-save $1${CHIEF_NO_COLOR}, or remove it with ${CHIEF_COLOR_CYAN}chief.secrets_password-remove $1${CHIEF_NO_COLOR}." >&2
}

# Return 0 if the password on stdin decrypts <secrets_file> (either backend).
function __chief_secrets_check_password() {
  local file="$1" pw det
  IFS= read -r pw
  det="$(__chief_secrets_detect_backend "$file")"
  if [[ "$det" == "ansible" ]]; then
    ansible-vault view --vault-password-file <(printf '%s\n' "$pw") "$file" >/dev/null 2>&1
  elif [[ "$det" == "gpg" ]]; then
    gpg --batch --quiet --passphrase-fd 3 --decrypt "$file" >/dev/null 2>&1 3<<<"$pw"
  else
    return 1
  fi
  local rc=$?
  unset pw
  return $rc
}

function chief.secrets_password-save() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--shared|--personal|--local|<file>] [--store=auto|keychain|file]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Save the password of an encrypted secrets file (Ansible Vault or GPG) so that
chief.secrets_file-load, chief.secrets_file-edit and --rekey don't prompt for it.
The password can only be entered at this prompt: never as an argument, environment
variable or piped input, so it never sits in shell history or a plain-text file.
It is checked against the file before it is saved.

${CHIEF_COLOR_GREEN}Where it is stored (--store=auto picks the first available):${CHIEF_NO_COLOR}
- keychain  macOS Keychain, or the Linux desktop keyring (secret-tool / libsecret).
            Encrypted by the OS and unlocked by your login.
- file      ~/.chief_secrets-store/ (mode 700), encrypted with a random key kept beside it.
            ${CHIEF_COLOR_YELLOW}Obfuscation only:${CHIEF_NO_COLOR} keeps it out of casual reads, backups and git,
            but anyone who can read your account can recover it. Used where there is no keychain
            (for example headless servers).

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  [secrets-file]  Optional path (default: \$CHIEF_SECRETS_FILE)
  --store=...     auto (default), keychain or file

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -?, --help      Show this help

${CHIEF_COLOR_MAGENTA}Notes:${CHIEF_NO_COLOR}
- ANSIBLE_VAULT_PASSWORD_FILE / CHIEF_SECRETS_PASSWORD_FILE, when set, still take precedence.
- The entry is tied to the file's path; save again after moving or renaming the file.
- Remove with chief.secrets_password-remove; check with chief.secrets_password-status.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME
  $FUNCNAME ~/.chief_user-secrets
  $FUNCNAME ~/chief_plugins/.chief_shared-secrets --store=file
"
  local arg secrets_file="" store="auto" layer=""
  for arg in "$@"; do
    case "$arg" in
      -\?|--help) echo -e "${USAGE}"; return 0 ;;
      --store=*) store="${arg#--store=}" ;;
      --shared) layer=shared ;;
      --personal) layer=personal ;;
      --local) layer=local ;;
      *) [[ -z "$secrets_file" ]] && secrets_file="$arg" ;;
    esac
  done
  if [[ -z "$secrets_file" ]]; then
    secrets_file="$(__chief_secrets_pick_file existing "$layer")" || return 1
  fi
  secrets_file="$(__chief_secrets_abs_path "$secrets_file")"

  if [[ ! -f "$secrets_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Secrets file does not exist: $secrets_file" >&2
    return 1
  fi
  if [[ -z "$(__chief_secrets_detect_backend "$secrets_file")" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Not a recognized encrypted file (expected Ansible Vault or GPG): $secrets_file" >&2
    return 1
  fi
  case "$store" in
    auto) [[ -n "$(__chief_secrets_keychain_kind)" ]] && store="keychain" || store="file" ;;
    keychain)
      if [[ -z "$(__chief_secrets_keychain_kind)" ]]; then
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} No keychain available here (macOS Keychain, or secret-tool with a running keyring). Use --store=file." >&2
        return 1
      fi ;;
    file) ;;
    *) echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} --store must be auto, keychain or file." >&2; return 1 ;;
  esac
  if [[ "$store" == "file" ]] && ! command -v openssl >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} The file store needs openssl, which was not found." >&2
    return 1
  fi
  # Interactive only: read from the terminal, never from stdin.
  if ! { : </dev/tty; } 2>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} $FUNCNAME needs a terminal; the password can only be typed at its prompt." >&2
    return 1
  fi

  local pw
  echo -e "${CHIEF_COLOR_CYAN}Password for ${secrets_file}:${CHIEF_NO_COLOR}" >&2
  read -rs pw </dev/tty
  echo >&2
  if [[ -z "$pw" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} No password entered. Nothing saved." >&2
    return 1
  fi
  if ! __chief_secrets_check_password "$secrets_file" <<<"$pw"; then
    unset pw
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} That password doesn't open $secrets_file. Nothing saved." >&2
    return 1
  fi
  if ! __chief_secrets_store_put "$secrets_file" "$store" <<<"$pw"; then
    unset pw
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Couldn't save the password to the ${store} store." >&2
    return 1
  fi
  unset pw
  if [[ "$store" == "keychain" ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Password saved in the $( [[ "$(__chief_secrets_keychain_kind)" == "macos" ]] && echo "macOS Keychain" || echo "keyring") for $secrets_file."
  else
    echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Password saved (obfuscated) in $(__chief_secrets_store_dir) for $secrets_file."
    echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} This store is obfuscation, not encryption: anyone who can read your account can recover the password."
  fi
}

function chief.secrets_password-remove() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--shared|--personal|--local|<file>]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Remove the saved password of a secrets file from the keychain and the file store.
Chief prompts for it again afterwards. The secrets file itself is not touched.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  [secrets-file]  Optional path (default: \$CHIEF_SECRETS_FILE)
"
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi
  local secrets_file="" layer="" arg
  for arg in "$@"; do
    case "$arg" in
      --shared) layer=shared ;;
      --personal) layer=personal ;;
      --local) layer=local ;;
      *) [[ -z "$secrets_file" ]] && secrets_file="$arg" ;;
    esac
  done
  if [[ -z "$secrets_file" ]]; then
    secrets_file="$(__chief_secrets_pick_file existing "$layer")" || return 1
  fi
  secrets_file="$(__chief_secrets_abs_path "$secrets_file")"
  if __chief_secrets_store_del "$secrets_file"; then
    echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Saved password removed for $secrets_file."
  else
    echo -e "${CHIEF_COLOR_YELLOW}Nothing to remove:${CHIEF_NO_COLOR} no saved password for $secrets_file."
  fi
}

function chief.secrets_password-status() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--shared|--personal|--local|<file>]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Show where Chief will get the password of a secrets file from when loading or editing it:
a password file environment variable, a saved password (keychain or file), or a prompt.
With no file, shows every secrets file that exists (shared, personal, this host).

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  [secrets-file]  Optional path (default: \$CHIEF_SECRETS_FILE)
"
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi
  local secrets_file="" det where kind layer="" arg
  for arg in "$@"; do
    case "$arg" in
      --shared) layer=shared ;;
      --personal) layer=personal ;;
      --local) layer=local ;;
      *) [[ -z "$secrets_file" ]] && secrets_file="$arg" ;;
    esac
  done
  if [[ -z "$secrets_file" && -n "$layer" ]]; then
    secrets_file="$(__chief_secrets_pick_file existing "$layer")" || return 1
  fi
  if [[ -z "$secrets_file" ]]; then
    local lines=() line first=true
    while IFS= read -r line; do lines+=("$line"); done < <(__chief_secrets_existing_layers)
    if (( ${#lines[@]} == 0 )); then
      echo -e "${CHIEF_COLOR_YELLOW}No secrets file found${CHIEF_NO_COLOR} (shared, personal or this host). Create one with chief.secrets_file-edit."
      return 1
    fi
    for line in "${lines[@]}"; do
      $first || echo
      first=false
      echo -e "${CHIEF_COLOR_MAGENTA}[${line%%$'\t'*}]${CHIEF_NO_COLOR}"
      chief.secrets_password-status "${line#*$'\t'}"
    done
    return 0
  fi
  secrets_file="$(__chief_secrets_abs_path "$secrets_file")"
  echo -e "${CHIEF_COLOR_BLUE}Secrets file:${CHIEF_NO_COLOR} $secrets_file"
  if [[ ! -f "$secrets_file" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Not found.${CHIEF_NO_COLOR}"
    return 1
  fi
  det="$(__chief_secrets_detect_backend "$secrets_file")"
  echo -e "${CHIEF_COLOR_BLUE}Backend:${CHIEF_NO_COLOR}      ${det:-unknown}"
  kind="$(__chief_secrets_keychain_kind)"
  # No `case` inside $(...): Bash 3.2 (macOS /bin/bash, used by CI's syntax check) can't parse it.
  local kc_label="none available (file store is the fallback)"
  if [[ "$kind" == "macos" ]]; then
    kc_label="macOS Keychain"
  elif [[ "$kind" == "linux" ]]; then
    kc_label="Linux keyring (secret-tool)"
  fi
  echo -e "${CHIEF_COLOR_BLUE}Keychain:${CHIEF_NO_COLOR}     ${kc_label}"
  where="$(__chief_secrets_store_where "$secrets_file")"
  local source_msg
  if [[ "$det" == "ansible" && -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
    source_msg="ANSIBLE_VAULT_PASSWORD_FILE ($ANSIBLE_VAULT_PASSWORD_FILE)"
  elif [[ "$det" == "gpg" && -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" && -f "${CHIEF_SECRETS_PASSWORD_FILE}" ]]; then
    source_msg="CHIEF_SECRETS_PASSWORD_FILE ($CHIEF_SECRETS_PASSWORD_FILE)"
  elif [[ "$where" == "keychain" ]]; then
    source_msg="saved password (keychain)"
  elif [[ "$where" == "file" ]]; then
    source_msg="saved password (file store, obfuscated)"
  else
    source_msg="prompt (save one with: chief.secrets_password-save)"
  fi
  echo -e "${CHIEF_COLOR_BLUE}Password from:${CHIEF_NO_COLOR} ${source_msg}"
  local loaded
  loaded="$(__chief_secrets_loaded_desc "$secrets_file")" || loaded="not loaded in this shell"
  echo -e "${CHIEF_COLOR_BLUE}This shell:${CHIEF_NO_COLOR}   ${loaded}"
}

########################################################################
# Load record: which secrets files this shell has loaded, and how
########################################################################
# Shown by chief.status, chief.secrets_password-status and the start-up/reload hint, so a
# load is visible even when it was silent (--quiet) or done by a start-up file.
# Per shell; kept across chief.reload (re-sourcing this plugin must not reset it).
# Entry: CHIEF_SECRETS_LOADED[<abs path>]="<time>|<backend>|<origin>|<password source>|<quiet>"
if ! declare -p CHIEF_SECRETS_LOADED >/dev/null 2>&1; then
  declare -gA CHIEF_SECRETS_LOADED=()
fi

# A path with $HOME shown as ~.
function __chief_secrets_tilde() {
  if [[ "$1" == "$HOME"/* ]]; then
    printf '~%s' "${1#"$HOME"}"
  else
    printf '%s' "$1"
  fi
}

# How the current load was started, from the call stack:
#   "manually"                         typed at the prompt
#   "at start-up (CHIEF_CFG_SECRETS_LOAD)"  Chief's own start-up load
#   "automatically from <file>"        a start-up file or script (e.g. ~/.bash_profile)
#   "by <function> (<file>)"           another (non-Chief) function, e.g. in a plugin
#   "by secrets_file-edit --load"
# Chief's own functions are skipped by name (with CHIEF_CFG_ALIAS they come from a temp file).
function __chief_secrets_load_origin() {
  local i fn src n=${#FUNCNAME[@]} alias_prefix=""
  [[ -n "${CHIEF_CFG_ALIAS:-}" ]] && alias_prefix="$(printf '%s' "$CHIEF_CFG_ALIAS" | tr '[:upper:]' '[:lower:]')."
  for ((i = 1; i < n; i++)); do
    fn="${FUNCNAME[$i]}"
    src="${BASH_SOURCE[$i]}"
    if [[ "$fn" == "__chief_secrets_autoload" ]]; then
      echo "at start-up (CHIEF_CFG_SECRETS_LOAD)"
      return
    fi
    if [[ "$fn" == *.secrets_file-edit ]]; then
      echo "by secrets_file-edit --load"
      return
    fi
    if [[ "$fn" == chief.* || "$fn" == __chief* || ( -n "$alias_prefix" && "$fn" == "$alias_prefix"* ) ]]; then
      continue
    fi
    if [[ "$fn" == "source" || "$fn" == "main" ]]; then
      if [[ -n "$src" ]]; then
        echo "automatically from $(__chief_secrets_tilde "$src")"
        return
      fi
      continue
    fi
    echo "by ${fn} ($(__chief_secrets_tilde "$src"))"
    return
  done
  echo "manually"
}

# Record a successful load. Usage: __chief_secrets_record_load <file> <backend> <password source>
function __chief_secrets_record_load() {
  local quiet="no"
  [[ "${__chief_secrets_quiet:-false}" == "true" ]] && quiet="yes"
  CHIEF_SECRETS_LOADED["$1"]="$(date '+%H:%M:%S')|$2|$(__chief_secrets_load_origin)|$3|$quiet"
}

# One-line description of how <file> was loaded in this shell; returns 1 if it wasn't.
function __chief_secrets_loaded_desc() {
  local entry="${CHIEF_SECRETS_LOADED[$1]:-}" t backend origin pw quiet desc
  [[ -z "$entry" ]] && return 1
  IFS='|' read -r t backend origin pw quiet <<<"$entry"
  # Short password source: "saved password (keychain)" -> "keychain", "(file)" -> "file store".
  case "$pw" in
    "saved password (keychain)") pw="keychain" ;;
    "saved password (file)") pw="file store" ;;
  esac
  desc="loaded ${origin} at ${t} · ${backend} · password: ${pw}"
  [[ "$quiet" == "yes" ]] && desc+=" · ${CHIEF_COLOR_YELLOW}silent (--quiet)${CHIEF_NO_COLOR}"
  printf '%s' "$desc"
}

# Print the load record for chief.status. Usage: __chief_secrets_loaded_report
function __chief_secrets_loaded_report() {
  local f n=${#CHIEF_SECRETS_LOADED[@]}
  if (( n == 0 )); then
    local hint=""
    if [[ -n "${CHIEF_SECRETS_FILE:-}" && -f "${CHIEF_SECRETS_FILE}" ]]; then
      hint=" (available: $(__chief_secrets_tilde "$CHIEF_SECRETS_FILE"); load with chief.secrets_file-load)"
    fi
    echo -e "${CHIEF_COLOR_MAGENTA}Secrets:${CHIEF_NO_COLOR} none loaded in this shell${hint}"
    return 0
  fi
  echo -e "${CHIEF_COLOR_MAGENTA}Secrets:${CHIEF_NO_COLOR} ${n} file(s) loaded in this shell"
  # Path and details on separate lines, so it stays readable on narrow screens.
  for f in "${!CHIEF_SECRETS_LOADED[@]}"; do
    echo -e "  $(__chief_secrets_tilde "$f")"
    echo -e "    $(__chief_secrets_loaded_desc "$f")"
  done
}

# Note for a file skipped because it has no saved password (saved-only loads never prompt).
function __chief_secrets_no_saved_note() {
  echo -e "${CHIEF_COLOR_YELLOW}Not loaded:${CHIEF_NO_COLOR} $(__chief_secrets_tilde "$1") has no saved password, and this load doesn't prompt. Load it with ${CHIEF_COLOR_CYAN}chief.secrets_file-load $(__chief_secrets_tilde "$1")${CHIEF_NO_COLOR}, or save its password once: ${CHIEF_COLOR_CYAN}chief.secrets_password-save $(__chief_secrets_tilde "$1")${CHIEF_NO_COLOR}" >&2
}

# Start-up load, called once by chief.sh after plugins load and before the banner.
#   Interactive shells:      CHIEF_CFG_SECRETS_LOAD = false (default) | true | saved
#     true   load every secrets file that exists, quietly: saved password, else prompt
#     saved  the same, but only files with a saved password; never prompts
#   Non-interactive shells:  CHIEF_CFG_SECRETS_LOAD_NONINTERACTIVE = false (default) | true
#     true   saved passwords only, never prompts, no output at all. Off by default, since it
#            puts the secrets in the environment of every script and tool that starts Chief.
# Hosts with no secrets file are skipped silently. Loads are recorded as "at start-up".
# With CHIEF_CFG_VERBOSE=true (interactive), it says which files it loaded, like the other
# start-up steps, and those loads aren't marked silent.
function __chief_secrets_autoload() {
  local mode
  if [[ $- == *i* ]]; then
    mode="${CHIEF_CFG_SECRETS_LOAD:-false}"
    case "$mode" in
      false|"") return 0 ;;
      true|saved) ;;
      *)
        echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} CHIEF_CFG_SECRETS_LOAD='${mode}' isn't one of false, true or saved, so secrets weren't loaded. Fix it with: ${CHIEF_COLOR_CYAN}chief.config-set secrets_load true${CHIEF_NO_COLOR}" >&2
        return 0 ;;
    esac
  else
    [[ "${CHIEF_CFG_SECRETS_LOAD_NONINTERACTIVE:-false}" == "true" ]] || return 0
    mode=quiet
  fi
  [[ -n "$(__chief_secrets_existing_layers)" ]] || return 0
  local __chief_secrets_saved_only=false
  [[ "$mode" != "true" ]] && __chief_secrets_saved_only=true
  if [[ "$mode" == "quiet" ]]; then
    chief.secrets_file-load --quiet >/dev/null 2>&1 </dev/null
    return 0
  fi
  chief.secrets_file-load --quiet
  [[ "${CHIEF_CFG_VERBOSE:-false}" == "true" ]] && __chief_secrets_autoload_report
  return 0
}

# Verbose start-up: one line naming the secrets files loaded at start-up, by layer. Those
# loads were announced, so their record isn't marked silent (banner: "loaded", not "silent").
function __chief_secrets_autoload_report() {
  local line layer f entry done=()
  while IFS= read -r line; do
    layer="${line%%$'\t'*}"
    f="$(__chief_secrets_abs_path "${line#*$'\t'}")"
    entry="${CHIEF_SECRETS_LOADED[$f]:-}"
    [[ "$entry" == *"|at start-up (CHIEF_CFG_SECRETS_LOAD)|"* ]] || continue
    CHIEF_SECRETS_LOADED["$f"]="${entry%|*}|no"
    [[ "$layer" == "local" ]] && layer="this host"
    done+=("${layer} ($(__chief_secrets_tilde "$f"))")
  done < <(__chief_secrets_existing_layers)
  (( ${#done[@]} > 0 )) || return 0
  local IFS=';'
  echo -e "${CHIEF_COLOR_GREEN}Secrets loaded:${CHIEF_NO_COLOR} $(printf '%s' "${done[*]}" | sed 's/;/, /g')"
}

function chief.secrets_file-load() {
  __chief_secrets_resolve_default
  if [[ -z $CHIEF_SECRETS_FILE ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_user-secrets"
  fi

  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--shared|--personal|--local|<file>] [-q|--quiet]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Load (decrypt and source) an encrypted Bash secrets file into the current shell.
Backend is auto-detected from the file (Ansible Vault or GPG); you never specify it for load.

${CHIEF_COLOR_GREEN}Password (first match wins):${CHIEF_NO_COLOR}
1. Password file: ANSIBLE_VAULT_PASSWORD_FILE (Ansible Vault) or CHIEF_SECRETS_PASSWORD_FILE (GPG)
2. Saved password: macOS Keychain, Linux keyring, or obfuscated file
   (save it with chief.secrets_password-save; check with chief.secrets_password-status)
3. Prompt

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  (none)          Load every secrets file that exists, in this order (later ones win when
                  they set the same variable): shared (<shared folder>/.chief_shared-secrets),
                  personal (<shared folder>/users/\$CHIEF_CFG_USER/secrets), this host
                  (~/.chief_user-secrets). One failing doesn't stop the others.
  --shared, --personal, --local   Just that one.
  <file>          Just that file.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -q, --quiet     No success message (errors and warnings still show).
                  Handy in ~/.bash_profile: chief.secrets_file-load --quiet
                  Every load is still recorded: chief.status and chief.secrets_password-status
                  show what this shell loaded, how (manually, by a start-up file, or by Chief
                  at start-up), and whether it was silent.
  -?, --help      Show this help

${CHIEF_COLOR_GREEN}Load at start-up (instead of a line in ~/.bash_profile):${CHIEF_NO_COLOR}
  CHIEF_CFG_SECRETS_LOAD=true     interactive shells: saved password, else prompt
  CHIEF_CFG_SECRETS_LOAD=saved    interactive shells: only files with a saved password; never prompts
  CHIEF_CFG_SECRETS_LOAD_NONINTERACTIVE=true
                                  also scripts and tools: saved passwords only, silently.
                                  Off by default: it puts your secrets in every script's environment.
  Turn on with: chief.config-set secrets_load true   (or in shared settings, per host)
  With CHIEF_CFG_VERBOSE=true, start-up says which files it loaded.
"
  local arg secrets_file="" __chief_secrets_quiet=false layer=""
  for arg in "$@"; do
    case "$arg" in
      -\?|--help) echo -e "${USAGE}"; return 0 ;;
      -q|--quiet) __chief_secrets_quiet=true ;;
      --shared) layer=shared ;;
      --personal) layer=personal ;;
      --local) layer=local ;;
      *) [[ -z "$secrets_file" ]] && secrets_file="$arg" ;;
    esac
  done
  if [[ -z "$secrets_file" && -n "$layer" ]]; then
    secrets_file="$(__chief_secrets_pick_file existing "$layer")" || return 1
  fi
  # No file: load every layer that exists (shared, personal, this host), in that order. A failure
  # in one doesn't stop the others; the return code says whether all of them loaded.
  if [[ -z "$secrets_file" ]]; then
    local lines=() line rc=0 qflag=()
    $__chief_secrets_quiet && qflag=(--quiet)
    while IFS= read -r line; do lines+=("$line"); done < <(__chief_secrets_existing_layers)
    if (( ${#lines[@]} == 0 )); then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} No secrets file found (shared, personal or this host). Create one with chief.secrets_file-edit."
      return 1
    fi
    local one
    for line in "${lines[@]}"; do
      chief.secrets_file-load "${line#*$'\t'}" "${qflag[@]}"
      one=$?
      (( one == 0 )) && continue
      rc=1
      # 3: skipped for having no saved password; that note already says what to do.
      (( one == 3 )) || echo -e "${CHIEF_COLOR_YELLOW}Skipped the ${line%%$'\t'*} secrets${CHIEF_NO_COLOR} ($(__chief_secrets_tilde "${line#*$'\t'}")); the others still load." >&2
    done
    return $rc
  fi
  if [[ "$secrets_file" != /* ]]; then
    secrets_file="$(realpath "$secrets_file" 2>/dev/null || echo "$(pwd)/$secrets_file")"
  fi

  if [[ ! -f "$secrets_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Secrets file does not exist: $secrets_file"
    return 1
  fi

  __chief_secrets_warn_legacy_file "$(basename "$secrets_file")"

  local det
  det="$(__chief_secrets_detect_backend "$secrets_file")"
  if [[ -z "$det" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Not a recognized encrypted file (expected Ansible Vault or GPG): $secrets_file"
    return 1
  fi

  if [[ "$det" == "ansible" ]]; then
    if ! command -v ansible-vault >/dev/null 2>&1; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault required. Install ansible-core."
      return 1
    fi
    # Decrypt first (keeping stderr) so a decrypt failure is not confused with a syntax error in the content.
    local adec aerrf spw pw_src="prompt"
    spw="$(__chief_secrets_saved_password_for "$secrets_file" ansible)"
    if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
      pw_src="ANSIBLE_VAULT_PASSWORD_FILE"
    elif [[ -n "$spw" ]]; then
      pw_src="saved password ($(__chief_secrets_store_where "$(__chief_secrets_abs_path "$secrets_file")"))"
    fi
    if [[ "$pw_src" == "prompt" && "${__chief_secrets_saved_only:-false}" == "true" ]]; then
      __chief_secrets_no_saved_note "$secrets_file"
      return 3
    fi
    aerrf="$(mktemp)"
    adec="$(__chief_secrets_ansible_vault "$spw" view "$secrets_file" 2>"$aerrf")" || {
      __chief_secrets_ansible_report "$aerrf" decrypt
      [[ -n "$spw" ]] && __chief_secrets_saved_password_hint "$secrets_file"
      unset spw
      rm -f "$aerrf"
      return 1
    }
    unset spw
    rm -f "$aerrf"
    if source <(printf '%s\n' "$adec"); then
      __chief_secrets_record_load "$secrets_file" ansible-vault "$pw_src"
      __chief_secrets_say "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file loaded (ansible-vault)."
    else
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Sourcing decrypted content failed (syntax error). Check with: ansible-vault view $secrets_file | bash -n"
      return 1
    fi
  else
    __chief_secrets_require_gpg || return 1
    local dec gpg_pass errf from_saved=false pw_src="prompt"
    errf="$(mktemp)"
    if [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
      pw_src="CHIEF_SECRETS_PASSWORD_FILE"
      dec="$(gpg --batch --passphrase-file "$CHIEF_SECRETS_PASSWORD_FILE" --decrypt "$secrets_file" 2>"$errf")" || {
        __chief_secrets_gpg_report "$errf" decrypt
        rm -f "$errf"
        return 1
      }
    else
      gpg_pass="$(__chief_secrets_saved_password_for "$secrets_file" gpg)"
      if [[ -n "$gpg_pass" ]]; then
        from_saved=true
        pw_src="saved password ($(__chief_secrets_store_where "$(__chief_secrets_abs_path "$secrets_file")"))"
      elif [[ "${__chief_secrets_saved_only:-false}" == "true" ]]; then
        rm -f "$errf"
        __chief_secrets_no_saved_note "$secrets_file"
        return 3
      else
        echo -e "${CHIEF_COLOR_CYAN}GPG password:${CHIEF_NO_COLOR}" >&2
        read -rs gpg_pass </dev/tty 2>/dev/null || read -rs gpg_pass
        echo >&2
      fi
      dec="$(gpg --batch --passphrase-fd 0 --decrypt "$secrets_file" 2>"$errf" <<< "$gpg_pass")" || {
        unset gpg_pass
        __chief_secrets_gpg_report "$errf" decrypt
        $from_saved && __chief_secrets_saved_password_hint "$secrets_file"
        rm -f "$errf"
        return 1
      }
      unset gpg_pass
    fi
    rm -f "$errf"
    if source <(printf '%s' "$dec"); then
      __chief_secrets_record_load "$secrets_file" gpg "$pw_src"
      __chief_secrets_say "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file loaded (gpg)."
    else
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Sourcing decrypted content failed (syntax error)."
      return 1
    fi
  fi
}

# Deprecation wrappers (Option A): once per session warn then call secrets_*
function chief.vault_file-edit() {
  if [[ -z "${CHIEF_SECRETS_WARNED_VAULT_EDIT:-}" ]]; then
    export CHIEF_SECRETS_WARNED_VAULT_EDIT=1
    echo -e "${CHIEF_COLOR_YELLOW}Deprecation:${CHIEF_NO_COLOR} chief.vault_file-edit is deprecated, use chief.secrets_file-edit" >&2
  fi
  chief.secrets_file-edit "$@"
}

function chief.vault_file-load() {
  if [[ -z "${CHIEF_SECRETS_WARNED_VAULT_LOAD:-}" ]]; then
    export CHIEF_SECRETS_WARNED_VAULT_LOAD=1
    echo -e "${CHIEF_COLOR_YELLOW}Deprecation:${CHIEF_NO_COLOR} chief.vault_file-load is deprecated, use chief.secrets_file-load" >&2
  fi
  chief.secrets_file-load "$@"
}
