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

# $1 sets CHIEF_GIT_BRANCH, $2 sets CHIEF_PATH, $3 sets CHIEF_CONFIG

CHIEF_VERSION="v2.1.2"
CHIEF_GIT_REPO="https://github.com/randyoyarzabal/chief.git"
CHIEF_GIT_BRANCH="main"

CHIEF_BASHRC="$HOME/.bashrc"
CHIEF_CONFIG="$HOME/.chief_config.sh"
CHIEF_PATH="$HOME/.chief"
LOCAL_INSTALL=false

# Check for any overrides from defaults
if [[ -n "$1" ]]; then
  if [[ "$1" == "--local" ]]; then
    LOCAL_INSTALL=true
    if [[ -n "$2" ]]; then
      CHIEF_GIT_BRANCH="$2"
    fi

    if [[ -n "$3" ]]; then
      CHIEF_PATH="$3"
    fi

    if [[ -n "$4" ]]; then
      CHIEF_CONFIG="$4"
    fi
  else
    CHIEF_GIT_BRANCH="$1"

    if [[ -n "$2" ]]; then
      CHIEF_PATH="$2"
    fi

    if [[ -n "$3" ]]; then
      CHIEF_CONFIG="$3"
    fi
  fi
fi

CHIEF_CONFIG_LINES=(
  "export CHIEF_PATH=$CHIEF_PATH"
  "export CHIEF_CONFIG=$CHIEF_CONFIG"
  "source $CHIEF_PATH/chief.sh"
)

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
  echo -e "${CHIEF_COLOR_YELLOW}/ /__/ / / / /  __/ __/ ${CHIEF_NO_COLOR}${CHIEF_VERSION}"
  echo -e "${CHIEF_COLOR_YELLOW}\___/_/ /_/_/\___/_/ ${CHIEF_COLOR_CYAN}https://chief.reonetlabs.us${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_GREEN}Chief is now installed and configured. Configure it using the 'chief.configure' command.${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}Get your BASH together! ${CHIEF_COLOR_YELLOW}Restart your terminal or reload your ${CHIEF_BASHRC} file to start Chief.${CHIEF_NO_COLOR}"
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

function _chief_install (){
  echo "Installation parameters:
  CHIEF_GIT_BRANCH=$CHIEF_GIT_BRANCH
  CHIEF_PATH=$CHIEF_PATH
  CHIEF_CONFIG=$CHIEF_CONFIG"

  if [[ -d $CHIEF_PATH ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}You already have Chief installed.${CHIEF_NO_COLOR}"
    echo -e "You'll need to remove '$CHIEF_PATH' if you want to re-install it."
    return 1
  fi

  if ${LOCAL_INSTALL}; then
    local source_path="$(cd "$(dirname "$0")/.." && pwd)"
    cp -a "$source_path" "$CHIEF_PATH"
  else
    echo -e "${CHIEF_COLOR_BLUE}Cloning Chief (branch: $CHIEF_GIT_BRANCH)...${CHIEF_NO_COLOR}"
    umask g-w,o-w
    type -P git &> /dev/null || {
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
    git clone --branch "$CHIEF_GIT_BRANCH" --depth=1 "$CHIEF_GIT_REPO" "$CHIEF_PATH" || {
      echo -e "${CHIEF_COLOR_RED}Error: git clone of Chief repo failed.${CHIEF_NO_COLOR}"
      return 1
    }
  fi
  echo -e "${CHIEF_COLOR_GREEN}Chief was successfully installed in '${CHIEF_PATH}'.${CHIEF_NO_COLOR}"
}

function _chief_install_config () {
  echo -e "${CHIEF_COLOR_BLUE}Configuring Chief...${CHIEF_NO_COLOR}"
  if [[ ! -f "$CHIEF_CONFIG" ]]; then
    cp $CHIEF_PATH/templates/chief_config_template.sh $CHIEF_CONFIG
    echo -e "${CHIEF_COLOR_GREEN}Chief configuration file created at $CHIEF_CONFIG.${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_YELLOW}Chief configuration file already exists at $CHIEF_CONFIG.${CHIEF_NO_COLOR}"
  fi

  if [[ ! -f "$CHIEF_BASHRC" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error: ${CHIEF_BASHRC} file does not exist.${CHIEF_NO_COLOR}"
    response=$(_chief_confirm "Create it?")
    if [[ $response == 'yes' ]]; then
      touch "$CHIEF_BASHRC"
      for line in "${CHIEF_CONFIG_LINES[@]}"; do
        echo "$line" >> "$CHIEF_BASHRC"
      done
    else
      echo -e "${CHIEF_COLOR_YELLOW}Chief wasn't auto-added to your start-up scripts.${CHIEF_NO_COLOR}"
      echo -e "${CHIEF_COLOR_YELLOW}To use Chief, you must add the following lines to to your start-up scripts:${CHIEF_NO_COLOR}"
      for line in "${CHIEF_CONFIG_LINES[@]}"; do
        echo -e "${CHIEF_COLOR_CYAN}${line}${CHIEF_NO_COLOR}"
      done
      return 1
    fi
  else
    # Only append the lines if they are not already present
    for line in "${CHIEF_CONFIG_LINES[@]}"; do
      grep -qxF "$line" "${CHIEF_BASHRC}" || echo "$line" >> "${CHIEF_BASHRC}"
    done
  fi
  echo -e "${CHIEF_COLOR_GREEN}These lines were added to your ${CHIEF_BASHRC} (if it didn't already exist):${CHIEF_NO_COLOR}"
  for line in "${CHIEF_CONFIG_LINES[@]}"; do
    echo -e "  $line"
  done
}

function _chief_install_main () {
  _chief_install "$@" || {
    echo -e "${CHIEF_COLOR_RED}Chief installation failed.${CHIEF_NO_COLOR}"
    exit 1
  }

  _chief_install_config "$@" || {
    echo -e "${CHIEF_COLOR_RED}Chief configuration failed.${CHIEF_NO_COLOR}"
    exit 1
  }

  response=$(_chief_confirm "Would you like to enable Chief's git-aware prompt?
  If you are using a custom prompt, such as Oh-My-BASH, this will have no effect.
  Note that you can disable this later by running 'chief.configure'. 
  Try 'chief.git_legend' for details.")
  if [[ $response == 'yes' ]]; then
      echo -e "${CHIEF_COLOR_BLUE}Enabling CHIEF_CFG_PROMPT in $CHIEF_CONFIG.${CHIEF_NO_COLOR}"
      # Portable sed usage; reference: https://unix.stackexchange.com/a/381201
      sed -i.bak -e "s/CHIEF_CFG_PROMPT\=false/CHIEF_CFG_PROMPT\=true/g" -- "${CHIEF_CONFIG}" && rm -- "${CHIEF_CONFIG}.bak"
  fi
  _chief.banner
}

_chief_install_main "$@"

if [[ $? -ne 0 ]]; then
  echo -e "${CHIEF_COLOR_RED}Chief installation failed. Please check the error messages above.${CHIEF_NO_COLOR}"
  exit 1
fi
