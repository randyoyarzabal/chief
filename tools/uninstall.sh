#!/usr/bin/env bash

CHIEF_PATH="$HOME/.chief"
CHIEF_CONFIG="$HOME/.chief_config.sh" 

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
  # TODO: Implement uninstall functionality

  # Remove the Chief installation directory
  if [[ -d $CHIEF_PATH ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Removing Chief installation directory...${CHIEF_NO_COLOR}"
    rm -rf "$CHIEF_PATH" || {
      echo -e "${CHIEF_COLOR_RED}Error: Could not remove Chief installation directory.${CHIEF_NO_COLOR}"
      return 1
    }
    echo -e "${CHIEF_COLOR_GREEN}Chief installation directory removed successfully.${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_YELLOW}Chief is not installed, nothing to remove.${CHIEF_NO_COLOR}"
  fi
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
    sed -i '/export CHIEF_CONFIG="\$HOME\/.chief_config.sh"/d' "$HOME/.bashrc"
    sed -i '/export CHIEF_PATH="\$HOME\/.chief"/d' "$HOME/.bashrc"
    sed -i '/source \${CHIEF_PATH}\/chief.sh/d' "$HOME/.bashrc"
    echo -e "${CHIEF_COLOR_GREEN}Chief lines removed from ~/.bashrc.${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_YELLOW}~/.bashrc does not exist, nothing to remove.${CHIEF_NO_COLOR}"
  fi 
  _chief.banner
  echo -e "${CHIEF_COLOR_GREEN}Chief was successfully un-installed.${CHIEF_NO_COLOR}"
}

_chief_uninstall