#!/usr/bin/env bash

BASHRC_FILE="$HOME/.bashrc"

# Chief Environment
CHIEF_CONFIG_LINES=(
  "export CHIEF_CONFIG=\"\$HOME/.chief_config.sh\""
  "export CHIEF_PATH=\"\$HOME/.chief\""
  "source \${CHIEF_PATH}/chief.sh"
)

function _chief_uninstall {
  # Use sed to remove lines from .bashrc on non MacOS systems
  echo -e "${CHIEF_COLOR_BLUE}Removing Chief lines from ~/.bashrc...${CHIEF_NO_COLOR}"
  for line in "${CHIEF_CONFIG_LINES[@]}"; do
    echo -e "${CHIEF_COLOR_BLUE}Removing line from ~/.bashrc: $line${CHIEF_NO_COLOR}"
    # sed -i "/$(echo "$line" | sed 's/[\/&]/\\&/g')/d" "$HOME/.bashrc"
    # Portable sed usage: https://unix.stackexchange.com/a/381201
    sed -i.bak -e "/$(echo "$line" | sed 's/[\/&]/\\&/g')/d" -- "${BASHRC_FILE}" && rm -- "${BASHRC_FILE}.bak"
  done
}

_chief_uninstall