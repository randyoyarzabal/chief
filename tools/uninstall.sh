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

# $1 sets CHIEF_PATH, $2 sets CHIEF_CONFIG

# Set default .bashrc vars
CHIEF_PATH="$HOME/.chief"
CHIEF_CONFIG="$HOME/.chief_config.sh"

# Check for any overrides from defaults
if [[ -n "$1" ]]; then
  CHIEF_PATH="$2"
fi

if [[ -n "$2" ]]; then
  CHIEF_CONFIG="$3"
fi

# Chief loading lines for .bashrc
CHIEF_CONFIG_LINES=(
  "export CHIEF_CONFIG=$CHIEF_CONFIG"
  "export CHIEF_PATH=$CHIEF_PATH"
  "source $CHIEF_PATH/chief.sh"
)

CHIEF_BASHRC="$HOME/.bashrc"

CHIEF_COLOR_RED='\033[0;31m'
CHIEF_COLOR_BLUE='\033[0;34m'
CHIEF_COLOR_CYAN='\033[0;36m'
CHIEF_COLOR_GREEN='\033[0;32m'
CHIEF_COLOR_YELLOW='\033[1;33m'
CHIEF_NO_COLOR='\033[0m' # Reset color/style

function _chief.banner {
  echo -e "${CHIEF_COLOR_YELLOW}        __    _      ____${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}  _____/ /_  (_)__  / __/${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW} / ___/ __ \/ / _ \/ /_  ${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}/ /__/ / / / /  __/ __/  ${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}\___/_/ /_/_/\___/_/ ${CHIEF_COLOR_CYAN}https://chief.reonetlabs.us${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_CYAN}Thank you for using Chief! ${CHIEF_COLOR_GREEN}Feel free to send us feedback at chief@randyoyarzabal.com${CHIEF_NO_COLOR}"
}

function _chief_confirm() {
  local USAGE="Usage: $FUNCNAME <msg/question>

Display a yes/no user prompt and echo the response.
Returns 'yes' or 'no' string.

Example:
   response=\$($FUNCNAME 'Do you want to continue?')
"
  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  read -p "$1 ([y]es or [N]o): "
  case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
    y | yes) echo "yes" ;;
    *) echo "no" ;;
  esac
}

function _chief_uninstall {
  if [[ ! -d $CHIEF_PATH ]]; then
  echo "Uninstallation parameters:
  CHIEF_PATH=$CHIEF_PATH
  CHIEF_CONFIG=$CHIEF_CONFIG"
  
    echo -e "${CHIEF_COLOR_YELLOW}Chief is not installed, nothing to remove.${CHIEF_NO_COLOR}"
    return 1
  fi

  # Check if Chief is installed 
  response=$(_chief_confirm "Are you sure you want to uninstall the Chief utility? 
Uninstallation parameters:
  CHIEF_PATH=$CHIEF_PATH
  CHIEF_CONFIG=$CHIEF_CONFIG
The configuration file will be backed up as ${CHIEF_CONFIG}.backup.
All plugin files and plugin directories will NOT be removed.
This action cannot be undone. Proceed with uninstallation?")
  if [[ $response == 'no' ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Uninstall aborted.${CHIEF_NO_COLOR}"
    return 0
  fi
  # Remove the Chief installation directory
  echo -e "${CHIEF_COLOR_BLUE}Removing Chief installation directory...${CHIEF_NO_COLOR}"
  rm -rf "$CHIEF_PATH" || {
    echo -e "${CHIEF_COLOR_RED}Error: Could not remove Chief installation directory.${CHIEF_NO_COLOR}"
    return 1
  }
  echo -e "${CHIEF_COLOR_GREEN}Chief installation directory removed successfully.${CHIEF_NO_COLOR}"

  # Remove the Chief configuration file
  if [[ -f $CHIEF_CONFIG ]]; then
    # Backup the configuration file before removing it
    echo -e "${CHIEF_COLOR_BLUE}Backing up Chief configuration file...${CHIEF_NO_COLOR}"
    cp "$CHIEF_CONFIG" "${CHIEF_CONFIG}.backup" || {
      echo -e "${CHIEF_COLOR_RED}Error: Could not backup Chief configuration file.${CHIEF_NO_COLOR}"
      return 1
    }
    echo -e "${CHIEF_COLOR_BLUE}Removing Chief configuration file...${CHIEF_NO_COLOR}"
    rm -f "$CHIEF_CONFIG" || {
      echo -e "${CHIEF_COLOR_RED}Error: Could not remove Chief configuration file.${CHIEF_NO_COLOR}"
      return 1
    }
    echo -e "${CHIEF_COLOR_GREEN}Chief configuration file removed successfully.${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_YELLOW}Chief configuration file does not exist, nothing to remove.${CHIEF_NO_COLOR}"
  fi

  # Remove lines from .bashrc
  if [[ -f "$HOME/.bashrc" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Removing Chief lines from ~/.bashrc...${CHIEF_NO_COLOR}"
    for line in "${CHIEF_CONFIG_LINES[@]}"; do
      echo -e "${CHIEF_COLOR_BLUE}Removing line from ~/.bashrc: $line${CHIEF_NO_COLOR}"
      # Portable sed usage; reference: https://unix.stackexchange.com/a/381201
      sed -i.bak -e "/$(echo "$line" | sed 's/[\/&]/\\&/g')/d" -- "${CHIEF_BASHRC}" && rm -- "${CHIEF_BASHRC}.bak"
    done
    echo -e "${CHIEF_COLOR_GREEN}Chief lines removed from ~/.bashrc.${CHIEF_NO_COLOR}"
    # fi
  else
    echo -e "${CHIEF_COLOR_YELLOW}~/.bashrc does not exist, nothing to remove.${CHIEF_NO_COLOR}"
  fi 
  _chief.banner
  echo -e "${CHIEF_COLOR_GREEN}Chief was successfully uninstalled.${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}Plugin files and directories were NOT removed. You can remove them manually if you wish.${CHIEF_NO_COLOR}"
}

_chief_uninstall