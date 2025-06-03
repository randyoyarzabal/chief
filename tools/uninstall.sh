#!/usr/bin/env bash

CHIEF_INSTALL_DIR="$HOME/.chief"
CHIEF_CONFIG_FILE="$HOME/.chief_config.sh" 

COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
NO_COLOR='\033[0m' # Reset color/style

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
  if [[ -d $CHIEF_INSTALL_DIR ]]; then
    echo -e "${COLOR_BLUE}Removing Chief installation directory...${NO_COLOR}"
    rm -rf "$CHIEF_INSTALL_DIR" || {
      echo -e "${COLOR_RED}Error: Could not remove Chief installation directory.${NO_COLOR}"
      return 1
    }
    echo -e "${COLOR_GREEN}Chief installation directory removed successfully.${NO_COLOR}"
  else
    echo -e "${COLOR_YELLOW}Chief is not installed, nothing to remove.${NO_COLOR}"
  fi
  # Remove the Chief configuration file
  if [[ -f $CHIEF_CONFIG_FILE ]]; then
    # Backup the configuration file before removing it
    echo -e "${COLOR_BLUE}Backing up Chief configuration file...${NO_COLOR}"
    cp "$CHIEF_CONFIG_FILE" "${CHIEF_CONFIG_FILE}.backup" || {
      echo -e "${COLOR_RED}Error: Could not backup Chief configuration file.${NO_COLOR}"
      return 1
    }
    echo -e "${COLOR_BLUE}Removing Chief configuration file...${NO_COLOR}"
    rm -f "$CHIEF_CONFIG_FILE" || {
      echo -e "${COLOR_RED}Error: Could not remove Chief configuration file.${NO_COLOR}"
      return 1
    }
    echo -e "${COLOR_GREEN}Chief configuration file removed successfully.${NO_COLOR}"
  else
    echo -e "${COLOR_YELLOW}Chief configuration file does not exist, nothing to remove.${NO_COLOR}"
  fi
  # Remove lines from .bashrc
  if [[ -f "$HOME/.bashrc" ]]; then
    echo -e "${COLOR_BLUE}Removing Chief lines from ~/.bashrc...${NO_COLOR}"
    sed -i '/export CHIEF_CONFIG="\$HOME\/.chief_config.sh"/d' "$HOME/.bashrc"
    sed -i '/export CHIEF_PATH="\$HOME\/.chief"/d' "$HOME/.bashrc"
    sed -i '/source \${CHIEF_PATH}\/chief.sh/d' "$HOME/.bashrc"
    echo -e "${COLOR_GREEN}Chief lines removed from ~/.bashrc.${NO_COLOR}"
  else
    echo -e "${COLOR_YELLOW}~/.bashrc does not exist, nothing to remove.${NO_COLOR}"
  fi 
  echo -e "${COLOR_GREEN}Chief was successfully un-installed.${NO_COLOR}"
}

_chief_uninstall