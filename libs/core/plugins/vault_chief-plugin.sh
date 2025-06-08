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

function chief.vault_file-edit() {
  # Check if CHIEF_SECRETS_FILE is set, if not set it to default.
  if [[ -z $CHIEF_SECRETS_FILE ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_secret-vault"
  fi

  local USAGE="Usage: $FUNCNAME [vault-file] [--no-load]

Optional arguments: 
[vault-file] to specify a different vault file path.
[--no-load] to prevent loading the vault file after editing.

Edit a Bash-compliant vault file using ansible-vault.
This will create a new vault file if it doesn't exist, or edit an existing one.

On a single-user system, it is recommended to set ANSIBLE_VAULT_PASSWORD_FILE for convenience so that you don't have to enter the password every time you edit the vault file; this is not recommended on a shared system.

If no vault-file is passed, it will use \$CHIEF_SECRETS_FILE=$CHIEF_SECRETS_FILE or set this variable to your preferred vault file path.
"
  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  # Check if ansible-vault is installed.
  if ! type ansible-vault >/dev/null 2>&1; then
    echo "ansible-vault is required."
    return 1
  fi

  local no_load=false
  # Check if first or 2nd argument is not '--no-load'
  if [[ $1 == "--no-load" ]];then
    no_load=true  
    vault_file=$CHIEF_SECRETS_FILE
  elif [[ $2 == "--no-load" ]]; then
    no_load=true 
    vault_file=$1
  else
    if [[ -z $1 ]]; then
      vault_file=$CHIEF_SECRETS_FILE
    else
      vault_file=$1
    fi
  fi

  # Create the file if doesn't exist.
  if [ ! -f "$vault_file" ]; then
      echo "$vault_file does not exist. Creating the file and will encrypt it."
      # Create the directory if it doesn't exist and exit if it fails.
      if ! mkdir -p "$(dirname "$vault_file")"; then
        echo "Failed to create directory for vault file: $vault_file"
        return 1
      fi
      vi $vault_file
      echo "Loading (Bash source) vault file: $vault_file..."
      source $vault_file
      ansible-vault encrypt $vault_file
  else
    echo "Decrypt and edit $vault_file..."
    # Check if file is ansible-vault encrypted.
    if ! ansible-vault view "$vault_file" >/dev/null 2>&1; then
      echo "Vault file: $vault_file is not encrypted or is not a valid ansible-vault file."
      echo "Please check the file or create a new one using 'chief.vault_file-edit'."
      return 1
    else    
      ansible-vault edit $vault_file
      # If the --no-load option is passed, we will not load the vault file after editing.
      if $no_load; then
        echo "Vault file: $vault_file edited, but changes were not loaded to memory. Use 'chief.vault_file-load' to load it."
      else
        chief.vault_file-load $vault_file
      fi
    fi
  fi
}

function chief.vault_file-load() {
  if [[ -z $CHIEF_SECRETS_FILE ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_secret-vault"
  fi

  local USAGE="Usage: $FUNCNAME [vault-file]

Load a Bash-compliant vault file using ansible-vault.
This will create a new vault file if it doesn't exist, or edit an existing one.

On a single-user system, it is recommended to set ANSIBLE_VAULT_PASSWORD_FILE for convenience so that you don't have to enter the password every time you edit the vault file; this is not recommended on a shared system.

If no vault-file is passed, it will use \$CHIEF_SECRETS_FILE=$CHIEF_SECRETS_FILE or set this variable to your preferred vault file path.
"
  # Check if ansible-vault at least version 2.18.2 is installed.
  if ! type ansible-vault >/dev/null 2>&1; then
    echo "ansible-vault is required."
    return 1
  fi

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  if [[ -z $1 ]]; then
    vault_file=$CHIEF_SECRETS_FILE
  else
    vault_file=$1
  fi

  # Commenting out the source line for now, since it seems to be working fine on ansible-vault 2.18 and above.
  # Since the line: 'source <(ansible-vault view "$vault_file");' doesn't work on a Mac
  #  let's decrypt the file before loading, then re-encrypt.
  # if [[ $(uname) == "Darwin" ]]; then
  #   # on a Mac
  #   ansible-vault decrypt "$vault_file" > /dev/null
  #   source "$vault_file"
  #   ansible-vault encrypt "$vault_file" > /dev/null
  # else
  #   # on Linux
  #   source <(ansible-vault view "$vault_file"); 
  # fi
  if [[ ! -f $vault_file ]]; then
    echo "Vault file: $vault_file does not exist. Please create it first using 'chief.vault_file-edit'."
    return 1
  else
    echo "Loading vault file: $vault_file..."
    # Load the vault file into memory.
    # This will source the file and make the variables available in the current shell.
    # If the vault file is encrypted, it will prompt for the password.
    # Load the vault file and check for errors.
    if ! source <(ansible-vault view "$vault_file"); then
      echo "Failed to decrypt the vault file: $vault_file. Please check your password or the file's integrity."
      echo "Be sure you are using the latest version of ansible-vault."
      return 1
    else
      # If the source command was successful, we can assume the file was loaded correctly.
      echo "Vault file: $vault_file loaded to memory."
    fi
  fi
}