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

function chief.secrets_file-edit() {
  __chief_secrets_resolve_default
  if [[ -z $CHIEF_SECRETS_FILE ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_user-secrets"
  fi

  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [secrets-file] [--load] [--backend=gpg|ansible]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit/create a Bash shell secrets file (env vars, functions, etc.) encrypted with Ansible Vault or GPG.
Content is decrypted → edited → re-encrypted. Load means decrypt → source into current shell.

${CHIEF_COLOR_GREEN}Backends:${CHIEF_NO_COLOR}
- ansible-vault (ansible-core 2.9+), gpg (symmetric AES256). Backend chosen when creating; auto-detected when editing.

${CHIEF_COLOR_GREEN}Password (optional file):${CHIEF_NO_COLOR}
- Ansible Vault: ANSIBLE_VAULT_PASSWORD_FILE or prompt
- GPG:           CHIEF_SECRETS_PASSWORD_FILE or prompt

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  [secrets-file]  Optional path (default: \$CHIEF_SECRETS_FILE)
  --load          Load (source) secrets into environment after editing
  --backend=...   For new files only: gpg or ansible (default: gpg if available, else ansible).
                  Once a file exists, backend is auto-detected; do not pass --backend for edit/load.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -?, --help      Show this help

${CHIEF_COLOR_MAGENTA}Default file names:${CHIEF_NO_COLOR}
- Personal: .chief_user-secrets (or legacy .chief_user-vault)
- Shared:   .chief_shared-secrets (or legacy .chief_shared-vault)

${CHIEF_COLOR_RED}⚠ TEAM:${CHIEF_NO_COLOR} .chief_shared-secrets in team repos is SHARED. Use personal file for private secrets.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME
  $FUNCNAME --load
  $FUNCNAME ~/.my-secrets --backend=gpg
"
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  local no_load=true secrets_file="" backend=""
  local arg
  for arg in "$@"; do
    case "$arg" in
      --load) no_load=false ;;
      --backend=*) backend="${arg#--backend=}" ;;
      -?|--help) ;;
      *) [[ -z "$secrets_file" ]] && secrets_file="$arg" ;;
    esac
  done

  if [[ -z "$secrets_file" ]]; then
    secrets_file="$CHIEF_SECRETS_FILE"
  fi

  # Resolve path
  if [[ "$secrets_file" != /* ]]; then
    secrets_file="$(realpath "$secrets_file" 2>/dev/null || echo "$(pwd)/$secrets_file")"
  fi

  # Deprecation: legacy file name
  __chief_secrets_warn_legacy_file "$(basename "$secrets_file")"

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
    local editor="${EDITOR:-vi}"
    echo -e "${CHIEF_COLOR_GREEN}Creating new secrets file:${CHIEF_NO_COLOR} $secrets_file (backend: $backend)"
    $editor "$secrets_file"
    if [[ ! -f "$secrets_file" ]] || [[ ! -s "$secrets_file" ]]; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} File not created or empty. Save in editor and retry."
      return 1
    fi
    if ! $no_load; then
      source "$secrets_file" || true
    fi
    if [[ "$backend" == "ansible" ]]; then
      ansible-vault encrypt "$secrets_file" || return 1
    else
      local tmpf
      tmpf="$(mktemp)"
      cat "$secrets_file" > "$tmpf"
      if [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
        gpg --batch --yes --armor --passphrase-file "$CHIEF_SECRETS_PASSWORD_FILE" --symmetric --cipher-algo AES256 -o "$secrets_file" "$tmpf" || return 1
      else
        gpg --yes --armor --symmetric --cipher-algo AES256 -o "$secrets_file" "$tmpf" || return 1
      fi
      rm -f "$tmpf"
    fi
    echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file created and encrypted."
    if $no_load; then
      echo -e "${CHIEF_COLOR_BLUE}Load with:${CHIEF_NO_COLOR} chief.secrets_file-load ${secrets_file:+$secrets_file}"
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

  if [[ "$det" == "ansible" ]]; then
    if ! command -v ansible-vault >/dev/null 2>&1; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault required. Install ansible-core."
      return 1
    fi
    ansible-vault edit "$secrets_file" || return 1
  else
    local tmpf editor gpg_pass
    tmpf="$(mktemp)"
    editor="${EDITOR:-vi}"
    if [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
      gpg --batch --passphrase-file "$CHIEF_SECRETS_PASSWORD_FILE" --decrypt "$secrets_file" > "$tmpf" 2>/dev/null || {
        rm -f "$tmpf"
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GPG decrypt failed (wrong password or file)." >&2
        return 1
      }
    else
      echo -e "${CHIEF_COLOR_CYAN}GPG password:${CHIEF_NO_COLOR}" >&2
      read -rs gpg_pass </dev/tty 2>/dev/null || read -rs gpg_pass
      echo >&2
      gpg --batch --passphrase-fd 0 --decrypt "$secrets_file" > "$tmpf" 2>/dev/null <<< "$gpg_pass" || {
        unset gpg_pass
        rm -f "$tmpf"
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GPG decrypt failed (wrong password or file)." >&2
        return 1
      }
    fi
    "$editor" "$tmpf"
    if [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
      gpg --batch --yes --armor --passphrase-file "$CHIEF_SECRETS_PASSWORD_FILE" --symmetric --cipher-algo AES256 -o "$secrets_file" "$tmpf" 2>/dev/null || {
        rm -f "$tmpf"
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GPG encrypt failed." >&2
        return 1
      }
    else
      gpg --batch --yes --armor --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "$secrets_file" "$tmpf" 2>/dev/null <<< "$gpg_pass" || {
        unset gpg_pass
        rm -f "$tmpf"
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GPG encrypt failed." >&2
        return 1
      }
      unset gpg_pass
    fi
    rm -f "$tmpf"
  fi

  if $no_load; then
    echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file edited (not loaded). Load with: chief.secrets_file-load ${secrets_file:+$secrets_file}"
  else
    chief.secrets_file-load "$secrets_file"
  fi
}

function chief.secrets_file-load() {
  __chief_secrets_resolve_default
  if [[ -z $CHIEF_SECRETS_FILE ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_user-secrets"
  fi

  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [secrets-file]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Load (decrypt and source) an encrypted Bash secrets file into the current shell.
Backend is auto-detected from the file (Ansible Vault or GPG); you never specify it for load.

${CHIEF_COLOR_GREEN}Password (optional file):${CHIEF_NO_COLOR}
- Ansible Vault: ANSIBLE_VAULT_PASSWORD_FILE or prompt
- GPG:           CHIEF_SECRETS_PASSWORD_FILE or prompt

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  [secrets-file]  Optional path (default: \$CHIEF_SECRETS_FILE)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -?, --help      Show this help
"
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  local secrets_file="${1:-$CHIEF_SECRETS_FILE}"
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
    if source <(ansible-vault view "$secrets_file" 2>/dev/null); then
      echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file loaded (ansible-vault)."
    else
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to load (password or syntax). Try: ansible-vault view $secrets_file | bash -n"
      return 1
    fi
  else
    local dec gpg_pass
    if [[ -n "${CHIEF_SECRETS_PASSWORD_FILE:-}" ]] && [[ -f "$CHIEF_SECRETS_PASSWORD_FILE" ]]; then
      dec="$(gpg --batch --passphrase-file "$CHIEF_SECRETS_PASSWORD_FILE" --decrypt "$secrets_file" 2>/dev/null)" || {
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GPG decrypt failed. Check password or file."
        return 1
      }
    else
      echo -e "${CHIEF_COLOR_CYAN}GPG password:${CHIEF_NO_COLOR}" >&2
      read -rs gpg_pass </dev/tty 2>/dev/null || read -rs gpg_pass
      echo >&2
      dec="$(gpg --batch --passphrase-fd 0 --decrypt "$secrets_file" 2>/dev/null <<< "$gpg_pass")" || {
        unset gpg_pass
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GPG decrypt failed." >&2
        return 1
      }
      unset gpg_pass
    fi
    if source <(printf '%s' "$dec"); then
      echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Secrets file loaded (gpg)."
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
