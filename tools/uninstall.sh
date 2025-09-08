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

set -e  # Exit on any error

# Parse command line arguments
CHIEF_PATH="$HOME/.chief"
CHIEF_CONFIG="$HOME/.chief_config.sh"
CHIEF_BASH_PROFILE="$HOME/.bash_profile"

while [[ $# -gt 0 ]]; do
  case $1 in
    --path)
      CHIEF_PATH="$2"
      shift 2
      ;;
    --config)
      CHIEF_CONFIG="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Uninstall Chief - Bash Plugin Manager & Terminal Enhancement Tool"
      echo ""
      echo "Options:"
      echo "  --path PATH       Installation directory (default: ~/.chief)"
      echo "  --config CONFIG   Configuration file path (default: ~/.chief_config.sh)"
      echo "  --help, -h        Show this help message"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Try to source centralized constants for banner
if [[ -f "${CHIEF_PATH}/VERSION" ]]; then
  source "${CHIEF_PATH}/VERSION"
else
  CHIEF_WEBSITE="https://chief.reonetlabs.us"
fi

# Colors
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

confirm() {
  read -p "$1 ([y]es or [N]o): " -r
  [[ $REPLY =~ ^[Yy]$ ]]
}

print_banner() {
  echo -e "${YELLOW}        __    _      ____${NC}"
  echo -e "${YELLOW}  _____/ /_  (_)__  / __/${NC}"
  echo -e "${YELLOW} / ___/ __ \\/ / _ \\/ /_  ${NC}"
  echo -e "${YELLOW}/ /__/ / / / /  __/ __/ ${NC}"
  echo -e "${YELLOW}\\___/_/ /_/_/\\___/_/ ${CYAN}${CHIEF_WEBSITE}${NC}"
  echo ""
  echo -e "${GREEN}SUCCESS: Chief uninstalled successfully!${NC}"
  echo -e "${CYAN}Thank you for using Chief!${NC}"
}

uninstall_chief() {
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}       CHIEF UNINSTALLATION${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo ""
  echo -e "${CYAN}  Directory: ${NC}$CHIEF_PATH"
  echo -e "${CYAN}  Config:    ${NC}$CHIEF_CONFIG"
  echo ""

  # Check if Chief is installed
  if [[ ! -d "$CHIEF_PATH" ]]; then
    echo -e "${YELLOW}WARNING: Chief is not installed at $CHIEF_PATH${NC}"
    exit 1
  fi

  # Confirm uninstallation
  echo -e "${RED}WARNING: This will completely remove Chief from your system${NC}"
  echo -e "${YELLOW}INFO: Your configuration will be backed up as ${CHIEF_CONFIG}.backup${NC}"
  echo -e "${YELLOW}INFO: Custom plugins will NOT be removed${NC}"
  echo ""
  
  if ! confirm "Are you sure you want to uninstall Chief?"; then
    echo -e "${YELLOW}Uninstallation cancelled${NC}"
    exit 0
  fi

  # Remove installation directory
  echo -e "${BLUE}Removing installation directory...${NC}"
  rm -rf "$CHIEF_PATH"
  echo -e "${GREEN}SUCCESS: Installation directory removed${NC}"

  # Backup and remove configuration file
  if [[ -f "$CHIEF_CONFIG" ]]; then
    echo -e "${BLUE}Backing up configuration file...${NC}"
    cp "$CHIEF_CONFIG" "${CHIEF_CONFIG}.backup"
    rm -f "$CHIEF_CONFIG"
    echo -e "${GREEN}SUCCESS: Configuration backed up and removed${NC}"
  fi

  # Remove lines from .bash_profile
  if [[ -f "$CHIEF_BASH_PROFILE" ]]; then
    echo -e "${BLUE}Cleaning up $CHIEF_BASH_PROFILE...${NC}"
    sed -i.bak \
      -e '/^[^#]*export CHIEF_PATH=/d' \
      -e '/^[^#]*export CHIEF_CONFIG=/d' \
      -e '/^[^#].*chief\.sh$/d' \
      "$CHIEF_BASH_PROFILE" && rm "${CHIEF_BASH_PROFILE}.bak"
    echo -e "${GREEN}SUCCESS: Shell configuration cleaned${NC}"
  fi

  print_banner
}

# Main uninstallation flow
uninstall_chief