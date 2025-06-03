#!/usr/bin/env bash

CHIEF_VERSION="v1.1 (2025-Jun-3)"
CHIEF_REPOSITORY="https://github.com/randyoyarzabal/chief.git"
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
  echo -e "${CHIEF_COLOR_YELLOW}/ /__/ / / / /  __/ __/ ${CHIEF_NO_COLOR}${CHIEF_VERSION} [${PLATFORM}]"
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

function _chief_install {
  if [[ -d $CHIEF_PATH ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}You already have Chief installed.${CHIEF_NO_COLOR}"
    echo -e "You'll need to remove '$CHIEF_PATH' if you want to re-install it."
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Cloning Chief...${CHIEF_NO_COLOR}"
  umask g-w,o-w
  type -P git &>/dev/null || {
    echo -e "${CHIEF_COLOR_RED}Error: git is not installed.${CHIEF_NO_COLOR}"
    return 1
  }
  # The Windows (MSYS) Git is not compatible with normal use on cygwin
  if [[ $OSTYPE == cygwin ]]; then
    if command git --version | command grep msysgit > /dev/null; then
      echo "Error: Windows/MSYS Git is not supported on Cygwin"
      echo "Error: Make sure the Cygwin git package is installed and is first on the path"
      return 1
    fi
  fi
  git clone --depth=1 "$CHIEF_REPOSITORY" "$CHIEF_PATH" || {
    echo -e "${CHIEF_COLOR_RED}Error: git clone of Chief repo failed.${CHIEF_NO_COLOR}"
    return 1
  }
  echo -e "${CHIEF_COLOR_GREEN}Chief was successfully installed in '${CHIEF_PATH}'.${CHIEF_NO_COLOR}"
}

function _chief_install_config {
  echo -e "${CHIEF_COLOR_BLUE}Configuring Chief...${CHIEF_NO_COLOR}"
  if [[ ! -f "$CHIEF_CONFIG" ]]; then
    cp $CHIEF_PATH/templates/chief_config_template.sh $CHIEF_CONFIG
    echo -e "${CHIEF_COLOR_GREEN}Chief configuration file created at $CHIEF_CONFIG.${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_YELLOW}Chief configuration file already exists at $CHIEF_CONFIG.${CHIEF_NO_COLOR}"
  fi

  # Chief Environment
  local config_lines=(
    "export CHIEF_CONFIG=\"\$HOME/.chief_config.sh\""
    "export CHIEF_PATH=\"\$HOME/.chief\""
    "source \${CHIEF_PATH}/chief.sh"
  )

  # Check if .bashrc exists
  if [[ ! -f "$HOME/.bashrc" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error: ~/.bashrc file does not exist.${CHIEF_NO_COLOR}"
    response=$(_chief_confirm "Create it?")
    if [[ $response == 'yes' ]]; then
      touch "$HOME/.bashrc"
      for line in "${config_lines[@]}"; do
        echo "$line" >> "$HOME/.bashrc"
      done
    else
      echo -e "${CHIEF_COLOR_YELLOW}Chief wasn't auto-added to your start-up scripts.${CHIEF_NO_COLOR}"
      echo -e "${CHIEF_COLOR_YELLOW}To use Chief, you must add the following lines to to your start-up scripts:${CHIEF_NO_COLOR}"
      for line in "${config_lines[@]}"; do
        echo -e "${CHIEF_COLOR_CYAN}${line}${CHIEF_NO_COLOR}"
      done
      return 1
    fi
  else
    # Only append the lines if they are not already present
    for line in "${config_lines[@]}"; do
      grep -qxF "$line" "$HOME/.bashrc" || echo "$line" >> "$HOME/.bashrc"
    done
  fi
  echo -e "${CHIEF_COLOR_GREEN}These lines were added to your ~/.bashrc (if it didn't already exist):${CHIEF_NO_COLOR}"
  for line in "${config_lines[@]}"; do
    echo -e "  $line"
  done
}

function _chief_install_main () {
  _chief_install || {
    echo -e "${CHIEF_COLOR_RED}Chief installation failed.${CHIEF_NO_COLOR}"
    exit 1
  }

  _chief_install_config || {
    echo -e "${CHIEF_COLOR_RED}Chief configuration failed.${CHIEF_NO_COLOR}"
    exit 1
  }

  _chief.banner
  echo -e "${CHIEF_COLOR_GREEN}Chief is now installed and configured.${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}Get your BASH together! ${CHIEF_COLOR_YELLOW}Restart your terminal or reload your ~/.bashrc file to start Chief.${CHIEF_NO_COLOR}"
}

_chief_install_main