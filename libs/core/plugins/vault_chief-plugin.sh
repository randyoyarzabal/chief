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

This function requires the ansible-vault binary to be installed.

Optional arguments: 
[vault-file] to specify a non-default vault file. If the file and path does not exist, it will be created.
[--no-load] to prevent loading the vault file after editing.

Edit/create a Bash shell file vault file using ansible-vault.
This will create a new vault file if it doesn't exist, or edit an existing one.

On a single-user system, it is recommended to set ANSIBLE_VAULT_PASSWORD_FILE for convenience so that you don't have to enter the password every time you edit the vault file; this is not recommended on a shared system.

If no vault-file is passed, it will use '$CHIEF_SECRETS_FILE' or set CHIEF_SECRETS_FILE to your preferred vault file path.
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
      # Check if the file was created successfully.
      if [ ! -f "$vault_file" ]; then
        echo "Failed to create vault file (or was not saved): $vault_file"
        return 1
      fi
      echo "Loading (Bash source) vault file: $vault_file..."
      if $no_load; then
        echo "Vault file: $vault_file created, but not loaded to memory. Use 'chief.vault_file-load' to load it."
      else
        echo "If you don't want to load the vault file automatically, use 'chief.vault_file-edit --no-load'."
        source $vault_file
      fi
      ansible-vault encrypt $vault_file
  else
    # Check if file is ansible-vault encrypted without decrypting it.
    # This is done by checking if the first line starts with 'ANSIBLE_VAULT;'.
    if grep -q '^$ANSIBLE_VAULT;' "$vault_file"; then
      ansible-vault edit $vault_file
      # If the --no-load option is passed, we will not load the vault file after editing.
      if $no_load; then
        echo "Vault file: $vault_file edited, but changes were not loaded to memory. Use 'chief.vault_file-load' to load it."
      else
        echo "If you don't want to load the vault file automatically, use 'chief.vault_file-edit --no-load'."
        chief.vault_file-load $vault_file
      fi
    else    
      echo "Vault file: $vault_file is not encrypted or is not a valid ansible-vault file."
      echo "Please check the file or create a new one using 'chief.vault_file-edit'."
      echo "You can also manually encrypt the file using 'ansible-vault encrypt $vault_file'."
      return 1
    fi
  fi
}

function chief.vault_file-load() {
  if [[ -z $CHIEF_SECRETS_FILE ]]; then
    CHIEF_SECRETS_FILE="$HOME/.chief_secret-vault"
  fi

  local USAGE="Usage: $FUNCNAME [vault-file]

This function requires the ansible-vault binary to be installed.

Load (source) a Bash shell file vault file using ansible-vault.
This will create a new vault file if it doesn't exist, or edit an existing one.

On a single-user system, it is recommended to set ANSIBLE_VAULT_PASSWORD_FILE for convenience so that you don't have to enter the password every time you edit the vault file; this is not recommended on a shared system.

If no vault-file is passed, it will use '$CHIEF_SECRETS_FILE' or set CHIEF_SECRETS_FILE to your preferred vault file path.

KNOWN ISSUE: If you are using a Mac and have an older version of ansible-vault, you may need to decrypt the file before loading it, then re-encrypt it. This is due to a bug in older versions of ansible-vault that prevents sourcing the file directly. If you are using ansible-vault 2.18.0 or later, this should not be an issue.
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

  if [[ ! -f $vault_file ]]; then
    echo "Vault file: $vault_file does not exist. Please create it first using 'chief.vault_file-edit'."
    return 1
  else
    # Load the vault file into memory.
    # This will source the file and make the variables available in the current shell.
    # If the vault file is encrypted, it will prompt for the password.
    
    # Check if file is ansible-vault encrypted without decrypting it.
    # This is done by checking if the first line starts with 'ANSIBLE_VAULT;'.
    if grep -q '^$ANSIBLE_VAULT;' "$vault_file"; then
      # Load the vault file and check for errors.
      if ! source <(ansible-vault view "$vault_file"); then
        echo "Failed to decrypt the vault file: $vault_file. Please check your password or the file's integrity."
        echo "Be sure you are using the latest version of ansible-vault."
        return 1
      else
        # If the source command was successful, we can assume the file was loaded correctly.
        echo "Vault file: $vault_file loaded to memory."
      fi
    else
      echo "Vault file: $vault_file is not encrypted or is not a valid ansible-vault file."
      echo "Please check the file or create a new one using 'chief.vault_file-edit'."
      echo "You can also manually encrypt the file using 'ansible-vault encrypt $vault_file'."
      return 1
    fi
  fi
}