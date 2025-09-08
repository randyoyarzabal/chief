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

# Chief Plugin File: python_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0
# Functions and aliases related to SSH.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

function chief.ssh_rm_host() {
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

function chief.ssh_get_publickey() {
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

function chief.ssh_create_keypair() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <user_email> <key_name> [bits]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Create an OpenSSH private/public key pair with specified bit length.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  user_email   Email address for the key comment
  key_name     Base name for key files (without extension)
  bits         Optional key length in bits (default: 2048)

${CHIEF_COLOR_GREEN}Output Files:${CHIEF_NO_COLOR}
- <key_name>.private  # Private key file
- <key_name>.public   # Public key file

${CHIEF_COLOR_MAGENTA}Security:${CHIEF_NO_COLOR}
- RSA key generation with SSH-compatible format
- Private key protected with passphrase (recommended)
- 2048 bits minimum, 4096 bits recommended for high security

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME user@example.com my_key        # 2048-bit key
  $FUNCNAME user@example.com my_key 4096   # 4096-bit key
"

  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  local key_bits
  if [[ ! -z $3 ]]; then
    key_bits=$3
  else
    key_bits=2048
  fi

  local KEY_COMMENT=$1
  #local KEY_NAME="${KEY_COMMENT%%@*}_open-ssh"
  local KEY_NAME="$2"

  ssh-keygen -b ${key_bits} -t rsa -C ${KEY_COMMENT} -f ${KEY_NAME}
  mv ${KEY_NAME} ${KEY_NAME}.private
  mv ${KEY_NAME}.pub ${KEY_NAME}.public
}
