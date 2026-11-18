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

# Chief Plugin File: vault_chief-plugin.sh
# Author: Randy E. Oyarzabal
# HashiCorp Vault utilities: read/write KV secrets via the vault CLI.
# Requires: vault binary, VAULT_ADDR, and VAULT_TOKEN (or VAULT_TOKEN_FILE).

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

function __chief_vault_ensure_auth() {
  if [[ -z "${VAULT_ADDR:-}" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} VAULT_ADDR is not set." >&2
    return 1
  fi
  if [[ -n "${VAULT_TOKEN_FILE:-}" ]] && [[ -f "$VAULT_TOKEN_FILE" ]]; then
    export VAULT_TOKEN
    VAULT_TOKEN="$(cat "$VAULT_TOKEN_FILE")"
  fi
  if [[ -z "${VAULT_TOKEN:-}" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} VAULT_TOKEN (or VAULT_TOKEN_FILE) is not set." >&2
    return 1
  fi
  if ! command -v vault >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} vault CLI not found. Install HashiCorp Vault CLI." >&2
    return 1
  fi
  return 0
}

function chief.vault_read-secret() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <path> [key] [-n]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Read a secret from HashiCorp Vault KV engine.
- With key: returns only the raw value for that key (no JSON). Default: value + newline (clean prompt).
- Without key: returns full secret as JSON.

${CHIEF_COLOR_GREEN}Requirements:${CHIEF_NO_COLOR}
- vault CLI, VAULT_ADDR, VAULT_TOKEN (or VAULT_TOKEN_FILE)

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  path   Secret path (e.g. secrets/hello-world), not path/key
  key    Optional: field name inside that secret (e.g. message); when given, only that value is returned
  -n, --no-newline  For scripting: do not print trailing newline (use when capturing value)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME secret/data/myapp              # full JSON
  $FUNCNAME secret/data/myapp password     # value + newline (interactive)
  $FUNCNAME -n secrets/hello-world message # no newline (e.g. url=\$(...))
"
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi
  __chief_vault_ensure_auth || return 1
  local no_newline=false path="" key=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--no-newline) no_newline=true ;;
      -?|--help) ;;
      *)
        if [[ -z "$path" ]]; then
          path="$1"
        elif [[ -z "$key" ]]; then
          key="$1"
        fi
        ;;
    esac
    shift
  done
  if [[ -z "$path" ]]; then
    echo -e "${USAGE}" >&2
    return 1
  fi
  if [[ -n "$key" ]]; then
    local val
    val="$(vault kv get -field="$key" "$path" 2>/dev/null)" || return 1
    if $no_newline; then
      printf '%s' "$val"
    else
      printf '%s\n' "$val"
    fi
  else
    vault kv get -format=json "$path" 2>/dev/null || return 1
  fi
}

function chief.vault_write-secret() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <path> <key>=<value> [key2=value2 ...] [-format=json]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Write one or more key-value pairs to HashiCorp Vault KV path.

${CHIEF_COLOR_GREEN}Requirements:${CHIEF_NO_COLOR}
- vault CLI, VAULT_ADDR, VAULT_TOKEN (or VAULT_TOKEN_FILE)

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  path   KV path (e.g. secret/data/myapp)
  key=value  One or more key=value pairs
  -format=json  Optional: after writing, output the full secret as JSON

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME secret/data/myapp api_key=xxx
  $FUNCNAME secret/data/myapp user=admin password=secret -format=json
"
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi
  if [[ -z "$1" || -z "$2" ]]; then
    echo -e "${USAGE}" >&2
    return 1
  fi
  __chief_vault_ensure_auth || return 1
  local path="$1"
  shift
  local out_json=false
  local args=()
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == -format=json ]]; then
      out_json=true
    else
      args+=("$1")
    fi
    shift
  done
  vault kv put "$path" "${args[@]}" 2>/dev/null || return 1
  if $out_json; then
    vault kv get -format=json "$path" 2>/dev/null || return 1
  fi
}

function chief.vault_list-secrets() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <path> [-format=table|json|yaml]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
List at a path. If path is a secret, lists key names inside it. If path is a folder, lists secret names.
Requires jq to detect secret vs folder and to list keys within a secret.

${CHIEF_COLOR_GREEN}Requirements:${CHIEF_NO_COLOR}
- vault CLI, VAULT_ADDR, VAULT_TOKEN (or VAULT_TOKEN_FILE), jq

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  path   KV path (secret e.g. secret/myapp, or folder e.g. secret/)
  -format=table|json|yaml  table (default): key names or folder list; json/yaml: full data

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME secret/myapp           # keys inside secret (one per line)
  $FUNCNAME secret/myapp -format=json   # full secret as JSON
  $FUNCNAME secret/ -format=json   # folder list as JSON
"
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi
  if [[ -z "$1" ]]; then
    echo -e "${USAGE}" >&2
    return 1
  fi
  __chief_vault_ensure_auth || return 1
  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} jq is required for $FUNCNAME. Install jq:" >&2
    if [[ "${PLATFORM:-}" == "MacOS" ]]; then
      echo -e "  brew install jq" >&2
    else
      echo -e "  apt install jq / yum install jq / dnf install jq (or your package manager)" >&2
    fi
    return 1
  fi
  local path="$1"
  local format_arg=""
  local format_val="table"
  if [[ "$2" == -format=* ]]; then
    format_val="${2#-format=}"
    format_arg="-format=$format_val"
  fi

  local json
  json="$(vault kv get -format=json "$path" 2>/dev/null)"
  # Secret: .data.data is a non-null object (KV v2). Otherwise treat as folder.
  if [[ -n "$json" ]] && jq -e '.data.data != null and (.data.data | type == "object")' <<< "$json" >/dev/null 2>&1; then
    if [[ "$format_val" == "json" ]]; then
      echo "$json"
      return 0
    fi
    if [[ "$format_val" == "yaml" ]]; then
      vault kv get -format=yaml "$path" 2>/dev/null || return 1
      return 0
    fi
    echo -e "${CHIEF_COLOR_GREEN}Keys in secret:${CHIEF_NO_COLOR} $path" >&2
    jq -r '.data.data | keys[]' <<< "$json"
    return 0
  fi

  echo -e "${CHIEF_COLOR_GREEN}Folder (secret names at path):${CHIEF_NO_COLOR} $path" >&2
  vault kv list $format_arg "$path" 2>/dev/null || return 1
}
