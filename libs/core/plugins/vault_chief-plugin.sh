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

# Chief Plugin File: etc_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0.1
# Functions and aliases that are Vault (HashiCorp vault or ansible-vault) related.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

function chief.vault_file-edit() {
  # Check if CHIEF_SECRETS_FILE is set, if not set it to default.
  if [[ -z $CHIEF_SECRETS_FILE ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_user-vault"
  fi

  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [vault-file] [--load]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit/create a Bash shell vault file using ansible-vault encryption.

${CHIEF_COLOR_GREEN}Requirements:${CHIEF_NO_COLOR}
- ansible-vault binary (ansible-core 2.9+)
- Valid vault password

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  [vault-file]  Optional vault file path (default: \$CHIEF_SECRETS_FILE)
  --load        Automatically load vault into environment after editing

${CHIEF_COLOR_MAGENTA}Security Notes:${CHIEF_NO_COLOR}
- On single-user systems: Set ANSIBLE_VAULT_PASSWORD_FILE for convenience
- On shared systems: Enter password manually (more secure)
- Store CHIEF_SECRETS_FILE path in ~/.bash_profile (not shared plugins)

${CHIEF_COLOR_BLUE}Default Vault File Name:${CHIEF_NO_COLOR}
- ${CHIEF_COLOR_GREEN}Personal vault${CHIEF_NO_COLOR} (non-remote): .chief_user-vault 
- ${CHIEF_COLOR_YELLOW}Shared vault${CHIEF_NO_COLOR} (remote repos): .chief_shared-vault

${CHIEF_COLOR_MAGENTA}File Creation:${CHIEF_NO_COLOR}
- Personal vaults are created in \$HOME/ if they don't exist
- Shared vaults are created in the plugins repository root if they don't exist

${CHIEF_COLOR_RED}⚠️ TEAM COLLABORATION WARNING:${CHIEF_NO_COLOR}
- .chief_shared-vault in team repos is ${CHIEF_COLOR_RED}SHARED BY ALL TEAM MEMBERS${CHIEF_NO_COLOR}
- Use shared vault only for team secrets (service accounts, team API keys)
- Create personal vault for private secrets: ${CHIEF_COLOR_CYAN}$FUNCNAME ~/.my-personal-vault${CHIEF_NO_COLOR}

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                           # Edit default vault file (no auto-load)
  $FUNCNAME ~/.my-secrets             # Edit specific file (no auto-load)
  $FUNCNAME --load                    # Edit and auto-load default vault
  $FUNCNAME ~/.my-secrets --load      # Edit specific file and auto-load

${CHIEF_COLOR_GREEN}Current default:${CHIEF_NO_COLOR} $CHIEF_SECRETS_FILE
${CHIEF_COLOR_BLUE}Configuration:${CHIEF_NO_COLOR} $(
  if [[ "${CHIEF_CFG_PLUGINS_TYPE}" == "remote" ]]; then
    echo "Remote repository (.chief_shared-vault)"
  else
    echo "Local setup (\$HOME/.chief_user-vault)"
  fi
)
"
  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  # Check if ansible-vault is installed and get version info
  if ! command -v ansible-vault >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  macOS: brew install ansible"
    echo "  Linux: pip3 install ansible-core"
    echo "  Or: Use your package manager (apt, yum, etc.)"
    return 1
  fi

  # Check ansible-vault version (warn if too old)
  local ansible_version
  ansible_version=$(ansible-vault --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  if [[ -n $ansible_version ]] && command -v bc >/dev/null 2>&1; then
    if [[ $(echo "$ansible_version < 2.9" | bc 2>/dev/null) == "1" ]] 2>/dev/null; then
      echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} ansible-vault $ansible_version detected. Recommend 2.9+ for best compatibility."
    fi
  fi

  local no_load=true vault_file  # Default: don't auto-load (avoids double password prompt)
  # Parse arguments more robustly
  case "$1" in
    "--load")
      no_load=false
      vault_file="$CHIEF_SECRETS_FILE"
      ;;
    "")
      vault_file="$CHIEF_SECRETS_FILE"
      ;;
    *)
      vault_file="$1"
      [[ "$2" == "--load" ]] && no_load=false
      ;;
  esac

  # Resolve relative paths to absolute paths to avoid issues when not in home directory
  if [[ "$vault_file" != /* ]]; then
    vault_file="$(realpath "$vault_file" 2>/dev/null || echo "$(pwd)/$vault_file")"
  fi

  # Create the file if it doesn't exist
  if [[ ! -f "$vault_file" ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Creating new vault file:${CHIEF_NO_COLOR} $vault_file"
    
    # Create the directory if it doesn't exist
    if ! mkdir -p "$(dirname "$vault_file")"; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to create directory for vault file: $vault_file"
      return 1
    fi
    
    # Use preferred editor or fallback to vi
    local editor="${EDITOR:-vi}"
    echo -e "${CHIEF_COLOR_YELLOW}Opening editor:${CHIEF_NO_COLOR} $editor"
    $editor "$vault_file"
    
    # Check if the file was created successfully
    if [[ ! -f "$vault_file" ]] || [[ ! -s "$vault_file" ]]; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Vault file was not created or is empty: $vault_file"
      echo "Please ensure you save the file in your editor."
      return 1
    fi
    
    # Source the file before encrypting (if not --no-load)
    if ! $no_load; then
      echo -e "${CHIEF_COLOR_BLUE}Loading vault file to memory...${CHIEF_NO_COLOR}"
      if ! source "$vault_file"; then
        echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Failed to source vault file. Check syntax before encryption."
      fi
    fi
    
    # Encrypt the file
    echo -e "${CHIEF_COLOR_GREEN}Encrypting vault file...${CHIEF_NO_COLOR}"
    if ! ansible-vault encrypt "$vault_file"; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to encrypt vault file: $vault_file"
      return 1
    fi
    
    if $no_load; then
      echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Vault file created and encrypted (not loaded)."
      # Show simplified command for default vault file, full path for custom files
      if [[ "$vault_file" == "$CHIEF_SECRETS_FILE" ]]; then
        echo -e "${CHIEF_COLOR_BLUE}Load with:${CHIEF_NO_COLOR} chief.vault_file-load"
      else
        echo -e "${CHIEF_COLOR_BLUE}Load with:${CHIEF_NO_COLOR} chief.vault_file-load $vault_file"
      fi
    else
      echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Vault file created, encrypted, and loaded to memory."
      echo -e "${CHIEF_COLOR_BLUE}Tip:${CHIEF_NO_COLOR} Use --load flag to automatically load after editing."
    fi
  else
    # Check if file is ansible-vault encrypted
    if grep -q '^\$ANSIBLE_VAULT;' "$vault_file"; then
      echo -e "${CHIEF_COLOR_BLUE}Editing encrypted vault file...${CHIEF_NO_COLOR}"
      if ! ansible-vault edit "$vault_file"; then
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to edit vault file: $vault_file"
        echo "Check your password and file integrity."
        return 1
      fi
      
      # Optionally reload after editing
      if $no_load; then
        echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Vault file edited (changes not loaded to memory)."
        # Show simplified command for default vault file, full path for custom files
        if [[ "$vault_file" == "$CHIEF_SECRETS_FILE" ]]; then
          echo -e "${CHIEF_COLOR_BLUE}Load with:${CHIEF_NO_COLOR} chief.vault_file-load"
        else
          echo -e "${CHIEF_COLOR_BLUE}Load with:${CHIEF_NO_COLOR} chief.vault_file-load $vault_file"
        fi
      else
        echo -e "${CHIEF_COLOR_BLUE}Loading updated vault file...${CHIEF_NO_COLOR}"
        chief.vault_file-load "$vault_file"
      fi
    else
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} File is not an encrypted ansible-vault file: $vault_file"
      echo -e "${CHIEF_COLOR_YELLOW}Solutions:${CHIEF_NO_COLOR}"
      echo "  1. Create new vault: chief.vault_file-edit"
      echo "  2. Encrypt existing: ansible-vault encrypt $vault_file"
      echo "  3. Check file format: head -1 $vault_file"
      return 1
    fi
  fi
}

function chief.vault_file-load() {
  if [[ -z $CHIEF_SECRETS_FILE ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_user-vault"
  fi

  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [vault-file]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Load (source) an encrypted Bash shell vault file into memory using ansible-vault.

${CHIEF_COLOR_GREEN}Requirements:${CHIEF_NO_COLOR}
- ansible-vault binary (ansible-core 2.9+)
- Valid vault password
- Existing encrypted vault file

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  [vault-file]  Optional vault file path (default: \$CHIEF_SECRETS_FILE)

${CHIEF_COLOR_MAGENTA}Security Notes:${CHIEF_NO_COLOR}
- Variables are loaded into current shell session
- Use ANSIBLE_VAULT_PASSWORD_FILE for convenience (single-user systems only)
- Store CHIEF_SECRETS_FILE path in ~/.bash_profile (not shared plugins)

${CHIEF_COLOR_BLUE}Default Vault File Name:${CHIEF_NO_COLOR}
- ${CHIEF_COLOR_GREEN}Personal vault${CHIEF_NO_COLOR} (non-remote): .chief_user-vault 
- ${CHIEF_COLOR_YELLOW}Shared vault${CHIEF_NO_COLOR} (remote repos): .chief_shared-vault

${CHIEF_COLOR_MAGENTA}File Creation:${CHIEF_NO_COLOR}
- Personal vaults are created in \$HOME/ if they don't exist
- Shared vaults are created in the plugins repository root if they don't exist

${CHIEF_COLOR_RED}⚠️ TEAM COLLABORATION WARNING:${CHIEF_NO_COLOR}
- .chief_shared-vault in team repos is ${CHIEF_COLOR_RED}SHARED BY ALL TEAM MEMBERS${CHIEF_NO_COLOR}
- Load personal vault separately: ${CHIEF_COLOR_CYAN}$FUNCNAME ~/.my-personal-vault${CHIEF_NO_COLOR}

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Load default vault file
  $FUNCNAME ~/.my-secrets      # Load specific vault file

${CHIEF_COLOR_GREEN}Current default:${CHIEF_NO_COLOR} $CHIEF_SECRETS_FILE
${CHIEF_COLOR_BLUE}Configuration:${CHIEF_NO_COLOR} $(
  if [[ "${CHIEF_CFG_PLUGINS_TYPE}" == "remote" ]]; then
    echo "Remote repository (.chief_shared-vault)"
  else
    echo "Local setup (\$HOME/.chief_user-vault)"
  fi
)

${CHIEF_COLOR_BLUE}Troubleshooting:${CHIEF_NO_COLOR}
- macOS with older ansible: Use ansible-vault 2.18.0+ for best compatibility
- Permission errors: Check file ownership and vault password
"
  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  # Check if ansible-vault is installed
  if ! command -v ansible-vault >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ansible-vault is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  macOS: brew install ansible"
    echo "  Linux: pip3 install ansible-core"
    echo "  Or: Use your package manager (apt, yum, etc.)"
    return 1
  fi

  # Parse arguments
  local vault_file
  if [[ -z $1 ]]; then
    vault_file="$CHIEF_SECRETS_FILE"
  else
    vault_file="$1"
  fi

  # Resolve relative paths to absolute paths to avoid issues when not in home directory
  if [[ "$vault_file" != /* ]]; then
    vault_file="$(realpath "$vault_file" 2>/dev/null || echo "$(pwd)/$vault_file")"
  fi

  # Validate vault file exists
  if [[ ! -f "$vault_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Vault file does not exist: $vault_file"
    echo -e "${CHIEF_COLOR_YELLOW}Solutions:${CHIEF_NO_COLOR}"
    echo "  1. Create vault: chief.vault_file-edit"
    echo "  2. Check path: ls -la $(dirname "$vault_file")"
    echo "  3. Set CHIEF_SECRETS_FILE in ~/.bash_profile"
    return 1
  fi

  # Check if file is ansible-vault encrypted
  if grep -q '^\$ANSIBLE_VAULT;' "$vault_file"; then
    echo -e "${CHIEF_COLOR_BLUE}Loading encrypted vault file:${CHIEF_NO_COLOR} $vault_file"
    
    # Load the vault file and check for errors
    if source <(ansible-vault view "$vault_file" 2>/dev/null); then
      echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Vault file loaded to memory."
      echo -e "${CHIEF_COLOR_BLUE}Tip:${CHIEF_NO_COLOR} Vault env vars, functions, and aliases are now available in current shell session."
    else
      local exit_code=$?
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to load vault file: $vault_file"
      echo -e "${CHIEF_COLOR_YELLOW}Possible causes:${CHIEF_NO_COLOR}"
      echo "  1. Incorrect vault password"
      echo "  2. Corrupted vault file"
      echo "  3. Syntax errors in decrypted content"
      echo "  4. Ansible version compatibility issue"
      echo -e "${CHIEF_COLOR_BLUE}Debug:${CHIEF_NO_COLOR} Try: ansible-vault view $vault_file | bash -n"
      return $exit_code
    fi
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} File is not an encrypted ansible-vault file: $vault_file"
    echo -e "${CHIEF_COLOR_YELLOW}Solutions:${CHIEF_NO_COLOR}"
    echo "  1. Check file format: head -1 $vault_file"
    echo "  2. Encrypt file: ansible-vault encrypt $vault_file"
    echo "  3. Create new vault: chief.vault_file-edit"
    return 1
  fi
}