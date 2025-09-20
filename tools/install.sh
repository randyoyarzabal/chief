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

# Try to source centralized constants file, fall back to local constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/../VERSION"

if [[ -f "$VERSION_FILE" ]]; then
  source "$VERSION_FILE"
else
  # Fallback constants if VERSION file doesn't exist (e.g., standalone install script)
  export CHIEF_GIT_REPO="https://github.com/randyoyarzabal/chief.git"
  export CHIEF_INSTALL_GIT_BRANCH="main"
fi

# Default settings
CHIEF_BASH_PROFILE="$HOME/.bash_profile"
CHIEF_CONFIG="$HOME/.chief_config.sh"
CHIEF_PATH="$HOME/.chief"
LOCAL_INSTALL=false
BRANCH_SPECIFIED=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --local)
      LOCAL_INSTALL=true
      shift
      ;;
    --branch)
      CHIEF_INSTALL_GIT_BRANCH="$2"
      BRANCH_SPECIFIED=true
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
      echo "  --local           Install from local directory (for disconnected"
      echo "                    environments without git connectivity)"
      echo "  --branch BRANCH   Git branch to install from (default: main)"
      echo "                    Note: Ignored when using --local"
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

# Validate argument combinations
if $LOCAL_INSTALL && $BRANCH_SPECIFIED; then
  echo -e "\033[1;33mWARNING: --branch option is ignored when using --local installation.\033[0m"
  echo -e "\033[0;36mLocal installations use the files present in the current directory,\033[0m"
  echo -e "\033[0;36mnot a specific git branch. This is intended for disconnected environments.\033[0m"
  echo ""
fi

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
  # Read version and website from installed Chief VERSION file
  local version="Unknown"
  local website="https://chief.reonetlabs.us"  # Default fallback
  
  if [[ -f "$CHIEF_PATH/VERSION" ]]; then
    source "$CHIEF_PATH/VERSION"
    version="$CHIEF_VERSION"
    website="$CHIEF_WEBSITE"
  fi
  
  echo -e "${YELLOW}        __    _      ____${NC}"
  echo -e "${YELLOW}  _____/ /_  (_)__  / __/${NC}"
  echo -e "${YELLOW} / ___/ __ \\/ / _ \\/ /_  ${NC}"
  echo -e "${YELLOW}/ /__/ / / / /  __/ __/ ${NC}${version}"
  echo -e "${YELLOW}\\___/_/ /_/_/\\___/_/ ${CYAN}${website}${NC}"
  echo ""
  echo -e "${GREEN}SUCCESS: Chief installed successfully!${NC}"
}

install_chief() {
  local existing_installation=false
  echo -e "${BLUE}Installing Chief...${NC}"
  echo -e "${CYAN}  Directory: ${NC}$CHIEF_PATH"
  echo -e "${CYAN}  Config:    ${NC}$CHIEF_CONFIG"
  if ! $LOCAL_INSTALL; then
    echo -e "${CYAN}  Branch:    ${NC}$CHIEF_INSTALL_GIT_BRANCH"
  else
    echo -e "${CYAN}  Mode:      ${NC}Local installation (disconnected)"
  fi
  echo ""

  # Check if already installed
  if [[ -d "$CHIEF_PATH" ]]; then
    existing_installation=true
    if $LOCAL_INSTALL; then
      echo -e "${YELLOW}INFO: Chief is already installed at $CHIEF_PATH${NC}"
      if ! confirm "Update existing installation with local files?"; then
        echo -e "${YELLOW}Update aborted${NC}"
        exit 1
      fi
      echo -e "${CYAN}Updating existing installation...${NC}"
    else
      echo -e "${YELLOW}WARNING: Chief is already installed at $CHIEF_PATH${NC}"
      if ! confirm "Remove existing installation and reinstall?"; then
        echo -e "${YELLOW}Installation aborted${NC}"
        exit 1
      fi
      echo -e "${CYAN}Removing existing installation...${NC}"
    fi
    
    # Check if we're running from within the target directory
    local current_dir="$(pwd)"
    local target_dir="$(cd "$CHIEF_PATH" && pwd 2>/dev/null || echo "$CHIEF_PATH")"
    
    if [[ "$current_dir" == "$target_dir"* ]]; then
      echo -e "${CYAN}Script running from within target directory, changing to safe location...${NC}"
      cd "$HOME" || cd /tmp || {
        echo -e "${RED}ERROR: Cannot change to safe directory${NC}"
        exit 1
      }
    fi
    
    rm -rf "$CHIEF_PATH"
  fi

  # Install Chief
  if $LOCAL_INSTALL; then
    if $existing_installation; then
      echo -e "${BLUE}Updating from local directory (disconnected update)...${NC}"
    else
      echo -e "${BLUE}Copying from local directory (disconnected installation)...${NC}"
    fi
    local source_path="$(cd "$(dirname "$0")/.." && pwd)"
    cp -a "$source_path" "$CHIEF_PATH"
    
    # Remove any .git directory and git-related files to ensure disconnected mode
    if [[ -d "$CHIEF_PATH/.git" ]]; then
      echo -e "${CYAN}Removing git repository data for disconnected environment...${NC}"
      rm -rf "$CHIEF_PATH/.git"
    fi
    
    # Remove other git-related files that might exist  
    rm -f "$CHIEF_PATH/.gitignore" "$CHIEF_PATH/.gitattributes" 2>/dev/null || true
    
    # Confirm disconnected mode setup
    echo -e "${CYAN}Disconnected installation: git connectivity disabled${NC}"
    
    if $existing_installation; then
      echo -e "${GREEN}SUCCESS: Local files updated for disconnected environment${NC}"
    else
      echo -e "${GREEN}SUCCESS: Local files copied for disconnected environment${NC}"
    fi
  else
    echo -e "${BLUE}Cloning fresh installation from GitHub (branch: $CHIEF_INSTALL_GIT_BRANCH)...${NC}"
    
    # Check for git
    if ! command -v git >/dev/null 2>&1; then
      echo -e "${RED}ERROR: git is required but not installed${NC}"
      exit 1
    fi
    
    # Clone with full history to support branch switching
    git clone --branch "$CHIEF_INSTALL_GIT_BRANCH" "$CHIEF_GIT_REPO" "$CHIEF_PATH" || {
      echo -e "${RED}ERROR: Failed to clone from branch $CHIEF_INSTALL_GIT_BRANCH${NC}"
      echo -e "${YELLOW}Please check that the branch exists and you have internet connectivity${NC}"
      exit 1
    }
    
    # Ensure all remote branches are available for later branch switching
    cd "$CHIEF_PATH"
    git fetch origin || {
      echo -e "${YELLOW}WARNING: Failed to fetch additional remote branches${NC}"
    }
    cd - > /dev/null 2>&1
    
    echo -e "${GREEN}SUCCESS: Cloned ${CHIEF_INSTALL_GIT_BRANCH} branch with full remote branch access${NC}"
  fi

  echo -e "${GREEN}SUCCESS: Chief files installed${NC}"
  
  # Validate installation
  echo -e "${CYAN}Validating installation...${NC}"
  local missing_files=()
  
  if [[ ! -f "$CHIEF_PATH/chief.sh" ]]; then
    missing_files+=("$CHIEF_PATH/chief.sh")
  fi
  
  if [[ ! -f "$CHIEF_PATH/templates/chief_config_template.sh" ]]; then
    missing_files+=("$CHIEF_PATH/templates/chief_config_template.sh")
  fi
  
  if [[ ! -d "$CHIEF_PATH/libs/core" ]]; then
    missing_files+=("$CHIEF_PATH/libs/core")
  fi
  
  if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo -e "${RED}ERROR: Installation incomplete. Missing files:${NC}"
    for file in "${missing_files[@]}"; do
      echo -e "${RED}  - $file${NC}"
    done
    exit 1
  fi
  
  echo -e "${GREEN}SUCCESS: All required files present${NC}"
}

setup_config() {
  echo ""
  echo -e "${BLUE}Setting up configuration...${NC}"
  
  # Copy config template if needed
  if [[ ! -f "$CHIEF_CONFIG" ]]; then
    if [[ -f "$CHIEF_PATH/templates/chief_config_template.sh" ]]; then
      cp "$CHIEF_PATH/templates/chief_config_template.sh" "$CHIEF_CONFIG"
      echo -e "${GREEN}SUCCESS: Configuration file created at $CHIEF_CONFIG${NC}"
    else
      echo -e "${RED}ERROR: Template file not found at $CHIEF_PATH/templates/chief_config_template.sh${NC}"
      exit 1
    fi
  else
    echo -e "${YELLOW}INFO: Configuration file already exists at $CHIEF_CONFIG${NC}"
  fi

  # Update config to match the installed branch if not default (skip for local installs)
  if ! $LOCAL_INSTALL && [[ "$CHIEF_INSTALL_GIT_BRANCH" != "main" ]]; then
    echo -e "${CYAN}Updating configuration to track ${CHIEF_INSTALL_GIT_BRANCH} branch...${NC}"
    if grep -q "CHIEF_CFG_UPDATE_BRANCH=" "$CHIEF_CONFIG"; then
      # Update existing setting
      if sed -i.bak "s/CHIEF_CFG_UPDATE_BRANCH=.*/CHIEF_CFG_UPDATE_BRANCH=\"${CHIEF_INSTALL_GIT_BRANCH}\"/" "$CHIEF_CONFIG" 2>/dev/null; then
        rm -f "$CHIEF_CONFIG.bak" 2>/dev/null
        echo -e "${GREEN}SUCCESS: Configuration updated to track ${CHIEF_INSTALL_GIT_BRANCH} branch${NC}"
      else
        echo -e "${YELLOW}WARNING: Could not update branch tracking in config file${NC}"
      fi
    else
      # Add setting if it doesn't exist (for older config files)
      echo "" >> "$CHIEF_CONFIG"
      echo "# Branch tracking configuration (added by installer)" >> "$CHIEF_CONFIG"
      echo "CHIEF_CFG_UPDATE_BRANCH=\"${CHIEF_INSTALL_GIT_BRANCH}\"" >> "$CHIEF_CONFIG"
      echo -e "${GREEN}SUCCESS: Added branch tracking configuration (${CHIEF_INSTALL_GIT_BRANCH})${NC}"
    fi
  elif $LOCAL_INSTALL; then
    echo -e "${CYAN}Local installation: Skipping branch tracking configuration${NC}"
    echo -e "${CYAN}Disconnected environments manage updates manually${NC}"
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
    if ! grep -qxF "$line" "$CHIEF_BASH_PROFILE" 2>/dev/null; then
      if echo "$line" >> "$CHIEF_BASH_PROFILE"; then
        echo -e "${CYAN}  Added: ${YELLOW}$line${NC}"
        ((added_lines++))
      else
        echo -e "${RED}ERROR: Failed to add line to $CHIEF_BASH_PROFILE${NC}"
        exit 1
      fi
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
    if sed -i.bak 's/CHIEF_CFG_PROMPT=false/CHIEF_CFG_PROMPT=true/' "$CHIEF_CONFIG" 2>/dev/null; then
      rm -f "$CHIEF_CONFIG.bak" 2>/dev/null
      echo -e "${GREEN}SUCCESS: Git-aware prompt enabled${NC}"
      echo -e "${CYAN}INFO: The prompt will show branch status and repository information${NC}"
      echo ""
      echo -e "${CYAN}Additional prompt options:${NC}"
      echo -e "${CYAN}  • Enable multi-line prompt: Set CHIEF_CFG_MULTILINE_PROMPT=true in chief.config${NC}"
      echo -e "${CYAN}  • View prompt legend: Run 'chief.git_legend' to see color meanings${NC}"
    else
      echo -e "${RED}ERROR: Failed to update configuration file${NC}"
      exit 1
    fi
  else
    echo -e "${YELLOW}INFO: Git-aware prompt disabled (you can enable it later with chief.config)${NC}"
    echo -e "${CYAN}TIP: When you enable it, use 'chief.git_legend' to learn the prompt colors${NC}"
  fi
}

# Main installation flow
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}        CHIEF INSTALLATION${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Installing Chief files...${NC}"
install_chief

echo -e "${BLUE}Step 2: Setting up configuration...${NC}"
setup_config  

echo -e "${BLUE}Step 3: Configuring prompt...${NC}"
setup_prompt

echo -e "${BLUE}Step 4: Installation complete!${NC}"
print_banner

echo ""
echo -e "${CYAN}INSTALLATION SUMMARY:${NC}"
echo -e "${CYAN}The following changes were made to your system:${NC}"
if $LOCAL_INSTALL; then
  echo -e "${CYAN}  • Copied files from local directory to: ${YELLOW}$CHIEF_PATH${NC}"
else
  echo -e "${CYAN}  • Downloaded Chief files from GitHub to: ${YELLOW}$CHIEF_PATH${NC}"
fi
echo -e "${CYAN}  • Created/updated configuration file: ${YELLOW}$CHIEF_CONFIG${NC}"
if [[ -f "$CHIEF_BASH_PROFILE" ]]; then
  echo -e "${CYAN}  • Added 3 export/source lines to: ${YELLOW}$CHIEF_BASH_PROFILE${NC}"
else
  echo -e "${CYAN}  • Bash profile setup skipped (user choice)${NC}"
fi
echo -e "${CYAN}  • No system-wide changes, no sudo required${NC}"
echo ""
echo -e "${CYAN}NEXT STEPS:${NC}"
echo -e "${CYAN}  1. Restart your terminal (or run: source ~/.bash_profile)${NC}"
echo -e "${CYAN}  2. Run 'chief.config' to customize your settings${NC}"
echo -e "${CYAN}  3. Run 'chief.plugin -?' to learn about plugins${NC}"
echo -e "${CYAN}  4. Try 'chief.help' to explore all available commands${NC}"
if ! $LOCAL_INSTALL && [[ "$CHIEF_INSTALL_GIT_BRANCH" != "main" ]]; then
echo ""
echo -e "${CYAN}BRANCH TRACKING:${NC}"
echo -e "${CYAN}  • Installed from: ${YELLOW}${CHIEF_INSTALL_GIT_BRANCH}${NC} branch"
echo -e "${CYAN}  • Future updates will track: ${YELLOW}${CHIEF_INSTALL_GIT_BRANCH}${NC} branch"
echo -e "${CYAN}  • To switch branches: chief.config_set update_branch <branch_name>${NC}"
elif $LOCAL_INSTALL; then
echo ""
echo -e "${CYAN}DISCONNECTED INSTALLATION:${NC}"
echo -e "${CYAN}  • Installed from local files (no git repository)${NC}"
echo -e "${CYAN}  • Updates must be done manually by replacing files${NC}"
echo -e "${CYAN}  • Auto-update features are disabled for security${NC}"
fi
echo ""
echo -e "${GREEN}Chief installation completed successfully!${NC}"
echo -e "${CYAN}Installation script finished at $(date)${NC}"