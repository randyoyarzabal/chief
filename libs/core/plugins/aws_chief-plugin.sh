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

# Chief Plugin File: aws_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0
# AWS related functions and aliases

# Note this library requires python3

AWS_CREDS_SCRIPT="$CHIEF_PATH/libs/plugins/python/aws_creds.py"

function aws.set_role() {
  local USAGE="Usage: $FUNCNAME <role> <region>

Set role as default role in AWS credentials file.
"
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_ACCESS_KEY_ID
  unset AWS_SESSION_TOKEN
  unset AWS_REGION
  unset AWS_DEFAULT_REGION

  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  $AWS_CREDS_SCRIPT -u "$1" -r "$2"
}

function aws.export_creds() {
  local USAGE="Usage: $FUNCNAME <role> <region>

Export role and rename AWS credentials file.
"
  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  local output=$(eval "$AWS_CREDS_SCRIPT -u $1 -r $2 -e")
  source <(echo "$output")

  echo "$1 credentials exported. Be sure to aws.set_role to revert back if needed."
  echo "$output" | grep '#' | sed 's/\# //'
}
