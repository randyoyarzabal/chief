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

# Chief Plugin File: python_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0
# Functions and aliases related to SSH.

function chief.ssh_rm_host() {
  local USAGE="Usage: $FUNCNAME <line #>

Remove a host entry in known_hosts given a line # in a SSH host error message."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi
  perl -pi -e "s/\Q\$_// if (\$. == \"$1\");" ~/.ssh/known_hosts
}

function chief.ssh_get_publickey() {
  local USAGE="Usage: $FUNCNAME <private key file>

Extract a public key from an OpenSSH RSA private key file."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi
  ssh-keygen -y -f $1
}

function chief.ssh_create_keypair() {
  local USAGE="Usage: $FUNCNAME <user email> <key file> [# of bits]

Create an OpenSSH private/public key pair.
   Optionally pass # of bits, if not, the default is 2048 bits.
   Keys will be saved as: <key file>.private and <key file>.public files."

  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
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
