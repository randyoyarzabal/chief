#!/usr/bin/env bash

CHIEF_REPOSITORY="https://github.com/randyoyarzabal/chief.git"
CHIEF_INSTALL_DIR="$HOME/.chief"
CHIEF_CONFIG_FILE="$HOME/.chief_config-test.sh" 

# COLORS
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_GREEN='\033[0;32m'
COLOR_MAGENTA='\033[0;35m'
COLOR_ORANGE='\033[0;33m'
COLOR_YELLOW='\033[1;33m'
TEXT_BLINK='\033[5m'
NO_COLOR='\033[0m' # Reset color/style

function _chief_install {
  if [[ -d $CHIEF_INSTALL_DIR ]]; then
    echo -e "${COLOR_YELLOW}You already have Chief installed.${NO_COLOR}"
    echo -e "You'll need to remove '$CHIEF_INSTALL_DIR' if you want to re-install it."
    return 1
  fi

  echo -e "${COLOR_BLUE}Cloning Chief...${NO_COLOR}"
  umask g-w,o-w
  type -P git &>/dev/null || {
    echo -e "${COLOR_RED}Error: git is not installed.${NO_COLOR}"
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
  git clone --depth=1 "$CHIEF_REPOSITORY" "$CHIEF_INSTALL_DIR" || {
    echo -e "${COLOR_RED}Error: git clone of Chief repo failed.${NO_COLOR}"
    return 1
  }
}

function _chief_install_config {
  echo -e "${COLOR_BLUE}Configuring Chief...${NO_COLOR}"
  if [[ ! -f "$CHIEF_CONFIG_FILE" ]]; then
    cp $CHIEF_INSTALL_DIR/templates/chief_config_template.sh $CHIEF_CONFIG_FILE
  fi

  # Chief Environment
  local config_lines=(
    "export CHIEF_CONFIG=\"\$HOME/.chief_config-test.sh\""
    "export CHIEF_PATH=\"\$HOME/.chief\""
    "source \${CHIEF_PATH}/chief.sh"
  )

  # Only append the lines if they are not already present
  for line in "${config_lines[@]}"; do
    grep -qxF "$line" "$HOME/.bashrc" || echo "$line" >> "$HOME/.bashrc"
  done
  echo -e "${COLOR_GREEN}Chief has been configured successfully!${NO_COLOR}"
}

function _chief_install_banner {
  echo -e "${COLOR_CYAN}Thank you for using Chief${NO_COLOR}"
  echo -e "${COLOR_BLUE}Get your Bash together!${NO_COLOR}"
}

_chief_install || {
  echo -e "${COLOR_RED}Chief installation failed.${NO_COLOR}"
  exit 1
}

_chief_install_config || {
  echo -e "${COLOR_RED}Chief configuration failed.${NO_COLOR}"
  exit 1
}