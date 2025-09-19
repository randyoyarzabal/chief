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

# Chief Plugin File: ssh_chief-plugin.sh
# Author: Randy E. Oyarzabal
# Functions and aliases related to SSH.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

function chief.ssh_rm-host() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <line_number>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Remove a host entry from ~/.ssh/known_hosts by line number.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  line_number  Line number from SSH host error message

${CHIEF_COLOR_GREEN}Use Case:${CHIEF_NO_COLOR}
When SSH reports host key conflict with message:
'WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!'
'Add correct host key in ~/.ssh/known_hosts to get rid of this message.'
'Offending RSA key in ~/.ssh/known_hosts:42'

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME 42     # Remove entry on line 42
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi
  
  if [[ ! "$1" =~ ^[0-9]+$ ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Line number must be a positive integer"
    return 1
  fi
  
  echo -e "${CHIEF_COLOR_BLUE}Removing line $1 from ~/.ssh/known_hosts...${CHIEF_NO_COLOR}"
  perl -pi -e "s/\Q\$_// if (\$. == \"$1\");" ~/.ssh/known_hosts
  echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} Host entry removed"
}

function chief.ssh_get-publickey() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <private_key_file>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Extract the public key from an OpenSSH private key file.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  private_key_file  Path to OpenSSH private key file

${CHIEF_COLOR_GREEN}Supported Key Types:${CHIEF_NO_COLOR}
- RSA, DSA, ECDSA, Ed25519
- OpenSSH format private keys

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME ~/.ssh/id_rsa
  $FUNCNAME /path/to/my_key
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi
  
  if [[ ! -f "$1" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Private key file not found: $1"
    return 1
  fi
  
  echo -e "${CHIEF_COLOR_BLUE}Extracting public key from:${CHIEF_NO_COLOR} $1"
  ssh-keygen -y -f "$1"
}

function chief.ssh_create-keypair() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [key_name] [key_type] [user_email]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Create an OpenSSH private/public key pair in ~/.ssh with proper permissions.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  key_name     Name for key files (default: id_ed25519 or id_rsa)
  key_type     Key type: ed25519 or rsa (default: ed25519)
  user_email   Email address for the key comment (optional)

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Creates keys in ~/.ssh directory with proper permissions
- Supports modern Ed25519 (recommended) and RSA algorithms
- Creates ~/.ssh directory (mode 700) if it doesn't exist
- Sets secure permissions: private key (600), public key (644)
- Standard SSH naming: id_<type> and id_<type>.pub

${CHIEF_COLOR_MAGENTA}Key Types:${CHIEF_NO_COLOR}
- ed25519: Modern, fast, secure (256-bit security) [RECOMMENDED]
- rsa: Traditional RSA keys (4096-bit for security)

${CHIEF_COLOR_BLUE}Default Location:${CHIEF_NO_COLOR}
All keys are created in ~/.ssh/ directory for standard SSH usage.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                           # Create ~/.ssh/id_ed25519 & id_ed25519.pub
  $FUNCNAME mykey                     # Create ~/.ssh/mykey_ed25519.private & mykey_ed25519.public
  $FUNCNAME mykey rsa                 # Create ~/.ssh/mykey_rsa.private & mykey_rsa.public
  $FUNCNAME github ed25519 user@example.com  # With email comment
  $FUNCNAME work rsa user@company.com # Create ~/.ssh/work_rsa.private & work_rsa.public

${CHIEF_COLOR_BLUE}Next Steps:${CHIEF_NO_COLOR}
- Add public key to authorized_keys: ssh-copy-id user@host
- Add to SSH agent: ssh-add ~/.ssh/keyname
- Configure in ~/.ssh/config for specific hosts
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  # Parse arguments
  local key_name="${1}"
  local key_type="${2:-ed25519}"
  local user_email="${3}"
  
  # Validate key type
  if [[ "$key_type" != "ed25519" && "$key_type" != "rsa" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unsupported key type: $key_type"
    echo -e "${CHIEF_COLOR_YELLOW}Supported types:${CHIEF_NO_COLOR} ed25519, rsa"
    return 1
  fi
  
  # Set default key name based on type
  local is_standard_name=false
  if [[ -z "$key_name" ]]; then
    key_name="id_${key_type}"
    is_standard_name=true
  elif [[ "$key_name" == "id_${key_type}" ]]; then
    is_standard_name=true
  fi
  
  # Ensure ~/.ssh directory exists with proper permissions
  if [[ ! -d "$HOME/.ssh" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Creating ~/.ssh directory...${CHIEF_NO_COLOR}"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    echo -e "${CHIEF_COLOR_GREEN}✓ Created ~/.ssh with permissions 700${CHIEF_NO_COLOR}"
  fi
  
  # Determine the actual key file names
  local private_key_name
  local public_key_name
  
  if [[ "$is_standard_name" == true ]]; then
    # Standard SSH naming: id_type and id_type.pub
    private_key_name="$key_name"
    public_key_name="$key_name.pub"
  else
    # Custom naming: name_type.private and name_type.public
    private_key_name="${key_name}_${key_type}.private"
    public_key_name="${key_name}_${key_type}.public"
  fi
  
  # Full paths for the keys
  local private_key_path="$HOME/.ssh/$private_key_name"
  local public_key_path="$HOME/.ssh/$public_key_name"
  
  # Check if key already exists
  if [[ -f "$private_key_path" || -f "$public_key_path" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Key files already exist in ~/.ssh/"
    echo -e "${CHIEF_COLOR_BLUE}Existing files:${CHIEF_NO_COLOR}"
    [[ -f "$private_key_path" ]] && echo "  - $private_key_name"
    [[ -f "$public_key_path" ]] && echo "  - $public_key_name"
    if ! chief.etc_ask_yes_or_no "Do you want to overwrite them?"; then
      return 1
    fi
  fi
  
  # Prepare ssh-keygen command
  local ssh_keygen_cmd="ssh-keygen -t $key_type"
  
  # Add key-specific options
  if [[ "$key_type" == "rsa" ]]; then
    ssh_keygen_cmd="$ssh_keygen_cmd -b 4096"
    echo -e "${CHIEF_COLOR_BLUE}Generating RSA 4096-bit key pair...${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_BLUE}Generating Ed25519 key pair...${CHIEF_NO_COLOR}"
  fi
  
  # Add comment if provided
  if [[ -n "$user_email" ]]; then
    ssh_keygen_cmd="$ssh_keygen_cmd -C '$user_email'"
  fi
  
  # Add filename (always generate with standard naming first)
  local temp_key_path="$HOME/.ssh/temp_${key_name}_${key_type}"
  ssh_keygen_cmd="$ssh_keygen_cmd -f '$temp_key_path'"
  
  echo -e "${CHIEF_COLOR_BLUE}Location:${CHIEF_NO_COLOR} ~/.ssh/"
  if [[ "$is_standard_name" == true ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Files:${CHIEF_NO_COLOR} $private_key_name, $public_key_name"
  else
    echo -e "${CHIEF_COLOR_BLUE}Files:${CHIEF_NO_COLOR} $private_key_name, $public_key_name"
  fi
  
  # Generate the key pair
  if eval "$ssh_keygen_cmd"; then
    # Move and rename files to final names
    mv "$temp_key_path" "$private_key_path"
    mv "$temp_key_path.pub" "$public_key_path"
    
    # Set proper permissions
    chmod 600 "$private_key_path"  # Private key: owner read/write only
    chmod 644 "$public_key_path"   # Public key: owner read/write, others read
    
    echo -e "${CHIEF_COLOR_GREEN}✓ SSH key pair created successfully!${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_BLUE}Private key:${CHIEF_NO_COLOR} $private_key_path (permissions: 600)"
    echo -e "${CHIEF_COLOR_BLUE}Public key:${CHIEF_NO_COLOR} $public_key_path (permissions: 644)"
    echo
    echo -e "${CHIEF_COLOR_YELLOW}Public key content:${CHIEF_NO_COLOR}"
    cat "$public_key_path"
    echo
    echo -e "${CHIEF_COLOR_BLUE}Next steps:${CHIEF_NO_COLOR}"
    if [[ "$is_standard_name" == true ]]; then
      echo "• Add to remote server: ssh-copy-id -i $private_key_path user@hostname"
      echo "• Add to SSH agent: ssh-add $private_key_path"
      echo "• Copy public key: pbcopy < $public_key_path  # macOS"
      echo "• Copy public key: xclip -sel clip < $public_key_path  # Linux"
    else
      echo "• Add to remote server: ssh-copy-id -i $private_key_path user@hostname"
      echo "• Add to SSH agent: ssh-add $private_key_path"
      echo "• Copy public key: pbcopy < $public_key_path  # macOS"
      echo "• Copy public key: xclip -sel clip < $public_key_path  # Linux"
      echo "• Add to SSH config: IdentityFile $private_key_path"
    fi
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to generate SSH key pair"
    # Clean up any partial files
    [[ -f "$temp_key_path" ]] && rm -f "$temp_key_path"
    [[ -f "$temp_key_path.pub" ]] && rm -f "$temp_key_path.pub"
    return 1
  fi
}
