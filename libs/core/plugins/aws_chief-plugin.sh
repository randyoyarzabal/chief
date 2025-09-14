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

# Chief Plugin File: aws_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0.1
# AWS related functions and aliases

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

# Note this library requires python3

AWS_CREDS_SCRIPT="$CHIEF_PATH/libs/plugins/python/aws_creds.py"

function chief.aws.set_role() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <role> <region>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Set AWS role and region as default in AWS credentials file.

${CHIEF_COLOR_GREEN}Requirements:${CHIEF_NO_COLOR}
- Python3 installed and in PATH
- AWS credentials properly configured

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  role         AWS role to set as default
  region       AWS region to set as default

${CHIEF_COLOR_MAGENTA}Environment:${CHIEF_NO_COLOR}
Clears existing AWS session variables:
- AWS_SECRET_ACCESS_KEY, AWS_ACCESS_KEY_ID
- AWS_SESSION_TOKEN, AWS_REGION, AWS_DEFAULT_REGION

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME admin us-east-1
  $FUNCNAME developer us-west-2
"

  # Check if Python3 is installed
  if ! command -v python3 &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Python3 is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  macOS: brew install python3"
    echo "  Linux: Use your package manager (apt, yum, etc.)"
    return 1
  fi
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

function chief.aws.export_creds() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <role> <region>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Export AWS credentials as environment variables and backup credentials file.

${CHIEF_COLOR_GREEN}Requirements:${CHIEF_NO_COLOR}
- Python3 installed and in PATH
- AWS credentials properly configured
- aws_creds.py script available

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  role         AWS role to export credentials for
  region       AWS region to set as default

${CHIEF_COLOR_MAGENTA}Environment Variables Set:${CHIEF_NO_COLOR}
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY  
- AWS_SESSION_TOKEN (if applicable)
- AWS_DEFAULT_REGION

${CHIEF_COLOR_RED}Important:${CHIEF_NO_COLOR}
This exports credentials to your current shell session.
Use chief.aws.set_role to revert back to file-based credentials.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME admin us-east-1      # Export admin role for us-east-1
  $FUNCNAME developer us-west-2  # Export developer role for us-west-2
"

  # Check if Python3 is installed
  if ! command -v python3 &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Python3 is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  macOS: brew install python3"
    echo "  Linux: Use your package manager (apt, yum, etc.)"
    return 1
  fi

  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_BLUE}Exporting AWS credentials for role:${CHIEF_NO_COLOR} $1"
  echo -e "${CHIEF_COLOR_BLUE}Region:${CHIEF_NO_COLOR} $2"
  
  local output=$(eval "$AWS_CREDS_SCRIPT -u $1 -r $2 -e")
  source <(echo "$output")

  echo -e "${CHIEF_COLOR_GREEN}Success:${CHIEF_NO_COLOR} $1 credentials exported to environment"
  echo -e "${CHIEF_COLOR_YELLOW}Revert with:${CHIEF_NO_COLOR} chief.aws.set_role to use file-based credentials"
  echo "$output" | grep '#' | sed 's/\# //'
}
