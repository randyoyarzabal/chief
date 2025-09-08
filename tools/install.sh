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

# Try to source centralized constants file, fall back to local constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/../VERSION"

if [[ -f "$VERSION_FILE" ]]; then
  source "$VERSION_FILE"
else
  # Fallback constants if VERSION file doesn't exist (e.g., standalone install script)
  export CHIEF_VERSION="v3.0"
  export CHIEF_GIT_REPO="https://github.com/randyoyarzabal/chief.git"
  export CHIEF_INSTALL_GIT_BRANCH="dev"
  export CHIEF_WEBSITE="https://chief.reonetlabs.us"
fi

# Default settings
CHIEF_BASH_PROFILE="$HOME/.bash_profile"
CHIEF_CONFIG="$HOME/.chief_config.sh"
CHIEF_PATH="$HOME/.chief"
LOCAL_INSTALL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --local)
      LOCAL_INSTALL=true
      shift
      ;;
    --branch)
      CHIEF_INSTALL_GIT_BRANCH="$2"
      shift 2
      ;;
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
      echo "Install Chief - Bash Plugin Manager & Terminal Enhancement Tool"
      echo ""
      echo "Options:"
      echo "  --local           Install from local directory (for development)"
      echo "  --branch BRANCH   Git branch to install from (default: main)"
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

# Colors
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration lines to add to .bash_profile
CONFIG_LINES=(
  "export CHIEF_PATH=$CHIEF_PATH"
  "export CHIEF_CONFIG=$CHIEF_CONFIG"
  "source $CHIEF_PATH/chief.sh"
)

confirm() {
  read -p "$1 ([y]es or [N]o): " -r
  [[ $REPLY =~ ^[Yy]$ ]]
}

print_banner() {
  echo -e "${YELLOW}        __    _      ____${NC}"
  echo -e "${YELLOW}  _____/ /_  (_)__  / __/${NC}"
  echo -e "${YELLOW} / ___/ __ \\/ / _ \\/ /_  ${NC}"
  echo -e "${YELLOW}/ /__/ / / / /  __/ __/ ${NC}${CHIEF_VERSION}"
  echo -e "${YELLOW}\\___/_/ /_/_/\\___/_/ ${CYAN}${CHIEF_WEBSITE}${NC}"
  echo ""
  echo -e "${GREEN}SUCCESS: Chief installed successfully!${NC}"
  echo -e "${BLUE}INFO: Restart your terminal or run: ${YELLOW}source ~/.bash_profile${NC}"
}

install_chief() {
  echo -e "${BLUE}Installing Chief...${NC}"
  echo -e "${CYAN}  Directory: ${NC}$CHIEF_PATH"
  echo -e "${CYAN}  Config:    ${NC}$CHIEF_CONFIG"
  echo -e "${CYAN}  Branch:    ${NC}$CHIEF_INSTALL_GIT_BRANCH"
  echo ""

  # Check if already installed
  if [[ -d "$CHIEF_PATH" ]]; then
    echo -e "${YELLOW}WARNING: Chief is already installed at $CHIEF_PATH${NC}"
    if ! confirm "Remove existing installation and reinstall?"; then
      echo -e "${YELLOW}Installation aborted${NC}"
      exit 1
    fi
    rm -rf "$CHIEF_PATH"
  fi

  # Install Chief
  if $LOCAL_INSTALL; then
    echo -e "${BLUE}Copying from local directory...${NC}"
    local source_path="$(cd "$(dirname "$0")/.." && pwd)"
    cp -a "$source_path" "$CHIEF_PATH"
  else
    echo -e "${BLUE}Cloning from GitHub (branch: $CHIEF_INSTALL_GIT_BRANCH)...${NC}"
    
    # Check for git
    if ! command -v git >/dev/null 2>&1; then
      echo -e "${RED}ERROR: git is required but not installed${NC}"
      exit 1
    fi
    
    git clone --branch "$CHIEF_INSTALL_GIT_BRANCH" --depth=1 "$CHIEF_GIT_REPO" "$CHIEF_PATH"
  fi

  echo -e "${GREEN}SUCCESS: Chief files installed${NC}"
}

setup_config() {
  echo ""
  echo -e "${BLUE}Setting up configuration...${NC}"
  
  # Copy config template if needed
  if [[ ! -f "$CHIEF_CONFIG" ]]; then
    cp "$CHIEF_PATH/templates/chief_config_template.sh" "$CHIEF_CONFIG"
    echo -e "${GREEN}SUCCESS: Configuration file created at $CHIEF_CONFIG${NC}"
  else
    echo -e "${YELLOW}INFO: Configuration file already exists at $CHIEF_CONFIG${NC}"
  fi

  echo ""
  echo -e "${BLUE}Setting up shell integration...${NC}"
  
  # Setup .bash_profile
  if [[ ! -f "$CHIEF_BASH_PROFILE" ]]; then
    echo -e "${CYAN}Chief needs to create $CHIEF_BASH_PROFILE to load automatically.${NC}"
    if confirm "Create $CHIEF_BASH_PROFILE?"; then
      touch "$CHIEF_BASH_PROFILE"
      echo -e "${GREEN}SUCCESS: Created $CHIEF_BASH_PROFILE${NC}"
    else
      echo -e "${YELLOW}WARNING: Skipping automatic shell setup${NC}"
      echo -e "${CYAN}You'll need to add these lines to your shell config manually:${NC}"
      echo ""
      for line in "${CONFIG_LINES[@]}"; do
        echo -e "${YELLOW}  $line${NC}"
      done
      echo ""
      return
    fi
  fi

  # Add config lines if not already present
  echo -e "${CYAN}Adding Chief configuration to $CHIEF_BASH_PROFILE...${NC}"
  local added_lines=0
  for line in "${CONFIG_LINES[@]}"; do
    if ! grep -qxF "$line" "$CHIEF_BASH_PROFILE"; then
      echo "$line" >> "$CHIEF_BASH_PROFILE"
      echo -e "${CYAN}  Added: ${YELLOW}$line${NC}"
      ((added_lines++))
    else
      echo -e "${CYAN}  Found: ${YELLOW}$line${NC}"
    fi
  done

  if [[ $added_lines -gt 0 ]]; then
    echo -e "${GREEN}SUCCESS: Added $added_lines new line(s) to $CHIEF_BASH_PROFILE${NC}"
  else
    echo -e "${GREEN}SUCCESS: Shell configuration already up to date${NC}"
  fi
}

setup_prompt() {
  echo ""
  echo -e "${BLUE}Would you like to enable Chief's git-aware prompt?${NC}"
  echo -e "${CYAN}  If you are using a custom prompt, such as Oh-My-BASH, this will have no effect.${NC}"
  echo -e "${CYAN}  Note that you can disable this later by running 'chief.config'.${NC}"
  echo ""
  
  if confirm "Enable git-aware prompt?"; then
    sed -i.bak 's/CHIEF_CFG_PROMPT=false/CHIEF_CFG_PROMPT=true/' "$CHIEF_CONFIG" && rm "$CHIEF_CONFIG.bak"
    echo -e "${GREEN}SUCCESS: Git-aware prompt enabled${NC}"
    echo -e "${CYAN}INFO: The prompt will show branch status and repository information${NC}"
  else
    echo -e "${YELLOW}INFO: Git-aware prompt disabled (you can enable it later with chief.config)${NC}"
  fi
}

# Main installation flow
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}        CHIEF INSTALLATION${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

install_chief
setup_config  
setup_prompt
print_banner

echo -e "${CYAN}NEXT STEPS:${NC}"
echo -e "${CYAN}  Run 'chief.config' to customize your settings${NC}"
echo -e "${CYAN}  Run 'chief.plugin -?' to learn about plugins${NC}"