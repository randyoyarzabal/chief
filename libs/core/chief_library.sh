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

# Core Chief user functionality such as settings and various helper functions.
# Chief - A Bash-based configuration and management tool for Linux/MacOS
# https://github.com/randyoyarzabal/chief

########################################################################
#             NO USER-SERVICEABLE PARTS BEYOND THIS POINT
# This file is part of the Chief configuration and management tool.
# It is designed to be sourced, not executed directly.
########################################################################

########################################################################
# WARNING: This file is not meant to be edited/configured/used directly. 
# All settings and commands are available via 'chief.*'' commands when 
# "${CHIEF_PATH}/chief.sh" is sourced.
# Use the 'chief.config' command to configure and manage Chief.
########################################################################

# CHIEF DEFAULTS
########################################################################

# Source version and constants from centralized file
source "${CHIEF_PATH}/VERSION"
CHIEF_PLUGINS_CORE="${CHIEF_PATH}/libs/core/plugins"
CHIEF_PLUGIN_SUFFIX="_chief-plugin.sh"
CHIEF_DEFAULT_PLUGINS_TYPE="local" 
CHIEF_DEFAULT_PLUGINS_GIT_BRANCH="main"
CHIEF_DEFAULT_PLUGINS="${HOME}/chief_plugins"
CHIEF_DEFAULT_PLUGIN_TEMPLATE="${CHIEF_PATH}/templates/chief_plugin_template.sh"

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief Library) must be sourced; not executed interactively."
  exit 1
fi

# CORE HELPER FUNCTIONS
########################################################################

# Detect platform
uname_out="$(uname -s)"
case "${uname_out}" in
  Linux*) 
    # Detect Linux distribution from /etc/os-release
    if [[ -f /etc/os-release ]]; then
      # Extract PRETTY_NAME or NAME from os-release
      if grep -q "PRETTY_NAME=" /etc/os-release; then
        PLATFORM=$(grep "PRETTY_NAME=" /etc/os-release | cut -d'"' -f2 | cut -d' ' -f1-2)
      elif grep -q "NAME=" /etc/os-release; then
        PLATFORM=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2 | cut -d' ' -f1-2)
      else
        PLATFORM='Linux'
      fi
    else
      PLATFORM='Linux'
    fi
    ;;
  Darwin*) PLATFORM='MacOS' ;;
  CYGWIN*) PLATFORM='Cygwin' ;;
  MINGW*) PLATFORM='MinGw' ;;
  *) PLATFORM="UNKNOWN:${uname_out}" ;;
esac

#  Note: this only applied to any function/alias starting with "chief."
function __chief_load_file() {
  # Usage: __chief_load_file <source_file>
  # 
  # Developer usage: Sources a file with optional alias substitution
  # - If CHIEF_CFG_ALIAS is set, creates a temporary file with chief.* functions renamed to the alias
  # - Sources both the aliased version and original version to ensure compatibility
  # - Used internally by __chief_load_library() to load configuration and library files
  #
  # Arguments:
  #   source_file - Path to the file to be sourced
  
  #Set default values
  local tmp_lib=$(__chief_get_tmpfile) # Temporary library file.
  local source_file=${1} # File to source

  if [[ -n ${CHIEF_CFG_ALIAS} ]]; then
    # Substitute chief.* with alias if requested
    local alias=$(__chief_lower ${CHIEF_CFG_ALIAS})
    
    # Apply alias to functions
    sed "s/function chief./function $alias./g" ${source_file} >${tmp_lib} # Replace into a temp file.
    sed -i.bak -e "s/alias chief./alias $alias./g" -- "${tmp_lib}" 

    source ${tmp_lib} &> /dev/null # Source the library as its alias and 
    # Suppress output because it will be loaded a second time as "chief.*"

    # Destroy / delete the temp library
    rm -rf ${tmp_lib}
  fi
  # Always source the library as "chief." to ensure all functions are available.
  source ${source_file}
}

function __chief_load_library() {
  # Usage: __chief_load_library [--verbose]
  # 
  # Developer usage: Loads Chief configuration and library files
  # - Sources configuration file first, then the library file
  # - Loads all available plugins from configured plugin directories
  # - Prints verbose output if --verbose flag is provided
  # - Used internally during Chief initialization
  #
  # Options:
  #   --verbose - Display detailed loading information
  
  __chief_load_file ${CHIEF_CONFIG}

  __chief_load_file ${CHIEF_LIBRARY} 

  # Set a default alias if none defined.
  if [[ -n ${CHIEF_CFG_ALIAS} ]]; then
    __chief_print "Chief is aliased as ${CHIEF_CFG_ALIAS}."
  fi

  __chief_load_plugins 'core' "$1"

  if [[ -z ${CHIEF_CFG_PLUGINS_TYPE} ]]; then
    # If not set, default to local plugins.
    CHIEF_CFG_PLUGINS_TYPE=${CHIEF_DEFAULT_PLUGINS_TYPE}
  fi

  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]]; then
    __chief_load_remote_plugins "$1"
  elif [[ ${CHIEF_CFG_PLUGINS_TYPE} == "local" ]]; then
    __chief_load_plugins 'user' "$1"
  fi

  __chief_print "Chief BASH library/environment (re)loaded." "$1"
}

function __chief_print() {
  # Usage: __chief_print <string> [--verbose]
  # 
  # Developer usage: Conditionally prints messages based on verbose setting
  # - Only prints if CHIEF_CFG_VERBOSE is true or --verbose flag is passed
  # - Used internally for debug and status messages
  # - Prevents output clutter when verbose mode is disabled
  #
  # Arguments:
  #   string - Message to print
  # Options:
  #   --verbose - Force printing regardless of CHIEF_CFG_VERBOSE setting  
  if ${CHIEF_CFG_VERBOSE} || [[ "${2}" == '--verbose' ]]; then
    echo "${1}"
  fi
}

function __chief_lower() {
  # Usage: __chief_lower <string>
  # 
  # Developer usage: Converts string to lowercase
  # - Used internally for case-insensitive string operations
  # - Primarily used for alias processing and string normalization
  #
  # Arguments:
  #   string - Text to convert to lowercase
  
  local valStr=$1
  valStr=$(echo $valStr | awk '{print tolower($0)}')
  echo $valStr
}

function __chief_upper() {
  # Usage: __upper <string>
  # 
  # Developer usage: Converts string to uppercase
  # - Used internally for case-insensitive string operations and formatting
  # - Utility function for string manipulation
  #
  # Arguments:
  #   string - Text to convert to uppercase
  
  local valStr=$1
  valStr=$(echo $valStr | awk '{print toupper($0)}')
  echo $valStr
}

function __chief_get_tmpfile() {
  # Usage: __chief_get_tmpfile
  # 
  # Developer usage: Generates a unique temporary file path
  # - Creates platform-specific random filename in /tmp directory
  # - Uses /dev/random on macOS and /dev/urandom on Linux for entropy
  # - Returns absolute path to temporary file (file is not created, just named)
  # - Used internally by __chief_load_file for alias processing
  #
  # Returns:
  #   Absolute path to a unique temporary file
  local tmp_file
  if [[ ${PLATFORM} == "MacOS" ]]; then
    tmp_file="/tmp/._$(cat /dev/random | LC_CTYPE=C tr -dc "[:alpha:]" | fold -w 8 | head -n 1)"
  else
    tmp_file="/tmp/._$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)"
  fi
  echo ${tmp_file}
}

function __chief_this_file() {
  # This is used inside a script like a Chief plugin file.
  # Usage: __chief_edit_file ${BASH_SOURCE[0]}
  # Reference: https://stackoverflow.com/a/9107028
  # 
  # Developer usage: Returns absolute path to the specified file
  # - Resolves relative paths to absolute paths
  # - Used internally for file path resolution in plugins
  # - Particularly useful for determining plugin file locations
  #
  # Arguments:
  #   file - Path to file (can be relative or absolute)
  #
  # Returns:
  #   Absolute path to the specified file
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

# Edit a file and reload into memory if changed.
function __chief_has_vscode() {
  # Usage: __chief_has_vscode
  # 
  # Check if VSCode CLI 'code' binary is available
  # Returns: 0 if available, 1 if not available
  command -v code >/dev/null 2>&1
}

function chief.edit-file() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <file> [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit any file with automatic reload detection and sourcing. Ideal for shell scripts,
configuration files, and any file that needs to be reloaded after editing.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  file           Path to the file to edit (required)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --vscode, -v   Use VSCode editor (requires 'code' command)
  -?, --help     Show this help message

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Automatically detects file changes using timestamps
- Sources/reloads the file if modifications are detected  
- Falls back to vi if preferred editor is unavailable
- Works with any text file type
- Cross-platform compatible (Linux/macOS)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME ~/.bashrc                    # Edit bashrc with default editor
  $FUNCNAME ~/.bashrc --vscode           # Edit bashrc with VSCode
  $FUNCNAME /path/to/script.sh           # Edit any shell script
  $FUNCNAME /etc/hosts                   # Edit system files (with sudo)

${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR}
This is the same auto-reload mechanism used by chief.bash_profile, chief.bashrc, etc.
"

  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if [[ -z "$1" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} File path is required"
    echo -e "${USAGE}"
    return 1
  fi

  local file="$1"
  local editor_option=""
  
  # Parse options
  case "$2" in
    --vscode|-v)
      editor_option="vscode"
      ;;
    "")
      # No option specified, use default
      ;;
    *)
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $2"
      echo -e "${USAGE}"
      return 1
      ;;
  esac

  __chief_edit_file "$file" "$editor_option"
}

# Internal function for file editing (used by public chief.edit-file and other functions)
function __chief_edit_file() {
  # Usage: __chief_edit_file <file> [editor_option] [reload_option]
  # Arguments:
  #   file - Path to the file to edit
  #   editor_option - Optional: 'vscode' to use VSCode, otherwise uses default editor
  #   reload_option - Optional: 'reload' to reload entire Chief library instead of just the file
  local file=${1}
  local editor_option=${2}
  local date1
  local date2
  
  # Choose editor based on option and availability
  local editor_cmd="vi"  # default editor
  if [[ "$editor_option" == "vscode" ]]; then
    if __chief_has_vscode; then
      editor_cmd="code --wait"
    else
      echo -e "${CHIEF_COLOR_YELLOW}Warning: VSCode 'code' command not found. Falling back to vi editor.${CHIEF_NO_COLOR}"
      editor_cmd="vi"
    fi
  fi
  
  if [[ ${PLATFORM} == "MacOS" ]]; then
    date1=$(stat -L -f "%Sm" -t "%Y%m%dT%H%M%S" "$file")
    ${editor_cmd} ${file}
    date2=$(stat -L -f "%Sm" -t "%Y%m%dT%H%M%S" "$file")
  else
    date1=$(stat -L -c %y "$file")
    ${editor_cmd} ${file}
    date2=$(stat -L -c %y "$file")
  fi

  # Check if the file was actually modified before reloading
  if [[ ${date2} != ${date1} ]]; then
    if [[ -z $3 ]]; then
      __chief_load_file ${file}
    else
      if [[ $3 == 'reload' ]]; then
        __chief_load_library --verbose  
      fi
    fi

    if [[ -z ${2} ]]; then
      echo "${file##*/} file was modified, therefore, reloaded."
    else
      echo "${2} was modified, therefore, reloaded."
    fi
    return 0 # Changes were made to the file.
  else
    return 1 # No changes made to the file.
  fi
}

# Helper function to check for local changes in plugins directory
__chief_check_plugins_local_changes() {
  # Check if plugins directory is a git repository and has local changes
  if [[ -d ${CHIEF_CFG_PLUGINS_PATH}/.git ]]; then
    cd "${CHIEF_CFG_PLUGINS_PATH}"
    local has_changes=$(git status -s)
    cd - > /dev/null 2>&1
    if [[ -n "$has_changes" ]]; then
      return 0  # Has local changes
    fi
  fi
  return 1  # No local changes or not a git repo
}

# Helper function to validate git repository access without cloning
__chief_validate_git_access() {
  # Usage: __chief_validate_git_access <repo_url> [branch]
  # Returns: 0 if access is valid, 1 if access fails
  local repo_url="$1"
  local branch="${2:-main}"
  
  if [[ -z "$repo_url" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error: Repository URL is required for git access validation.${CHIEF_NO_COLOR}"
    return 1
  fi
  
  # Test git access by doing a lightweight ls-remote operation
  echo "Testing git access to repository..."
  if git ls-remote --heads "$repo_url" "$branch" >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_GREEN}✓ Git repository access validated successfully.${CHIEF_NO_COLOR}"
    return 0
  else
    echo -e "${CHIEF_COLOR_RED}✗ Failed to access git repository: $repo_url${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_YELLOW}This could be due to:${CHIEF_NO_COLOR}"
    echo -e "  - Invalid repository URL"
    echo -e "  - Network connectivity issues"
    echo -e "  - Authentication/permission problems"
    echo -e "  - Repository does not exist or branch '$branch' not found"
    return 1
  fi
}

# Helper function to backup existing local plugins directory
__chief_backup_local_plugins() {
  # Usage: __chief_backup_local_plugins <plugins_path>
  local plugins_path="$1"
  
  if [[ -z "$plugins_path" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error: Plugins path is required for backup.${CHIEF_NO_COLOR}"
    return 1
  fi
  
  if [[ ! -d "$plugins_path" ]]; then
    # Directory doesn't exist, nothing to backup
    return 0
  fi
  
  # Check if it's a git repository
  if [[ -d "$plugins_path/.git" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Existing git repository detected at: $plugins_path${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_YELLOW}This directory will be replaced with the remote repository.${CHIEF_NO_COLOR}"
    return 0
  fi
  
  # Check if directory has any files
  if [[ -n "$(ls -A "$plugins_path" 2>/dev/null)" ]]; then
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="${plugins_path}_backup_${timestamp}"
    
    echo -e "${CHIEF_COLOR_YELLOW}Local plugins directory exists and contains files.${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_BLUE}Creating backup: $backup_path${CHIEF_NO_COLOR}"
    
    if mv "$plugins_path" "$backup_path"; then
      echo -e "${CHIEF_COLOR_GREEN}✓ Local plugins backed up successfully to: $backup_path${CHIEF_NO_COLOR}"
      return 0
    else
      echo -e "${CHIEF_COLOR_RED}✗ Failed to backup local plugins directory.${CHIEF_NO_COLOR}"
      return 1
    fi
  fi
  
  # Directory exists but is empty, safe to remove
  rmdir "$plugins_path" 2>/dev/null || true
  return 0
}

__chief_load_remote_plugins() {
  # Usage: __chief_load_remote_plugins [--verbose] [--force] [--explicit]
  # 
  # Developer usage: Loads remote plugins from a git repository
  # - Checks if autoupdate is enabled or --force flag is provided
  # - Checks for local changes and warns user if autoupdate is enabled
  # - Prompts user to update if plugins directory is empty/doesn't exist
  # - Clones/updates git repository if necessary
  # - Loads plugins from the git repository
  #
  # Options:
  #   --verbose - Display detailed loading information
  #   --force - Force update of plugins
  #   --explicit - Explicit user request (always update regardless of CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE)
  
  local good_to_load=false
  local skip_autoupdate=false
  local explicit_request=false
  
  # Check for explicit request flag
  for arg in "$@"; do
    if [[ "$arg" == "--explicit" ]]; then
      explicit_request=true
      break
    fi
  done
  
  # Check for local changes when autoupdate is enabled (but not when --force is used)
  if ${CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE} && [[ "$2" != "--force" ]] && __chief_check_plugins_local_changes; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Local changes detected in plugins directory: ${CHIEF_CFG_PLUGINS_PATH}"
    echo -e "${CHIEF_COLOR_CYAN}Local changes found in plugins directory. Auto-update is enabled but would overwrite your changes.${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}"
    echo -e "  ${CHIEF_COLOR_GREEN}1.${CHIEF_NO_COLOR} Commit and push your changes first, then restart Chief"
    echo -e "  ${CHIEF_COLOR_GREEN}2.${CHIEF_NO_COLOR} Temporarily disable auto-update to keep your changes"
    echo -e "  ${CHIEF_COLOR_GREEN}3.${CHIEF_NO_COLOR} Force update anyway (${CHIEF_COLOR_RED}WILL LOSE YOUR CHANGES${CHIEF_NO_COLOR})"
    echo
    
    if chief.etc_ask-yes-or-no "Temporarily disable PLUGINS_GIT_AUTOUPDATE to preserve your local changes?"; then
      skip_autoupdate=true
      echo -e "${CHIEF_COLOR_YELLOW}Auto-update disabled for this session. Your local changes are safe.${CHIEF_NO_COLOR}"
      echo -e "${CHIEF_COLOR_CYAN}To commit your changes: cd ${CHIEF_CFG_PLUGINS_PATH} && git add . && git commit -m 'your message' && git push${CHIEF_NO_COLOR}"
      echo -e "${CHIEF_COLOR_CYAN}To permanently enable auto-update again: set CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=true in your config${CHIEF_NO_COLOR}"
    else
      if chief.etc_ask-yes-or-no "Force update anyway? This will ${CHIEF_COLOR_RED}DISCARD ALL LOCAL CHANGES${CHIEF_NO_COLOR}!"; then
        good_to_load=true
        echo -e "${CHIEF_COLOR_YELLOW}Proceeding with force update. Local changes will be lost.${CHIEF_NO_COLOR}"
      else
        skip_autoupdate=true
        echo -e "${CHIEF_COLOR_GREEN}Update cancelled. Your local changes are preserved.${CHIEF_NO_COLOR}"
        echo -e "${CHIEF_COLOR_CYAN}Please handle your local changes manually and restart Chief when ready.${CHIEF_NO_COLOR}"
      fi
    fi
  fi
  
  # If autoupdate is enabled and not skipped, or --force was used, or explicit request.
  if ! $skip_autoupdate && (${CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE} || [[ "$2" == "--force" ]] || $explicit_request); then
    good_to_load=true
  # If the git path isn't set Or path doesn't exist Or it is empty.
  elif [[ -z ${CHIEF_CFG_PLUGINS_PATH} ]] || [[ ! -d ${CHIEF_CFG_PLUGINS_PATH} ]] || [[ -z "$(ls -A ${CHIEF_CFG_PLUGINS_PATH})" ]]; then
    if chief.etc_ask-yes-or-no "Your Chief plugins directory is empty/doesn't exist, do you want to run the update now?
You can run 'chief.plugins_update' anytime or set CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=true"; then
      good_to_load=true
    fi  
  fi

  if ${good_to_load}; then
    echo "Configured values:
CHIEF_CFG_PLUGINS_GIT_REPO=${CHIEF_CFG_PLUGINS_GIT_REPO}
CHIEF_CFG_PLUGINS_GIT_BRANCH=${CHIEF_CFG_PLUGINS_GIT_BRANCH}
CHIEF_CFG_PLUGINS_PATH=${CHIEF_CFG_PLUGINS_PATH}
CHIEF_CFG_PLUGINS_GIT_PATH=${CHIEF_CFG_PLUGINS_GIT_PATH}"

    # Check if git is installed.
    if ! command -v git &> /dev/null; then
      echo -e "${CHIEF_COLOR_RED}Error: git is not installed. Please install git to use remote plugins.${CHIEF_NO_COLOR}"
      return 1
    fi

    # Check if a git branch is defined, if not, set to default.
    if [[ -z ${CHIEF_CFG_PLUGINS_GIT_BRANCH} ]]; then
      CHIEF_CFG_PLUGINS_GIT_BRANCH=${CHIEF_DEFAULT_PLUGINS_GIT_BRANCH}
    fi

    # Validate git repository access BEFORE creating any directories or modifying filesystem
    if ! __chief_validate_git_access "${CHIEF_CFG_PLUGINS_GIT_REPO}" "${CHIEF_CFG_PLUGINS_GIT_BRANCH}"; then
      echo -e "${CHIEF_COLOR_RED}Aborting plugins update due to git access failure.${CHIEF_NO_COLOR}"
      echo -e "${CHIEF_COLOR_CYAN}Please check your repository URL, network connection, and authentication.${CHIEF_NO_COLOR}"
      return 1
    fi

    # Check if the git repository exists, if not, clone it.
    if [[ ! -d ${CHIEF_CFG_PLUGINS_PATH}/.git ]]; then
      # Handle existing local plugins directory by backing it up
      if ! __chief_backup_local_plugins "${CHIEF_CFG_PLUGINS_PATH}"; then
        echo -e "${CHIEF_COLOR_RED}Failed to backup existing plugins directory. Aborting.${CHIEF_NO_COLOR}"
        return 1
      fi
      
      # Now create the directory (only after validation and backup)
      if [[ ! -d ${CHIEF_CFG_PLUGINS_PATH} ]]; then
        mkdir -p ${CHIEF_CFG_PLUGINS_PATH} || {
          echo -e "${CHIEF_COLOR_RED}Error: Unable to create directory '${CHIEF_CFG_PLUGINS_PATH}'.${CHIEF_NO_COLOR}"
          return 1
        }
      fi
      
      echo "Cloning remote plugins repository..."
      git clone --branch ${CHIEF_CFG_PLUGINS_GIT_BRANCH} ${CHIEF_CFG_PLUGINS_GIT_REPO} ${CHIEF_CFG_PLUGINS_PATH}
    else
      echo "Updating remote plugins repository..."
      cd "${CHIEF_CFG_PLUGINS_PATH}"
      
      # If force update was chosen, reset local changes first
      if [[ "$2" == "--force" ]] || [[ "$good_to_load" == "true" ]] && __chief_check_plugins_local_changes; then
        echo -e "${CHIEF_COLOR_YELLOW}Resetting local changes...${CHIEF_NO_COLOR}"
        git reset --hard HEAD
        git clean -fd
      fi
      
      # Check if local branch is different from $CHIEF_CFG_PLUGINS_GIT_BRANCH
      local current_branch=$(git rev-parse --abbrev-ref HEAD)
      if [[ ${current_branch} != ${CHIEF_CFG_PLUGINS_GIT_BRANCH} ]]; then
        echo "Switching to branch: ${CHIEF_CFG_PLUGINS_GIT_BRANCH}"
        git checkout ${CHIEF_CFG_PLUGINS_GIT_BRANCH}
      fi
      git pull origin ${CHIEF_CFG_PLUGINS_GIT_BRANCH}
      cd - > /dev/null 2>&1
    fi
  else
    # Check if plugins directory is empty.
    # Only show warning when verbose is enabled and hints are disabled
    if [[ $(__chief_get_plugins) == "" ]] && ! ${CHIEF_CFG_HINTS} && ${CHIEF_CFG_VERBOSE}; then
      echo -e "${CHIEF_COLOR_YELLOW}Warning: Remote plugins are not set to auto-update (CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=false). Run ${CHIEF_COLOR_CYAN}chief.plugins_update${CHIEF_COLOR_YELLOW} to update.${CHIEF_NO_COLOR}"
    fi
  fi
  # Check for team vault file in plugins repository
  local vault_path
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" && -n ${CHIEF_CFG_PLUGINS_GIT_PATH} ]]; then
    vault_path="${CHIEF_CFG_PLUGINS_PATH}/${CHIEF_CFG_PLUGINS_GIT_PATH}/.chief_shared-vault"
  else
    vault_path="${CHIEF_CFG_PLUGINS_PATH}/.chief_shared-vault"
  fi
  
  if [[ -f "$vault_path" ]]; then
    export CHIEF_SECRETS_FILE="$vault_path"
    __chief_print "Found vault file: $vault_path" "$1"
    __chief_print "Use 'chief.vault_file-load' to load portable secrets" "$1"
  fi

  # Load plugins from the remote repository.
  __chief_load_plugins 'user' "$1"
}

# Source the library/plugin module passed.
function __chief_load_plugins() {
  # Usage: __chief_load_plugins <plug-in module> (user/core) 
  # 
  # Developer usage: Loads plugins from the user or core directory
  # - Checks if the plugin module is valid
  # - Sets the directory path based on the module
  # - Loads plugins from the directory
  #
  # Arguments:
  #   module - The plugin module to load (user/core)
  #
  # Options:
  #   --verbose - Display detailed loading information
  __chief_print "Loading Chief ${1}-plugins..." "$2"

  local plugin_file
  local plugin_name
  local dir_path
  local load_flag

  load_flag=false # Default to false, unless plugin switch is defined.
  if [[ $1 == 'core' ]]; then
    dir_path=${CHIEF_PLUGINS_CORE}
    load_flag=true
  elif [[ $1 == 'user' ]]; then
    # For local plugins, use CHIEF_CFG_PLUGINS_PATH directly
    # For remote plugins, use CHIEF_CFG_PLUGINS_PATH + CHIEF_CFG_PLUGINS_GIT_PATH (if set)
    if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" && -n ${CHIEF_CFG_PLUGINS_GIT_PATH} ]]; then
      dir_path="${CHIEF_CFG_PLUGINS_PATH}/${CHIEF_CFG_PLUGINS_GIT_PATH}"
    else
      dir_path=${CHIEF_CFG_PLUGINS_PATH}
    fi
    if [[ -n ${CHIEF_CFG_PLUGINS_PATH} ]]; then
      load_flag=true
    fi
  else
    __chief_print "   plugins: ${1} is not a valid plug-in module." "$2"
    return 1
  fi

  local plugins=() # Array to hold plugin names
  local sorted_plugins=() # Array to hold sorted plugin names
  if ! ${load_flag}; then
    __chief_print "   plugins: ${1} not enabled." "$2"
  else
    # Check for existence of plugin folder requested
    if [[ -d ${dir_path} ]]; then
      for plugin in "${dir_path}/"*"${CHIEF_PLUGIN_SUFFIX}"; do
        plugins+=("${plugin}") # Collect plugin names
      done

      # Sort the plugins alphabetically
      sorted_plugins=($(printf '%s\n' "${plugins[@]}"|sort))

      # Loop through sorted plugins and print them
      for plugin in "${sorted_plugins[@]}"; do
        plugin_file=${plugin##*/}
        plugin_name=${plugin_file%%_*}

        if [[ -f ${plugin} ]]; then
          __chief_load_file "${plugin}" # Apply alias and source the plugin
          __chief_print "   plugin: ${plugin_name} loaded." "$2"
        fi
      done
    else
      __chief_print "   $1 plugins directory does not exist." "$2"
    fi
  fi
}

__chief_get_plugins() {
  # Usage: __chief_get_plugins
  # 
  # Developer usage: Generates a list of plugins as a string separated by '|'
  # - Used internally to display the list of plugins in the banner, hints, and chief.plugin help text
  # - Accounts for new plugins that are created once the terminal is already started
  #
  # Returns:
  #   A string of plugin names separated by '|'
  local plugin_file
  local plugin_name
  local dir_path
  local plugin_list_str

  # Use same logic as __chief_load_plugins for consistency
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" && -n ${CHIEF_CFG_PLUGINS_GIT_PATH} ]]; then
    dir_path="${CHIEF_CFG_PLUGINS_PATH}/${CHIEF_CFG_PLUGINS_GIT_PATH}"
  else
    dir_path=${CHIEF_CFG_PLUGINS_PATH}
  fi

  local plugins=() # Array to hold plugin names
  local sorted_plugins=() # Array to hold sorted plugin names

  if [[ -d ${dir_path} ]]; then
    for plugin in "${dir_path}/"*"${CHIEF_PLUGIN_SUFFIX}"; do
      plugins+=("${plugin}") # Collect plugin names
    done

    # Sort the plugins alphabetically
    sorted_plugins=($(printf '%s\n' "${plugins[@]}"|sort))

    # Loop through sorted plugins and print them
    for plugin in "${sorted_plugins[@]}"; do
      plugin_file=${plugin##*/}
      plugin_name=${plugin_file%%_*}
      plugin_list_str="$plugin_list_str|$plugin_name" # Append plugin name
    done
    plugin_list_str=$(echo ${plugin_list_str#?}) # Trim first character
  fi
  echo "${plugin_list_str}" # Return the plugin list string
}

# Edit a plugin file and reload into memory if changed.
#   Note, will only succeed if plug-in is enabled in settings.
# Usage: __chief_edit_plugin <plug-in name>
function __chief_edit_plugin() {
  # Usage: __chief_edit_plugin <plugin_name> [editor_option]
  # Arguments:
  #   plugin_name - Name of the plugin to edit
  #   editor_option - Optional: 'vscode' to use VSCode, otherwise uses default editor
  local plugin_name
  local plugin_file
  local editor_option=${2}

  # Check if plugins are enabled.
  if [[ -z ${CHIEF_CFG_PLUGINS_PATH} ]]; then
    echo "Chief plugins are not enabled."
    return
  fi

  plugin_name=$(__chief_lower ${1})
  # Use same logic as __chief_load_plugins for consistency
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" && -n ${CHIEF_CFG_PLUGINS_GIT_PATH} ]]; then
    plugin_file="${CHIEF_CFG_PLUGINS_PATH}/${CHIEF_CFG_PLUGINS_GIT_PATH}/${plugin_name}${CHIEF_PLUGIN_SUFFIX}"
  else
    plugin_file="${CHIEF_CFG_PLUGINS_PATH}/${plugin_name}${CHIEF_PLUGIN_SUFFIX}"
  fi

  # Check if the plugin file exists, if not, prompt to create it.
  if [[ -f ${plugin_file} ]]; then
    __chief_edit_file ${plugin_file} ${editor_option}
  else
    echo "Chief plugin: ${plugin_name} plugin file does not exist."
    if ! chief.etc_ask-yes-or-no "Create it?"; then
      echo -e "${CHIEF_COLOR_YELLOW}Plugin file not created.${CHIEF_NO_COLOR}"
      return 1
    fi

    # Get the plugin template file
    if [[ -z ${CHIEF_CFG_PLUGIN_TEMPLATE} ]] || [[ ! -f ${CHIEF_CFG_PLUGIN_TEMPLATE} ]]; then
      echo -e "${CHIEF_COLOR_RED}Chief plugin template not defined or does not exist. Using default template.${CHIEF_NO_COLOR}"
      CHIEF_CFG_PLUGIN_TEMPLATE=${CHIEF_DEFAULT_PLUGIN_TEMPLATE}
    fi

    # Check if a plugin directory is defined, if not, set to default.
    if [[ -z ${CHIEF_CFG_PLUGINS_PATH} ]]; then
      CHIEF_CFG_PLUGINS_PATH=${CHIEF_DEFAULT_PLUGINS}
    fi

    # Create the plugins directory if it does not exist.
    if [[ ! -d ${CHIEF_CFG_PLUGINS_PATH} ]]; then
      mkdir -p ${CHIEF_CFG_PLUGINS_PATH} || {
        echo -e "${CHIEF_COLOR_RED}Error: Unable to create directory '${CHIEF_CFG_PLUGINS_PATH}'.${CHIEF_NO_COLOR}"
        return 1
      }
    fi

    # Copy the template to the plugin file
    cp ${CHIEF_CFG_PLUGIN_TEMPLATE} ${plugin_file} || {
      echo -e "${CHIEF_COLOR_RED}Error: Unable to create '${plugin_file}'.${CHIEF_NO_COLOR}"
      return 1
    }

    # Replace the plugin name in the template
    # Portable sed usage; reference: https://unix.stackexchange.com/a/381201
    sed -i.bak -e "s/\$CHIEF_PLUGIN_NAME/${plugin_name}/g" -- "${plugin_file}" && rm -rf "${plugin_file}.bak"
    #sed -i "s/\$CHIEF_PLUGIN_NAME/${plugin_name}/g" ${plugin_file}
    __chief_edit_file ${plugin_file} ${editor_option}
  fi
}

# Display Chief banner
function __chief.banner {
  local git_status
  local alias_status
  local branch_status

  if [[ -n $CHIEF_CFG_ALIAS ]]; then
    alias_status="alias: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_ALIAS}"
  else
    alias_status=""
  fi

  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]]; then
    if $CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE; then
      git_status="plugins: ${CHIEF_COLOR_CYAN}git [auto-update ${CHIEF_COLOR_GREEN}enabled]"
    else
      git_status="plugins: ${CHIEF_COLOR_CYAN}git [auto-update ${CHIEF_COLOR_RED}disabled]"
    fi
  else
    git_status="plugins: ${CHIEF_COLOR_CYAN}local${CHIEF_NO_COLOR}"
  fi

  # Show which branch is being tracked for updates
  local update_branch="${CHIEF_CFG_UPDATE_BRANCH:-main}"
  if [[ "${update_branch}" == "dev" ]]; then
    branch_status="tracking: ${CHIEF_COLOR_YELLOW}${update_branch} ${CHIEF_COLOR_RED}(bleeding-edge)${CHIEF_NO_COLOR}"
  elif [[ "${update_branch}" == "main" ]]; then
    branch_status="tracking: ${CHIEF_COLOR_GREEN}${update_branch} ${CHIEF_COLOR_CYAN}(stable)${CHIEF_NO_COLOR}"
  else
    branch_status="tracking: ${CHIEF_COLOR_CYAN}${update_branch} ${CHIEF_COLOR_YELLOW}(custom)${CHIEF_NO_COLOR}"
  fi

  echo -e "${CHIEF_COLOR_YELLOW}        __    _      ____${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}  _____/ /_  (_)__  / __/ ${alias_status}${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW} / ___/ __ \/ / _ \/ /_  ${git_status}${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}/ /__/ / / / /  __/ __/ ${branch_status}${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}\___/_/ /_/_/\___/_/ ${CHIEF_NO_COLOR}${CHIEF_VERSION} [${PLATFORM}]"
}

# Display "hints" text and dynamically display alias if necessary.
function __chief.hints_text() {
  # Usage: __chief.hints_text [--verbose] [--no-tracking]
  local show_tracking=true
  local show_hints=false
  
  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --verbose)
        show_hints=true
        ;;
      --no-tracking)
        show_tracking=false
        ;;
    esac
  done
  
  if ${CHIEF_CFG_HINTS} || $show_hints; then
    # If plugins are not set to auto-update, display a message.
    if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]] && ! ${CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE}; then   
      echo -e "${CHIEF_COLOR_GREEN}chief.[tab]${CHIEF_NO_COLOR} for available commands."
      echo -e "${CHIEF_COLOR_GREEN}chief.plugins_update${CHIEF_NO_COLOR} to update/load plugins. | ${CHIEF_COLOR_GREEN}chief.update${CHIEF_NO_COLOR} to update Chief."
    else
      echo -e "${CHIEF_COLOR_GREEN}chief.[tab]${CHIEF_NO_COLOR} for available commands. | ${CHIEF_COLOR_GREEN}chief.update${CHIEF_NO_COLOR} to update Chief.${CHIEF_NO_COLOR}"
    fi
    local plugin_list=$(__chief_get_plugins)
    if [[ ${plugin_list} != "" ]]; then
      echo -e "${CHIEF_COLOR_GREEN}Plugins loaded: ${CHIEF_COLOR_CYAN}${plugin_list}${CHIEF_NO_COLOR}"
    fi
    # Show branch tracking status (only if not already shown in banner)
    if $show_tracking; then
      local update_branch="${CHIEF_CFG_UPDATE_BRANCH:-main}"
      if [[ "${update_branch}" == "dev" ]]; then
        echo -e "${CHIEF_COLOR_CYAN}Tracking: ${CHIEF_COLOR_YELLOW}${update_branch}${CHIEF_COLOR_RED} (bleeding-edge)${CHIEF_COLOR_CYAN} branch | ${CHIEF_COLOR_GREEN}chief.config_set update_branch main${CHIEF_COLOR_CYAN} for stable${CHIEF_NO_COLOR}"
      elif [[ "${update_branch}" == "main" ]]; then
        echo -e "${CHIEF_COLOR_CYAN}Tracking: ${CHIEF_COLOR_GREEN}${update_branch}${CHIEF_COLOR_CYAN} (stable) branch | ${CHIEF_COLOR_GREEN}chief.config_set update_branch dev${CHIEF_COLOR_CYAN} for latest features${CHIEF_NO_COLOR}"
      else
        echo -e "${CHIEF_COLOR_CYAN}Tracking: ${CHIEF_COLOR_CYAN}${update_branch}${CHIEF_COLOR_YELLOW} (custom)${CHIEF_COLOR_CYAN} branch | ${CHIEF_COLOR_GREEN}chief.config_set update_branch main${CHIEF_COLOR_CYAN} for stable${CHIEF_NO_COLOR}"
      fi
    fi
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Essential Commands:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR} to edit configuration file | ${CHIEF_COLOR_GREEN}chief.config_set <option> <value>${CHIEF_NO_COLOR} to set config directly
    - ${CHIEF_COLOR_GREEN}chief.config_update${CHIEF_NO_COLOR} to update config with new template options"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.help${CHIEF_NO_COLOR} for comprehensive help | ${CHIEF_COLOR_GREEN}chief.help --compact${CHIEF_NO_COLOR} for quick reference"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.whereis <name>${CHIEF_NO_COLOR} to find any function/alias location"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.vault_*${CHIEF_NO_COLOR} to encrypt/decrypt secrets (requires ansible-vault)"
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Quick Customization:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config_set prompt true${CHIEF_NO_COLOR} for git-aware prompt | ${CHIEF_COLOR_GREEN}chief.git_legend${CHIEF_NO_COLOR} for colors"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config_set multiline_prompt true${CHIEF_NO_COLOR} for multi-line prompt"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config_set short_path true${CHIEF_NO_COLOR} for compact directory paths"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config_set --list${CHIEF_NO_COLOR} to see all available configuration options"
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Plugin Management:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugin [name]${CHIEF_NO_COLOR} to create/edit plugins | ${CHIEF_COLOR_GREEN}chief.plugin -?${CHIEF_NO_COLOR} to list"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugins_root${CHIEF_NO_COLOR} to navigate to plugins directory"
    echo ""
    if [[ ${1} != '--verbose' ]]; then
      echo -e "${CHIEF_COLOR_CYAN}** Run ${CHIEF_COLOR_GREEN}chief.config_set hints=false${CHIEF_COLOR_CYAN} to disable these hints. **${CHIEF_NO_COLOR}"
      echo ""
    fi
  else
    echo ""
  fi
}

# Display compact Chief hints and tips
function chief.hints() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--no-banner]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Display compact Chief tips, hints, and quick command reference.
Shows banner by default unless --no-banner is specified.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --no-banner    Skip showing Chief banner

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Quick command overview
- Plugin status and suggestions
- Configuration tips
- Essential workflow commands

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Show banner with hints
  $FUNCNAME --no-banner       # Show hints without banner
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  # Show banner by default unless --no-banner is specified
  if [[ $1 != "--no-banner" ]]; then
    __chief.banner
    __chief.hints_text --verbose --no-tracking
  else
    __chief.hints_text --verbose
  fi
}

# Comprehensive Chief help system
function chief.help() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [category] [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Display Chief help information, commands, and usage examples.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  category    Help category: commands, plugins, config, search (optional)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --compact, -c   Show compact command reference
  --search <term> Search for specific commands or topics
  -?, --help      Show this help

${CHIEF_COLOR_GREEN}Categories:${CHIEF_NO_COLOR}
  commands    Core Chief commands and usage
  plugins     Plugin management and available plugins  
  config      Configuration options and setup
  search      Search through available functions

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Show full help with banner
  $FUNCNAME commands          # Show only core commands
  $FUNCNAME plugins           # Show plugin information
  $FUNCNAME config            # Show configuration help
  $FUNCNAME --compact         # Compact command reference
  $FUNCNAME --search git      # Search for git-related commands
"

  if [[ $1 == "-?" ]] || [[ $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return
  fi

  case "${1:-full}" in
    commands|cmd)
      __chief_show_core_commands
      ;;
    plugins|plug)
      __chief_show_plugin_help
      ;;
    config|cfg)
      __chief_show_configuration_help
      ;;
    search)
      __chief_search_help "$2"
      ;;
    --compact|-c)
      __chief_show_compact_reference
      ;;
    --search)
      __chief_search_help "$2"
      ;;
    full|*)
      __chief.banner
      echo
      __chief_show_chief_stats
      echo
      echo -e "${CHIEF_COLOR_YELLOW}Available help categories:${CHIEF_NO_COLOR}"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.help commands${CHIEF_NO_COLOR}  - Core commands and usage"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.help plugins${CHIEF_NO_COLOR}   - Plugin management"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.help config${CHIEF_NO_COLOR}    - Configuration options"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.help --compact${CHIEF_NO_COLOR} - Quick reference"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.hints${CHIEF_NO_COLOR}          - Quick tips and workflow"
      echo
      echo -e "${CHIEF_COLOR_CYAN}Quick start: ${CHIEF_COLOR_GREEN}chief.[tab][tab]${CHIEF_NO_COLOR} to see all commands"
      echo
      echo -e "${CHIEF_COLOR_YELLOW}🐛 Bug Reports & Issues:${CHIEF_NO_COLOR}"
      echo -e "Found a bug or need help? Please create an issue on GitHub:"
      echo -e "• ${CHIEF_COLOR_CYAN}${CHIEF_REPO}/issues${CHIEF_NO_COLOR}"
      echo -e "• Include your OS version: ${CHIEF_COLOR_GREEN}$(uname -s) $(uname -r)${CHIEF_NO_COLOR}"
      echo -e "• Provide steps to reproduce the issue"
      echo -e "• Include relevant error messages and Chief version: ${CHIEF_COLOR_GREEN}${CHIEF_VERSION}${CHIEF_NO_COLOR}"
      ;;
  esac
}

# Display Chief version info.
function __chief.info() {
  # Usage: __chief.info
  __chief.banner
  echo -e "${CHIEF_COLOR_CYAN}${CHIEF_REPO}${CHIEF_NO_COLOR}"
}

# Start SSH agent
function __chief_start_agent {
  # Usage: __chief_start_agent
  __chief_print "Initializing new SSH agent..."
  (
    umask 066
    /usr/bin/ssh-agent >"${SSH_ENV}"
  )
  . "${SSH_ENV}" >/dev/null
}

function __chief_load_ssh_keys() {
    __chief_print "Loading SSH keys from: ${CHIEF_CFG_SSH_KEYS_PATH}..." "$1"

  if [[ ${PLATFORM} == "MacOS" ]]; then
    load="/usr/bin/ssh-add --apple-use-keychain"
  elif [[ ${PLATFORM} == "Linux" ]]; then
    # This will load ssh-agent (only if needed) just once and will only be reloaded on reboot.
    load="/usr/bin/ssh-add"
    SSH_ENV="$HOME/.ssh/environment"

    if [[ -f "${SSH_ENV}" ]]; then
      . "${SSH_ENV}" >/dev/null
      ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ >/dev/null || {
        __chief_start_agent
      }
    else
      __chief_start_agent
    fi
  fi

  # Load all keys with .key extension (supports RSA, ed25519, etc.)
  # Users can symlink existing keys with .key extension for selective loading
  for ssh_key in ${CHIEF_CFG_SSH_KEYS_PATH}/*.key; do
    if ${CHIEF_CFG_VERBOSE} || [[ "${1}" == '--verbose' ]]; then
      ${load} ${ssh_key}
    else
      ${load} ${ssh_key} &> /dev/null
    fi
  done

  # Load key from standard location
  # if [[ -e ~/.ssh/id_rsa ]]; then
  #   if ${CHIEF_CFG_VERBOSE}; then
  #     ${load} ~/.ssh/id_rsa
  #   else
  #     ${load} ~/.ssh/id_rsa &> /dev/null
  #   fi
  # fi
}

# Build Git / VirtualEnv prompt
function __chief_build_git_prompt() {
  # Usage: PROMPT_COMMAND='__chief_build_git_prompt'
  # Needed because PROMPT_COMMAND doesn't 'echo -e' and this also fixes the nasty
  # wrapping bug when the prompt is colorized and a VE is activated.
  # Note: Using \[ \] sequences for non-printing characters in prompts
  local P_BLUE='\[\033[0;34m\]'
  local P_CYAN='\[\033[0;36m\]'
  local P_GREEN='\[\033[0;32m\]'
  local P_MAGENTA='\[\033[0;35m\]'
  local P_YELLOW='\[\033[1;33m\]'
  local P_NO_COLOR='\[\033[0m\]'

  local ve_name=''
  if [[ ! -z ${VIRTUAL_ENV} ]]; then
    if ${CHIEF_CFG_COLORED_PROMPT}; then
      ve_name="(${P_BLUE}${VIRTUAL_ENV##*/}${P_NO_COLOR}) "
    else
      ve_name="(${VIRTUAL_ENV##*/}) "
    fi
  fi

  # If CHIEF_HOST is set, use it in the prompt
  if [[ -n ${CHIEF_HOST} ]]; then
    host="${CHIEF_HOST}"
  else
    host=$(hostname -s)  # Short hostname
  fi

  # Build the base prompt parts
  local user_host="\u@${host}"
  local path_part="${prompt_tag:-\w}"
  
  if ${CHIEF_CFG_COLORED_PROMPT}; then
    user_host="${P_MAGENTA}\u${P_NO_COLOR}@${P_GREEN}${host}${P_NO_COLOR}"
    path_part="${P_YELLOW}${prompt_tag:-\w}${P_NO_COLOR}"
  fi

  # Check if multi-line prompt is enabled
  if ${CHIEF_CFG_MULTILINE_PROMPT:-false}; then
    # Multi-line prompt: info on first line, prompt on second line
    if ${CHIEF_CFG_COLORED_PROMPT}; then
      __git_ps1 "${ve_name}${user_host}:${path_part}" "\n\\\$ "
    else
      __git_ps1 "${ve_name}${user_host}:${path_part}" "\n\\\$ "
    fi
  else
    # Single-line prompt (original behavior)
    if ${CHIEF_CFG_COLORED_PROMPT}; then
      __git_ps1 "${ve_name}${user_host}:${path_part}" "\\\$ "
    else
      __git_ps1 "${ve_name}${user_host}:${path_part}" "\\\$ "
    fi
  fi
}

function __chief_check_for_updates (){
  cd ${CHIEF_PATH}
  local CHANGE_MSG="${CHIEF_COLOR_GREEN}**Chief updates available**${CHIEF_NO_COLOR}"

  # Get target branch from config, default to main if not set
  local TARGET_BRANCH="${CHIEF_CFG_UPDATE_BRANCH:-main}"
  
  # Get local branch name
  local LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

  # Get change hash local and remote for later comparison
  local LOCAL_HASH=$(git rev-parse HEAD)
  local REMOTE_HASH=$(git ls-remote --tags --heads 2> /dev/null | grep heads/${TARGET_BRANCH} | awk '{ print $1 }')

  # Only compare local/remote changes if no local changes exist.
  if [[ -n $(git status -s) ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} local Chief changes detected. Update checking skipped."
  elif [[ ${LOCAL_HASH} != ${REMOTE_HASH} ]]; then
    if [[ ${LOCAL_BRANCH} != ${TARGET_BRANCH} ]]; then
      echo -e "${CHANGE_MSG} (switch to ${TARGET_BRANCH} branch)"
    else
      echo -e "${CHANGE_MSG}"
    fi
  fi
  cd - > /dev/null 2>&1
}

# TEXT COLOR VARIABLES
########################################################################

# Color guide from Stack Overflow
# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux

# Note: Use echo -e to support backslash escape
# echo -e "I ${CHIEF_COLOR_RED}love${CHIEF_NO_COLOR} Stack Overflow"

#Black        0;30     Dark Gray     1;30
#Red          0;31     Light Red     1;31
#Green        0;32     Light Green   1;32
#Brown/Orange 0;33     Yellow        1;33
#Blue         0;34     Light Blue    1;34
#Purple       0;35     Light Purple  1;35
#Cyan         0;36     Light Cyan    1;36
#Light Gray   0;37     White         1;37

export CHIEF_COLOR_RED='\033[0;31m'
export CHIEF_COLOR_BLUE='\033[0;34m'
export CHIEF_COLOR_CYAN='\033[0;36m'
export CHIEF_COLOR_GREEN='\033[0;32m'
export CHIEF_COLOR_MAGENTA='\033[0;35m'
export CHIEF_COLOR_ORANGE='\033[0;33m'
export CHIEF_COLOR_YELLOW='\033[1;33m'
export CHIEF_TEXT_BLINK='\033[5m'
export CHIEF_NO_COLOR='\033[0m' # Reset color/style

# PLATFORM-SPECIFIC SYMBOLS
########################################################################
# macOS gets fancy emoji icons, Linux gets simple colored text symbols
if [[ ${PLATFORM} == "MacOS" ]]; then
  export CHIEF_SYMBOL_SUCCESS='✅'
  export CHIEF_SYMBOL_ERROR='❌'
  export CHIEF_SYMBOL_WARNING='⚠️'
  export CHIEF_SYMBOL_INFO='ℹ️'
  export CHIEF_SYMBOL_CHECK='✓'
  export CHIEF_SYMBOL_CROSS='✗'
  export CHIEF_SYMBOL_DANGER='🚨'
  export CHIEF_SYMBOL_ROCKET='🚀'
  export CHIEF_SYMBOL_GEAR='⚙️'
else
  # Linux: Simple colored symbols for better compatibility
  export CHIEF_SYMBOL_SUCCESS="${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR}"
  export CHIEF_SYMBOL_ERROR="${CHIEF_COLOR_RED}✗${CHIEF_NO_COLOR}"
  export CHIEF_SYMBOL_WARNING="${CHIEF_COLOR_YELLOW}!${CHIEF_NO_COLOR}"
  export CHIEF_SYMBOL_INFO="${CHIEF_COLOR_CYAN}i${CHIEF_NO_COLOR}"
  export CHIEF_SYMBOL_CHECK="${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR}"
  export CHIEF_SYMBOL_CROSS="${CHIEF_COLOR_RED}✗${CHIEF_NO_COLOR}"
  export CHIEF_SYMBOL_DANGER="${CHIEF_COLOR_RED}!!${CHIEF_NO_COLOR}"
  export CHIEF_SYMBOL_ROCKET="${CHIEF_COLOR_BLUE}>>${CHIEF_NO_COLOR}"
  export CHIEF_SYMBOL_GEAR="${CHIEF_COLOR_CYAN}*${CHIEF_NO_COLOR}"
fi

# From: https://www.linuxquestions.org/questions/linux-newbie-8/bash-echo-the-arrow-keys-825773/
export CHIEF_KEYS_ESC=$'\e'
export CHIEF_KEYS_F1=$'\e'[[A
export CHIEF_KEYS_F2=$'\e'[[B
export CHIEF_KEYS_F3=$'\e'[[C
export CHIEF_KEYS_F4=$'\e'[[D
export CHIEF_KEYS_F5=$'\e'[[E
export CHIEF_KEYS_F6=$'\e'[17~
export CHIEF_KEYS_F7=$'\e'[18~
export CHIEF_KEYS_F8=$'\e'[19~
export CHIEF_KEYS_F9=$'\e'[20~
export CHIEF_KEYS_F10=$'\e'[21~
export CHIEF_KEYS_F11=$'\e'[22~
export CHIEF_KEYS_F12=$'\e'[23~
export CHIEF_KEYS_HOME=$'\e'[1~
export CHIEF_KEYS_HOME2=$'\e'[H
export CHIEF_KEYS_INSERT=$'\e'[2~
export CHIEF_KEYS_DELETE=$'\e'[3~
export CHIEF_KEYS_END=$'\e'[4~
export CHIEF_KEYS_END2=$'\e'[F
export CHIEF_KEYS_PAGEUP=$'\e'[5~
export CHIEF_KEYS_PAGEDOWN=$'\e'[6~
export CHIEF_KEYS_UP=$'\e'[A
export CHIEF_KEYS_DOWN=$'\e'[B
export CHIEF_KEYS_RIGHT=$'\e'[C
export CHIEF_KEYS_LEFT=$'\e'[D
export CHIEF_KEYS_NUMPADUNKNOWN=$'\e'[G


prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
      print -n "%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
      print -n "%{%k%}"
  fi

  print -n "%{%f%}"
  CURRENT_BG=''

  #Adds the new line and ➜ as the start character.
  printf "\n ➜";
}

function __chief_print_error(){
  echo -e "${CHIEF_COLOR_RED}Error: $1${CHIEF_NO_COLOR}"
}

function __chief_print_warn(){
  echo -e "${CHIEF_COLOR_YELLOW}Warning: $1${CHIEF_NO_COLOR}"
}

function __chief_print_success(){
  echo -e "${CHIEF_COLOR_GREEN}$1${CHIEF_NO_COLOR}"
}

function __chief_print_info(){
  echo -e "${CHIEF_COLOR_CYAN}$1${CHIEF_NO_COLOR}"
}

# MAIN FUNCTIONS
########################################################################

alias chief.ver='__chief.info'
alias chief.banner='chief.ver'

function chief.root() {
  local USAGE="Usage: $FUNCNAME

Change directory (cd) into the Chief utility root installation directory."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  cd ${CHIEF_PATH}
  echo -e "${CHIEF_COLOR_GREEN}Changed directory to CHIEF_PATH=${CHIEF_PATH}.${CHIEF_NO_COLOR}"
}

function chief.ssh_load_keys() {
  local USAGE="Usage: $FUNCNAME

Load SSH keys from CHIEF_CFG_SSH_KEYS_PATH defined in the Chief configuration.
Note: All private keys must end with the suffix '.key'. Symlinks are allowed.
This supports RSA, ed25519, and other key types. Use symlinks for selective loading.
"

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  if [[ -z ${CHIEF_CFG_SSH_KEYS_PATH}  ]]; then
    echo -e "${CHIEF_COLOR_RED}Error: CHIEF_CFG_SSH_KEYS_PATH is not set in ${CHIEF_CONFIG}. Please set it to the path where your SSH keys are stored.${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_YELLOW}Note: Keys must end with '.key' extension (supports RSA, ed25519, etc.)${CHIEF_NO_COLOR}"
    echo "${USAGE}"
    return 1
  fi
  chief.etc_spinner "Loading SSH keys..." "__chief_load_ssh_keys --verbose" tmp_out
  echo -e "${tmp_out}"
}

function chief.plugins_update() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--force]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Update and reload remote Chief plugins when using remote plugin configuration.

${CHIEF_COLOR_GREEN}Requirements:${CHIEF_NO_COLOR}
- CHIEF_CFG_PLUGINS_TYPE must be set to 'remote'
- CHIEF_CFG_PLUGINS_GIT_REPO must be configured
- Git must be available and repository accessible

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Detects and protects local changes before updating
- Fetches latest plugin versions from Git repository
- Automatically reloads updated plugins
- Provides verbose feedback during update process
- Maintains local plugin configuration

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
- --force    Force update, discarding any local changes (${CHIEF_COLOR_RED}DANGEROUS${CHIEF_NO_COLOR})

${CHIEF_COLOR_MAGENTA}Plugin Types:${CHIEF_NO_COLOR}
- ${CHIEF_COLOR_GREEN}Remote:${CHIEF_NO_COLOR} Plugins managed via Git repository (team sharing)
- ${CHIEF_COLOR_BLUE}Local:${CHIEF_NO_COLOR} Plugins in ~/chief_plugins (personal use)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Safe update with local changes protection
  $FUNCNAME --force            # Force update, discarding local changes
  chief.config                 # Configure plugin settings first

${CHIEF_COLOR_BLUE}Configuration:${CHIEF_NO_COLOR}
Set CHIEF_CFG_PLUGINS_TYPE='remote' and CHIEF_CFG_PLUGINS_GIT_REPO in chief.config
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi
  
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]]; then
    # Check for local changes before updating (unless --force is used)
    if [[ "$1" != "--force" ]] && __chief_check_plugins_local_changes; then
      echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Local changes detected in plugins directory: ${CHIEF_CFG_PLUGINS_PATH}"
      echo -e "${CHIEF_COLOR_CYAN}You have local modifications in your plugins directory.${CHIEF_NO_COLOR}"
      echo -e "${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}"
      echo -e "  ${CHIEF_COLOR_GREEN}1.${CHIEF_NO_COLOR} Commit and push your changes first: ${CHIEF_COLOR_CYAN}cd ${CHIEF_CFG_PLUGINS_PATH} && git add . && git commit -m 'your message' && git push${CHIEF_NO_COLOR}"
      echo -e "  ${CHIEF_COLOR_GREEN}2.${CHIEF_NO_COLOR} Force update anyway: ${CHIEF_COLOR_CYAN}$FUNCNAME --force${CHIEF_NO_COLOR} (${CHIEF_COLOR_RED}WILL LOSE YOUR CHANGES${CHIEF_NO_COLOR})"
      echo -e "  ${CHIEF_COLOR_GREEN}3.${CHIEF_NO_COLOR} Cancel and handle changes manually"
      echo
      
      if chief.etc_ask-yes-or-no "Force update anyway? This will ${CHIEF_COLOR_RED}DISCARD ALL LOCAL CHANGES${CHIEF_NO_COLOR}!"; then
        echo -e "${CHIEF_COLOR_YELLOW}Proceeding with force update. Local changes will be lost.${CHIEF_NO_COLOR}"
        __chief_load_remote_plugins "--verbose" "--force" "--explicit" && {
          echo -e "${CHIEF_COLOR_GREEN}Updated all plugins to the latest version.${CHIEF_NO_COLOR}"
        } || {
          echo -e "${CHIEF_COLOR_RED}Error: Failed to update plugins.${CHIEF_NO_COLOR}"
        }
      else
        echo -e "${CHIEF_COLOR_GREEN}Update cancelled. Your local changes are preserved.${CHIEF_NO_COLOR}"
        echo -e "${CHIEF_COLOR_CYAN}Please handle your local changes manually and run $FUNCNAME again when ready.${CHIEF_NO_COLOR}"
        return 1
      fi
    else
      # Safe update (no local changes detected or --force was used)
      local force_flag=""
      if [[ "$1" == "--force" ]]; then
        force_flag="--force"
        echo -e "${CHIEF_COLOR_YELLOW}Force update requested - local changes will be discarded.${CHIEF_NO_COLOR}"
      fi
      
      __chief_load_remote_plugins "--verbose" "$force_flag" "--explicit" && {
        echo -e "${CHIEF_COLOR_GREEN}Updated all plugins to the latest version.${CHIEF_NO_COLOR}"
      } || {
        echo -e "${CHIEF_COLOR_RED}Error: Failed to update plugins.${CHIEF_NO_COLOR}"
      }
    fi
  else
    echo -e "${CHIEF_COLOR_YELLOW}This function is used only when CHIEF_CFG_PLUGINS_TYPE='remote'.${CHIEF_NO_COLOR}"
  fi
}

function chief.update() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Update the Chief utility library to the latest version from the official repository.

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Checks for available updates with spinner indicator
- Interactive confirmation before updating
- Pulls latest changes from Chief repository
- Automatically reloads environment after update
- Preserves your personal configuration and plugins
- Tracks configured branch (CHIEF_CFG_UPDATE_BRANCH)

${CHIEF_COLOR_BLUE}Update Process:${CHIEF_NO_COLOR}
1. Check for available updates on configured branch
2. Prompt for user confirmation
3. Switch to target branch if needed (main/dev)
4. Pull latest Chief version from target branch
5. Reload Chief environment
6. Return to original directory

${CHIEF_COLOR_MAGENTA}Safety Features:${CHIEF_NO_COLOR}
- Only updates Chief core files
- Preserves user configurations and plugins
- Shows progress with visual feedback
- Requires explicit user confirmation

${CHIEF_COLOR_CYAN}Branch Configuration:${CHIEF_NO_COLOR}
- Set CHIEF_CFG_UPDATE_BRANCH=\"main\" for stable releases
- Set CHIEF_CFG_UPDATE_BRANCH=\"dev\" for bleeding-edge features  
- Set CHIEF_CFG_UPDATE_BRANCH=\"custom-branch\" for specific versions
- WARNING: non-main branches may contain unstable features

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Check and update Chief
  chief.reload                 # Reload after manual updates

${CHIEF_COLOR_BLUE}Alternative:${CHIEF_NO_COLOR}
You can also manually update by running git pull in the Chief directory.
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  __chief.banner
  
  # Check if we need to switch branches first (regardless of updates)
  cd "${CHIEF_PATH}"
  local TARGET_BRANCH="${CHIEF_CFG_UPDATE_BRANCH:-main}"
  local LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  
  if [[ ${LOCAL_BRANCH} != ${TARGET_BRANCH} ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Notice: Currently on ${LOCAL_BRANCH} branch, but configured to track ${TARGET_BRANCH}${CHIEF_NO_COLOR}"
    if chief.etc_ask-yes-or-no "Switch to ${TARGET_BRANCH} branch now?"; then
      echo -e "${CHIEF_COLOR_CYAN}Switching from ${LOCAL_BRANCH} to ${TARGET_BRANCH} branch...${CHIEF_NO_COLOR}"
      
      # Fetch all branches to ensure target branch exists
      echo -e "${CHIEF_COLOR_BLUE}Fetching latest changes...${CHIEF_NO_COLOR}"
      
      # Check if this is a shallow clone and unshallow if needed for branch switching
      if git rev-parse --is-shallow-repository >/dev/null 2>&1 && [[ $(git rev-parse --is-shallow-repository) == "true" ]]; then
        echo -e "${CHIEF_COLOR_YELLOW}Detected shallow clone. Converting to full repository for branch switching...${CHIEF_NO_COLOR}"
        git fetch --unshallow origin || {
          echo -e "${CHIEF_COLOR_YELLOW}Warning: Failed to unshallow repository. Trying regular fetch...${CHIEF_NO_COLOR}"
          git fetch origin || {
            echo -e "${CHIEF_COLOR_RED}Error: Failed to fetch from remote repository${CHIEF_NO_COLOR}"
            cd - > /dev/null 2>&1
            return 1
          }
        }
      else
        git fetch origin || {
          echo -e "${CHIEF_COLOR_RED}Error: Failed to fetch from remote repository${CHIEF_NO_COLOR}"
          cd - > /dev/null 2>&1
          return 1
        }
      fi
      
      # Check if target branch exists remotely
      echo -e "${CHIEF_COLOR_BLUE}Verifying ${TARGET_BRANCH} branch exists remotely...${CHIEF_NO_COLOR}"
      if ! git ls-remote --heads origin "${TARGET_BRANCH}" | grep -q "refs/heads/${TARGET_BRANCH}$"; then
        echo -e "${CHIEF_COLOR_RED}Error: Branch '${TARGET_BRANCH}' does not exist in remote repository${CHIEF_NO_COLOR}"
        echo -e "${CHIEF_COLOR_CYAN}Available remote branches:${CHIEF_NO_COLOR}"
        git ls-remote --heads origin | sed 's|.*refs/heads/||' | sed 's/^/  /'
        echo -e "${CHIEF_COLOR_YELLOW}Try: chief.config_set update_branch <valid_branch_name>${CHIEF_NO_COLOR}"
        cd - > /dev/null 2>&1
        return 1
      fi
      echo -e "${CHIEF_COLOR_GREEN}✓ Branch ${TARGET_BRANCH} found remotely${CHIEF_NO_COLOR}"
      
      # Switch to target branch (create local branch if needed)
      if git show-ref --verify --quiet "refs/heads/${TARGET_BRANCH}"; then
        # Local branch exists, switch to it
        git checkout "${TARGET_BRANCH}" || {
          echo -e "${CHIEF_COLOR_RED}Error: Failed to switch to ${TARGET_BRANCH} branch${CHIEF_NO_COLOR}"
          cd - > /dev/null 2>&1
          return 1
        }
      else
        # Local branch doesn't exist, create it from remote
        echo -e "${CHIEF_COLOR_BLUE}Creating local ${TARGET_BRANCH} branch from remote...${CHIEF_NO_COLOR}"
        
        # Method 1: Create and switch to new branch tracking remote
        if git checkout -b "${TARGET_BRANCH}" "origin/${TARGET_BRANCH}" 2>/dev/null; then
          echo -e "${CHIEF_COLOR_GREEN}✓ Successfully created and switched to ${TARGET_BRANCH} branch${CHIEF_NO_COLOR}"
        else
          # Method 2: Use remote tracking branch creation
          echo -e "${CHIEF_COLOR_YELLOW}Trying alternative branch creation...${CHIEF_NO_COLOR}"
          if git checkout --track "origin/${TARGET_BRANCH}" 2>/dev/null; then
            echo -e "${CHIEF_COLOR_GREEN}✓ Successfully created tracking branch ${TARGET_BRANCH}${CHIEF_NO_COLOR}"
          else
            # Method 3: Force reset to remote branch (more aggressive)
            echo -e "${CHIEF_COLOR_YELLOW}Using force checkout method...${CHIEF_NO_COLOR}"
            git checkout -B "${TARGET_BRANCH}" "origin/${TARGET_BRANCH}" 2>/dev/null || {
              echo -e "${CHIEF_COLOR_RED}Error: All branch creation methods failed${CHIEF_NO_COLOR}"
              echo -e "${CHIEF_COLOR_CYAN}Available remote branches:${CHIEF_NO_COLOR}"
              git branch -r | grep -v HEAD | sed 's/origin\///' | sed 's/^[[:space:]]*/  /'
              echo -e "${CHIEF_COLOR_YELLOW}You may need to run: git clean -fd && git reset --hard${CHIEF_NO_COLOR}"
              cd - > /dev/null 2>&1
              return 1
            }
          fi
        fi
      fi
      
      echo -e "${CHIEF_COLOR_GREEN}Successfully switched to ${TARGET_BRANCH} branch${CHIEF_NO_COLOR}"
      
      # Pull latest changes from the target branch
      echo -e "${CHIEF_COLOR_CYAN}Pulling latest changes from ${TARGET_BRANCH} branch...${CHIEF_NO_COLOR}"
      git pull origin "${TARGET_BRANCH}" || {
        echo -e "${CHIEF_COLOR_RED}Error: Failed to pull updates from ${TARGET_BRANCH} branch${CHIEF_NO_COLOR}"
        cd - > /dev/null 2>&1
        return 1
      }
      
      # Reload Chief to reflect the branch change and updates
      echo -e "${CHIEF_COLOR_BLUE}Reloading Chief to reflect branch change and updates...${CHIEF_NO_COLOR}"
      chief.reload
      cd - > /dev/null 2>&1
      echo -e "${CHIEF_COLOR_GREEN}Updated Chief to [${CHIEF_VERSION}] from ${TARGET_BRANCH} branch.${CHIEF_NO_COLOR}"
      return 0
    else
      echo -e "${CHIEF_COLOR_YELLOW}Branch switch cancelled. Continuing with update check on current branch.${CHIEF_NO_COLOR}"
    fi
  fi
  
  # Now check for updates on the current/correct branch
  chief.etc_spinner "Checking for updates..." "__chief_check_for_updates" tmp_out
  echo -e "${tmp_out}"
  if [[ ${tmp_out} == *"available"* ]]; then
    if chief.etc_ask-yes-or-no "Updates are available, update now?"; then
      echo "Proceeding..."
      
      # We're already in CHIEF_PATH and on the correct branch
      local TARGET_BRANCH="${CHIEF_CFG_UPDATE_BRANCH:-main}"
      local LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
      
      # Switch to target branch if different from current branch
      if [[ ${LOCAL_BRANCH} != ${TARGET_BRANCH} ]]; then
        echo -e "${CHIEF_COLOR_CYAN}Switching from ${LOCAL_BRANCH} to ${TARGET_BRANCH} branch...${CHIEF_NO_COLOR}"
        
        # Fetch all branches to ensure target branch exists
        echo -e "${CHIEF_COLOR_BLUE}Fetching latest changes...${CHIEF_NO_COLOR}"
        
        # Check if this is a shallow clone and unshallow if needed for branch switching
        if git rev-parse --is-shallow-repository >/dev/null 2>&1 && [[ $(git rev-parse --is-shallow-repository) == "true" ]]; then
          echo -e "${CHIEF_COLOR_YELLOW}Detected shallow clone. Converting to full repository for branch switching...${CHIEF_NO_COLOR}"
          git fetch --unshallow origin || {
            echo -e "${CHIEF_COLOR_YELLOW}Warning: Failed to unshallow repository. Trying regular fetch...${CHIEF_NO_COLOR}"
            git fetch origin || {
              echo -e "${CHIEF_COLOR_RED}Error: Failed to fetch from remote repository${CHIEF_NO_COLOR}"
              return 1
            }
          }
        else
          git fetch origin || {
            echo -e "${CHIEF_COLOR_RED}Error: Failed to fetch from remote repository${CHIEF_NO_COLOR}"
            return 1
          }
        fi
        
        # Check if target branch exists remotely
        echo -e "${CHIEF_COLOR_BLUE}Verifying ${TARGET_BRANCH} branch exists remotely...${CHIEF_NO_COLOR}"
        if ! git ls-remote --heads origin "${TARGET_BRANCH}" | grep -q "refs/heads/${TARGET_BRANCH}$"; then
          echo -e "${CHIEF_COLOR_RED}Error: Branch '${TARGET_BRANCH}' does not exist in remote repository${CHIEF_NO_COLOR}"
          echo -e "${CHIEF_COLOR_CYAN}Available remote branches:${CHIEF_NO_COLOR}"
          git ls-remote --heads origin | sed 's|.*refs/heads/||' | sed 's/^/  /'
          echo -e "${CHIEF_COLOR_YELLOW}Try: chief.config_set update_branch <valid_branch_name>${CHIEF_NO_COLOR}"
          return 1
        fi
        echo -e "${CHIEF_COLOR_GREEN}✓ Branch ${TARGET_BRANCH} found remotely${CHIEF_NO_COLOR}"
        
        # Switch to target branch (create local branch if needed)
        if git show-ref --verify --quiet "refs/heads/${TARGET_BRANCH}"; then
          # Local branch exists, switch to it
          git checkout "${TARGET_BRANCH}" || {
            echo -e "${CHIEF_COLOR_RED}Error: Failed to switch to ${TARGET_BRANCH} branch${CHIEF_NO_COLOR}"
            return 1
          }
        else
          # Local branch doesn't exist, create it from remote
          echo -e "${CHIEF_COLOR_BLUE}Creating local ${TARGET_BRANCH} branch from remote...${CHIEF_NO_COLOR}"
          
          # Method 1: Create and switch to new branch tracking remote
          if git checkout -b "${TARGET_BRANCH}" "origin/${TARGET_BRANCH}" 2>/dev/null; then
            echo -e "${CHIEF_COLOR_GREEN}✓ Successfully created and switched to ${TARGET_BRANCH} branch${CHIEF_NO_COLOR}"
          else
            # Method 2: Use remote tracking branch creation
            echo -e "${CHIEF_COLOR_YELLOW}Trying alternative branch creation...${CHIEF_NO_COLOR}"
            if git checkout --track "origin/${TARGET_BRANCH}" 2>/dev/null; then
              echo -e "${CHIEF_COLOR_GREEN}✓ Successfully created tracking branch ${TARGET_BRANCH}${CHIEF_NO_COLOR}"
            else
              # Method 3: Force reset to remote branch (more aggressive)
              echo -e "${CHIEF_COLOR_YELLOW}Using force checkout method...${CHIEF_NO_COLOR}"
              git checkout -B "${TARGET_BRANCH}" "origin/${TARGET_BRANCH}" 2>/dev/null || {
                echo -e "${CHIEF_COLOR_RED}Error: All branch creation methods failed${CHIEF_NO_COLOR}"
                echo -e "${CHIEF_COLOR_CYAN}Available remote branches:${CHIEF_NO_COLOR}"
                git branch -r | grep -v HEAD | sed 's/origin\///' | sed 's/^[[:space:]]*/  /'
                echo -e "${CHIEF_COLOR_YELLOW}You may need to run: git clean -fd && git reset --hard${CHIEF_NO_COLOR}"
                return 1
              }
            fi
          fi
        fi
        
        echo -e "${CHIEF_COLOR_GREEN}Successfully switched to ${TARGET_BRANCH} branch${CHIEF_NO_COLOR}"
      fi
      
      # Pull updates from the target branch
      echo -e "${CHIEF_COLOR_CYAN}Updating from ${TARGET_BRANCH} branch...${CHIEF_NO_COLOR}"
      git pull origin "${TARGET_BRANCH}" || {
        echo -e "${CHIEF_COLOR_RED}Error: Failed to pull updates from ${TARGET_BRANCH} branch${CHIEF_NO_COLOR}"
        return 1
      }
      
      chief.reload
      cd - > /dev/null 2>&1
      echo -e "${CHIEF_COLOR_GREEN}Updated Chief to [${CHIEF_VERSION}] from ${TARGET_BRANCH} branch.${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_YELLOW}Update skipped.${CHIEF_NO_COLOR}"
    fi
  else
    echo -e "${CHIEF_COLOR_YELLOW}You're running the latest version [${CHIEF_VERSION}] of Chief.${CHIEF_NO_COLOR}"
  fi
}

function chief.uninstall() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Completely uninstall the Chief utility from your system with safety precautions.

${CHIEF_COLOR_GREEN}Safety Features:${CHIEF_NO_COLOR}
- Interactive confirmation before proceeding
- Backs up configuration as ${CHIEF_CONFIG}.backup
- Preserves all plugin files and directories
- Removes Chief from shell configuration files

${CHIEF_COLOR_BLUE}What Gets Removed:${CHIEF_NO_COLOR}
- Chief installation directory
- Shell profile integration (.bash_profile entries)
- Chief environment variables and functions
- Symlinks and shortcuts

${CHIEF_COLOR_MAGENTA}What Gets Preserved:${CHIEF_NO_COLOR}
- Personal plugins in ~/chief_plugins
- Backed up configuration file
- Custom shell modifications (non-Chief)
- User data and settings

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Uninstall with prompts
  
${CHIEF_COLOR_RED}Warning:${CHIEF_NO_COLOR}
This operation removes Chief from your system. Your plugins and config backup will remain.

${CHIEF_COLOR_BLUE}Reinstallation:${CHIEF_NO_COLOR}
Run the install script again to reinstall Chief with your backed up configuration.
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_YELLOW}Starting Chief uninstall process...${CHIEF_NO_COLOR}"
  ${CHIEF_PATH}/tools/uninstall.sh
}

function chief.config() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit Chief's configuration file with automatic reload on changes.

${CHIEF_COLOR_GREEN}Configuration Options:${CHIEF_NO_COLOR}
- CHIEF_CFG_BANNER: Show startup banner
- CHIEF_CFG_PROMPT: Use Chief's custom prompt
- CHIEF_CFG_GIT_PROMPT: Git-aware prompt features
- CHIEF_CFG_MULTILINE_PROMPT: Enable multiline prompt
- CHIEF_CFG_PLUGINS_TYPE: 'local' or 'remote' plugins
- CHIEF_CFG_SSH_KEYS_PATH: Auto-load SSH keys path (keys must end in .key)
- And many more...

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your preferred \$EDITOR
- Automatically reloads configuration on save
- Validates syntax before applying changes

${CHIEF_COLOR_MAGENTA}File Location:${CHIEF_NO_COLOR}
$CHIEF_CONFIG

${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR}
Some changes require terminal restart to take full effect.
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  # Third parameter is to reload entire library if config is modified.
  __chief_edit_file ${CHIEF_CONFIG} "Chief Configuration" "reload" && {
    echo -e "${CHIEF_COLOR_YELLOW}Terminal/session restart is required for some changes to take effect.${CHIEF_NO_COLOR}"
  }
}

function chief.config-set() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--list|-l] | <config_option>=<value> [--yes|-y]
       $FUNCNAME <config_option> <value> [--yes|-y]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Set a Chief configuration variable and reload the configuration automatically.
Supports both key=value and separate argument formats for flexibility.
By default, prompts for confirmation before modifying config file. Use --yes to skip prompts.

${CHIEF_COLOR_GREEN}Options:${CHIEF_NO_COLOR}
  --list, -l     List all available configuration variables and their current values
  --yes, -y      Skip confirmation prompt (non-interactive mode for scripting)
                 Can be placed anywhere in the argument list

${CHIEF_COLOR_GREEN}Arguments:${CHIEF_NO_COLOR}
  config_option  Configuration option name (without CHIEF_CFG_ prefix, case insensitive)
  value          Boolean (true/false) or string value to set

${CHIEF_COLOR_GREEN}Input Formats:${CHIEF_NO_COLOR}
  key=value      Combined format: config_option=value
  key value      Separate format: config_option value

${CHIEF_COLOR_BLUE}Supported Configuration Variables:${CHIEF_NO_COLOR}
  BANNER                    Show/hide startup banner (true/false)
  HINTS                     Show/hide startup hints (true/false)
  VERBOSE                   Enable verbose output (true/false)
  AUTOCHECK_UPDATES         Auto-check for updates (true/false)
  UPDATE_BRANCH             Branch to track for updates (any valid Git branch) 
  CONFIG_SET_INTERACTIVE    Enable/disable confirmation prompts (true/false)
  CONFIG_UPDATE_BACKUP      Create backups during config updates (true/false)
  PLUGINS_TYPE              Plugin type (\"local\"/\"remote\")
  PLUGINS_GIT_REPO          Git repository URL for remote plugins
  PLUGINS_GIT_BRANCH        Git branch to use (default: main)
  PLUGINS_PATH              Local plugin directory (also remote repo clone location)
  PLUGINS_GIT_PATH          [Remote only] Relative path within repo (empty = repo root)
  PLUGINS_GIT_AUTOUPDATE    Auto-update remote plugins (true/false)
  PROMPT                    Enable/disable Chief prompt (true/false)
  COLORED_PROMPT            Enable colored prompts (true/false)
  GIT_PROMPT                Show git status in prompt (true/false)
  MULTILINE_PROMPT          Use multi-line prompt layout (true/false)
  SHORT_PATH                Show short paths in prompt (true/false)
  COLORED_LS                Enable colored ls output (true/false)
  SSH_KEYS_PATH             Path to SSH keys directory (keys must end in .key)
  ALIAS                     Custom alias for chief commands

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME --list                      # List all configuration variables
  $FUNCNAME banner true                 # Enable startup banner (with prompt)
  $FUNCNAME banner=true                 # Same as above using key=value syntax
  $FUNCNAME --yes banner false          # Disable startup banner (no prompt)
  $FUNCNAME colored_ls=true --yes       # Enable colored ls (no prompt)
  $FUNCNAME prompt -y true              # Enable custom prompt (no prompt)
  $FUNCNAME ssh_keys_path \"\$HOME/.ssh\"  # Set SSH keys path (with prompt)
  $FUNCNAME update_branch=dev           # Track dev branch for updates (with prompt)
  $FUNCNAME --yes update_branch main    # Track stable main branch (no prompt)
  $FUNCNAME update_branch=staging       # Track custom staging branch (with prompt)
  $FUNCNAME config_set_interactive=false # Disable prompts globally
  $FUNCNAME config_update_backup=false  # Disable backups during config updates

${CHIEF_COLOR_MAGENTA}Notes:${CHIEF_NO_COLOR}
- Configuration options are case insensitive
- Supports BOTH syntaxes: config_name value OR config_name=value
- String values with spaces should be quoted
- Changes take effect immediately after reload
- Some changes may require terminal restart
- Reports previous and new values for each change
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  # Handle --list option
  if [[ $1 == "--list" || $1 == "-l" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Current Chief Configuration Settings:${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_BLUE}Source:${CHIEF_NO_COLOR} ${CHIEF_CONFIG}"
    echo
    
    # List all CHIEF_CFG_ variables from config file
    while IFS= read -r line; do
      if [[ $line =~ ^[#]*CHIEF_CFG_([A-Z_]+)=(.*)$ ]]; then
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${BASH_REMATCH[2]}"
        local is_commented=""
        
        if [[ $line =~ ^# ]]; then
          is_commented=" ${CHIEF_COLOR_RED}(commented/disabled)${CHIEF_NO_COLOR}"
        fi
        
        echo -e "  ${CHIEF_COLOR_GREEN}${var_name}${CHIEF_NO_COLOR}=${CHIEF_COLOR_YELLOW}${var_value}${CHIEF_NO_COLOR}${is_commented}"
      fi
    done < "${CHIEF_CONFIG}"
    
    return
  fi

  # Handle --yes option (non-interactive mode) - can be anywhere in arguments
  local skip_confirmation=false
  local args=()
  
  # Parse all arguments, extract --yes flag and build clean args array
  while [[ $# -gt 0 ]]; do
    case $1 in
      --yes|-y)
        skip_confirmation=true
        ;;
      *)
        args+=("$1")
        ;;
    esac
    shift
  done

  # Restore arguments without --yes flag
  set -- "${args[@]}"

  # Handle both syntaxes: "key value" or "key=value"
  local config_name config_value
  if [[ $# -eq 1 ]] && [[ "$1" =~ ^([^=]+)=(.*)$ ]]; then
    # Handle key=value syntax
    config_name=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
    config_value="${BASH_REMATCH[2]}"
  elif [[ $# -eq 2 ]]; then
    # Handle key value syntax
    config_name=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    config_value="$2"
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Missing required arguments"
    echo -e "Usage: config_name value OR config_name=value"
    echo -e "${USAGE}"
    return 1
  fi
  local config_var="CHIEF_CFG_${config_name}"
  
  # Validate config name exists in user config or template
  local config_template="${CHIEF_PATH}/templates/chief_config_template.sh"
  if ! grep -q "^[#]*${config_var}=" "${CHIEF_CONFIG}" 2>/dev/null && ! grep -q "^[#]*${config_var}=" "${config_template}" 2>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown configuration option: ${config_name}"
    echo -e "Run ${CHIEF_COLOR_GREEN}$FUNCNAME --list${CHIEF_NO_COLOR} to see all available variables"
    return 1
  fi

  # Get previous value
  local previous_value=""
  local was_commented=false
  if grep -q "^${config_var}=" "${CHIEF_CONFIG}"; then
    previous_value=$(grep "^${config_var}=" "${CHIEF_CONFIG}" | cut -d'=' -f2-)
  elif grep -q "^#${config_var}=" "${CHIEF_CONFIG}"; then
    previous_value=$(grep "^#${config_var}=" "${CHIEF_CONFIG}" | cut -d'=' -f2-)
    was_commented=true
  else
    previous_value="<not set>"
  fi

  # Validate boolean values and prepare new value
  case "${config_value}" in
    true|false)
      # Valid boolean values
      ;;
    *)
      # String value - wrap in quotes if it contains spaces or special chars
      if [[ "${config_value}" =~ [[:space:]\"\'$] ]]; then
        config_value="\"${config_value}\""
      fi
      ;;
  esac

  # Check if value is already set to the same value
  if [[ "${previous_value}" == "${config_value}" && "${was_commented}" == false ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Configuration ${CHIEF_COLOR_CYAN}${config_var}${CHIEF_NO_COLOR} is already set to ${CHIEF_COLOR_YELLOW}${config_value}${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_BLUE}No changes made.${CHIEF_NO_COLOR}"
    return 0
  fi

  # Interactive confirmation prompt (unless --yes flag used or global setting disabled)
  if [[ "${skip_confirmation}" != true ]] && [[ "${CHIEF_CFG_CONFIG_SET_INTERACTIVE:-true}" != "false" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}About to modify configuration:${CHIEF_NO_COLOR}"
    echo -e "  ${CHIEF_COLOR_CYAN}File:${CHIEF_NO_COLOR}     ${CHIEF_CONFIG}"
    echo -e "  ${CHIEF_COLOR_CYAN}Variable:${CHIEF_NO_COLOR} ${config_var}"
    echo -e "  ${CHIEF_COLOR_CYAN}Change:${CHIEF_NO_COLOR}   ${previous_value} → ${config_value}"
    echo
    echo -en "${CHIEF_COLOR_YELLOW}Overwrite ${CHIEF_CONFIG}? (y/n [n]): ${CHIEF_NO_COLOR}"
    read -r confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
      echo -e "${CHIEF_COLOR_BLUE}Configuration change cancelled.${CHIEF_NO_COLOR}"
      return 0
    fi
    echo
  fi

  echo -e "${CHIEF_COLOR_BLUE}Setting configuration variable:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_CYAN}Variable:${CHIEF_NO_COLOR} ${config_var}"
  
  local comment_note=""
  if [[ "${was_commented}" == true ]]; then
    comment_note=" (was commented)"
  fi
  
  echo -e "  ${CHIEF_COLOR_CYAN}Previous:${CHIEF_NO_COLOR} ${previous_value}${comment_note}"
  echo -e "  ${CHIEF_COLOR_CYAN}New:${CHIEF_NO_COLOR}      ${config_value}"


  # Update or add the configuration
  echo -e "${CHIEF_COLOR_BLUE}Updating configuration file...${CHIEF_NO_COLOR}"
  
  if grep -q "^[#]*${config_var}=" "${CHIEF_CONFIG}"; then
    # Configuration exists, update it (remove comment if present)
    local temp_file="/tmp/chief_config_temp_$$"
    # Portable way to resolve symlinks (readlink -f doesn't exist on macOS)
    local target_file="${CHIEF_CONFIG}"
    if [[ -L "${CHIEF_CONFIG}" ]]; then
      # Handle symbolic links portably
      if command -v readlink >/dev/null 2>&1; then
        target_file=$(readlink "${CHIEF_CONFIG}" 2>/dev/null || echo "${CHIEF_CONFIG}")
        # If result is relative, make it absolute
        if [[ "${target_file}" != /* ]]; then
          target_file="$(dirname "${CHIEF_CONFIG}")/${target_file}"
        fi
      fi
    fi
    
    # Temporarily disable noclobber and clean up any existing temp file
    local old_noclobber=$(set +o | grep noclobber)
    set +o noclobber
    rm -f "${temp_file}"
    
    if sed "s|^[#]*${config_var}=.*|${config_var}=${config_value}|" "${CHIEF_CONFIG}" > "${temp_file}" && command cp -f "${temp_file}" "${target_file}"; then
      echo -e "${CHIEF_SYMBOL_CHECK} Updated ${config_var}"
      rm -f "${temp_file}"
    else
      echo -e "${CHIEF_SYMBOL_CROSS} Failed to update ${config_var}"
      rm -f "${temp_file}"
      return 1
    fi
    
    # Restore noclobber setting
    eval "${old_noclobber}"
  else
    # Configuration doesn't exist, add it
    if echo "${config_var}=${config_value}" >> "${CHIEF_CONFIG}"; then
      echo -e "${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR} Added ${config_var}"
    else
      echo -e "${CHIEF_COLOR_RED}✗${CHIEF_NO_COLOR} Failed to add ${config_var}"
      return 1
    fi
  fi

  # Reload configuration
  echo -e "${CHIEF_COLOR_BLUE}Reloading Chief configuration...${CHIEF_NO_COLOR}"
  if __chief_load_library --verbose; then
    echo -e "${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR} Configuration reloaded successfully"
  else
    echo -e "${CHIEF_COLOR_YELLOW}⚠${CHIEF_NO_COLOR} Configuration file updated but reload had issues"
  fi
  
  # Verify the change
  local current_value
  if current_value=$(grep "^${config_var}=" "${CHIEF_CONFIG}" 2>/dev/null | cut -d'=' -f2-); then
    echo -e "${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR} Confirmed: ${config_var}=${current_value}"
  else
    echo -e "${CHIEF_COLOR_YELLOW}⚠${CHIEF_NO_COLOR} Could not verify the configuration change"
  fi
}

function __chief_get_config_renames() {
  # Usage: __chief_get_config_renames
  # 
  # Return associative array of old->new config variable names
  # Used for migrating renamed configuration options
  
  # Define config renames (old_name:new_name)
  local -A renames=(
    ["CHIEF_CFG_RSA_KEYS_PATH"]="CHIEF_CFG_SSH_KEYS_PATH"
  )
  
  # Output the mappings
  for old_key in "${!renames[@]}"; do
    echo "${old_key}:${renames[$old_key]}"
  done
}

function __chief_parse_config_template() {
  # Usage: __chief_parse_config_template <template_file>
  # 
  # Parse template config file and extract all configuration options with their comments
  # Returns format: VARIABLE_NAME|default_value|is_commented|comment_block
  
  local template_file="$1"
  local current_comments=""
  
  if [[ ! -f "$template_file" ]]; then
    echo "Error: Template file not found: $template_file" >&2
    return 1
  fi
  
  while IFS= read -r line; do
    # Skip empty lines but preserve section breaks
    if [[ -z "$line" ]]; then
      if [[ -n "$current_comments" ]]; then
        current_comments="${current_comments}\n"
      fi
      continue
    fi
    
    # Collect comments and section headers
    if [[ "$line" =~ ^[[:space:]]*# ]] && [[ ! "$line" =~ ^[[:space:]]*#[[:space:]]*CHIEF_CFG_ ]]; then
      if [[ -n "$current_comments" ]]; then
        current_comments="${current_comments}\n${line}"
      else
        current_comments="$line"
      fi
      continue
    fi
    
    # Parse configuration variables (both commented and uncommented)
    if [[ "$line" =~ ^[[:space:]]*#?[[:space:]]*CHIEF_CFG_([A-Z_]+)=(.*)$ ]]; then
      local var_name="CHIEF_CFG_${BASH_REMATCH[1]}"
      local var_value="${BASH_REMATCH[2]}"
      local is_commented="active"
      
      # Check if the variable line is commented out
      if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*CHIEF_CFG_ ]]; then
        is_commented="commented"
      fi
      
      # Output: variable|value|is_commented|comments
      echo "${var_name}|${var_value}|${is_commented}|${current_comments}"
      current_comments=""
    else
      # Reset comments if we hit a non-config line
      current_comments=""
    fi
  done < "$template_file"
}

function __chief_parse_user_config() {
  # Usage: __chief_parse_user_config <user_config_file>
  # 
  # Parse user config file and extract current values
  # Returns format: VARIABLE_NAME|current_value|is_commented
  
  local user_config="$1"
  
  if [[ ! -f "$user_config" ]]; then
    echo "Error: User config file not found: $user_config" >&2
    return 1
  fi
  
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*CHIEF_CFG_([A-Z_]+)=(.*)$ ]]; then
      # Commented config option
      local var_name="CHIEF_CFG_${BASH_REMATCH[1]}"
      local var_value="${BASH_REMATCH[2]}"
      echo "${var_name}|${var_value}|commented"
    elif [[ "$line" =~ ^[[:space:]]*CHIEF_CFG_([A-Z_]+)=(.*)$ ]]; then
      # Active config option
      local var_name="CHIEF_CFG_${BASH_REMATCH[1]}"
      local var_value="${BASH_REMATCH[2]}"
      echo "${var_name}|${var_value}|active"
    fi
  done < "$user_config"
}

function chief.config-update() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [OPTIONS]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Update your Chief configuration file with new options from the latest template.
This reconciles your existing config with new features while preserving your customizations.

${CHIEF_COLOR_GREEN}What This Does:${CHIEF_NO_COLOR}
- Creates a timestamped backup only when changes are made (if backup enabled)
- Adds any new configuration options from the template
- Preserves all your existing settings and customizations  
- Handles renamed configuration options automatically
- Maintains all comments and documentation from template
- Reloads Chief with the updated configuration

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --dry-run         Show what would be changed without making changes
  --no-backup       Skip creating backup (not recommended)
  --force           Update even if no changes detected
  -?, --help        Show this help message

${CHIEF_COLOR_MAGENTA}Safety Features:${CHIEF_NO_COLOR}
- Creates backup only when changes are made (respects CHIEF_CFG_CONFIG_UPDATE_BACKUP)
- Preserves your existing values and customizations
- Shows exactly what changes will be made
- Validates config syntax before applying changes

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                     # Update config with backup and reload
  $FUNCNAME --dry-run           # Preview changes without applying
  $FUNCNAME --force             # Force update even if up-to-date
"

  # Parse arguments
  local dry_run=false
  local no_backup=false  
  local force_update=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run)
        dry_run=true
        shift
        ;;
      --no-backup)
        no_backup=true
        shift
        ;;
      --force)
        force_update=true
        shift
        ;;
      -\?|--help)
        echo -e "${USAGE}"
        return 0
        ;;
      *)
        echo -e "${CHIEF_COLOR_RED}Error: Unknown option: $1${CHIEF_NO_COLOR}"
        echo -e "${USAGE}"
        return 1
        ;;
    esac
  done

  # Validate required files exist
  if [[ ! -f "$CHIEF_CONFIG" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error: User config file not found: $CHIEF_CONFIG${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_YELLOW}Run 'chief.config' to create your configuration file first.${CHIEF_NO_COLOR}"
    return 1
  fi
  
  local template_file="${CHIEF_PATH}/templates/chief_config_template.sh"
  if [[ ! -f "$template_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error: Config template not found: $template_file${CHIEF_NO_COLOR}"
    return 1
  fi

  echo -e "${CHIEF_COLOR_CYAN}Chief Configuration Update${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_CYAN}=========================${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_BLUE}Current config:${CHIEF_NO_COLOR} $CHIEF_CONFIG"
  echo -e "${CHIEF_COLOR_BLUE}Template:${CHIEF_NO_COLOR} $template_file"
  echo

  # Parse template and user config first to determine if changes are needed
  echo -e "${CHIEF_COLOR_BLUE}Analyzing configuration files...${CHIEF_NO_COLOR}"
  
  local template_options user_options
  template_options=$(__chief_parse_config_template "$template_file") || {
    echo -e "${CHIEF_COLOR_RED}Error: Failed to parse template config${CHIEF_NO_COLOR}"
    return 1
  }
  
  user_options=$(__chief_parse_user_config "$CHIEF_CONFIG") || {
    echo -e "${CHIEF_COLOR_RED}Error: Failed to parse user config${CHIEF_NO_COLOR}"
    return 1
  }

  # Build associative arrays for easier lookup
  declare -A template_vars template_status user_vars user_status renames
  
  # Load rename mappings
  local rename_line
  while IFS= read -r rename_line; do
    if [[ "$rename_line" =~ ^([^:]+):([^:]+)$ ]]; then
      renames["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  done < <(__chief_get_config_renames)
  
  # Load template variables
  while IFS='|' read -r var_name var_value is_commented comments; do
    template_vars["$var_name"]="$var_value"
    template_status["$var_name"]="$is_commented"
  done <<< "$template_options"
  
  # Load user variables  
  while IFS='|' read -r var_name var_value status; do
    user_vars["$var_name"]="$var_value"
    user_status["$var_name"]="$status"
  done <<< "$user_options"

  # Find changes needed
  local changes_needed=false
  local -a new_options=()
  local -a renamed_options=()
  
  # Check for new options in template
  for template_var in "${!template_vars[@]}"; do
    if [[ -z "${user_vars[$template_var]:-}" ]]; then
      new_options+=("$template_var")
      changes_needed=true
    fi
  done
  
  # Check for renamed options
  for old_var in "${!renames[@]}"; do
    local new_var="${renames[$old_var]}"
    if [[ -n "${user_vars[$old_var]:-}" && -z "${user_vars[$new_var]:-}" ]]; then
      renamed_options+=("$old_var -> $new_var")
      changes_needed=true
    fi
  done

  # Display what will be changed
  if [[ ${#new_options[@]} -gt 0 ]]; then
    echo -e "\n${CHIEF_COLOR_GREEN}New options to be added:${CHIEF_NO_COLOR}"
    printf '  • %s\n' "${new_options[@]}"
  fi
  
  if [[ ${#renamed_options[@]} -gt 0 ]]; then
    echo -e "\n${CHIEF_COLOR_YELLOW}Options to be renamed:${CHIEF_NO_COLOR}"
    printf '  • %s\n' "${renamed_options[@]}"
  fi

  if ! $changes_needed && ! $force_update; then
    echo -e "\n${CHIEF_COLOR_GREEN}✓ Your configuration is already up-to-date!${CHIEF_NO_COLOR}"
    return 0
  fi

  if $dry_run; then
    echo -e "\n${CHIEF_COLOR_CYAN}Dry run completed. Use without --dry-run to apply changes.${CHIEF_NO_COLOR}"
    return 0
  fi

  # Create backup only if changes are needed and backup is enabled
  local backup_file=""
  local backup_enabled="${CHIEF_CFG_CONFIG_UPDATE_BACKUP:-true}"
  if ! $no_backup && [[ "$backup_enabled" == "true" ]]; then
    backup_file="${CHIEF_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${CHIEF_COLOR_YELLOW}Creating backup: ${backup_file}${CHIEF_NO_COLOR}"
    cp "$CHIEF_CONFIG" "$backup_file" || {
      echo -e "${CHIEF_COLOR_RED}Error: Failed to create backup${CHIEF_NO_COLOR}"
      return 1
    }
  elif [[ "$backup_enabled" != "true" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Backup skipped (CHIEF_CFG_CONFIG_UPDATE_BACKUP=false)${CHIEF_NO_COLOR}"
  fi

  if ! $force_update; then
    echo
    read -p "Apply these changes to your configuration? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Configuration update cancelled.${CHIEF_NO_COLOR}"
      return 0
    fi
  fi

  # Create updated config
  local temp_config="${CHIEF_CONFIG}.tmp.$$"
  
  echo -e "\n${CHIEF_COLOR_BLUE}Updating configuration...${CHIEF_NO_COLOR}"
  
  # Start with template structure and inject user values
  {
    while IFS='|' read -r var_name var_value template_is_commented comments; do
      # Print comments
      if [[ -n "$comments" ]]; then
        echo -e "$comments"
      fi
      
      # Handle renamed variables
      local user_value=""
      local old_var_for_status=""
      
      # Check if this is a renamed variable (new name)
      for old_var in "${!renames[@]}"; do
        if [[ "${renames[$old_var]}" == "$var_name" && -n "${user_vars[$old_var]:-}" ]]; then
          user_value="${user_vars[$old_var]}"
          old_var_for_status="$old_var"
          echo "# Renamed from $old_var"
          break
        fi
      done
      
      # Use existing user value if available
      if [[ -z "$user_value" && -n "${user_vars[$var_name]:-}" ]]; then
        user_value="${user_vars[$var_name]}"
      fi
      
      # Use template default if no user value
      if [[ -z "$user_value" ]]; then
        user_value="$var_value"
      fi
      
      # Determine if should be commented
      local comment_prefix=""
      local check_var="$var_name"
      
      # For renamed variables, check the old variable's status
      if [[ -n "$old_var_for_status" ]]; then
        check_var="$old_var_for_status"
      fi
      
      # Use user's existing status if available, otherwise use template status
      local var_status="${user_status[$check_var]:-$template_is_commented}"
      if [[ "$var_status" == "commented" ]]; then
        comment_prefix="#"
      fi
      
      echo "${comment_prefix}${var_name}=${user_value}"
      echo
    done <<< "$template_options"
    
    # Add any user variables not in template (custom additions)
    for user_var in "${!user_vars[@]}"; do
      if [[ -z "${template_vars[$user_var]:-}" ]]; then
        # Skip if this was a renamed variable (old name)
        local skip_old=false
        for old_var in "${!renames[@]}"; do
          if [[ "$old_var" == "$user_var" ]]; then
            skip_old=true
            break
          fi
        done
        
        if ! $skip_old; then
          echo "# Custom user variable (not in template)"
          local comment_prefix=""
          [[ "${user_status[$user_var]}" == "commented" ]] && comment_prefix="#"
          echo "${comment_prefix}${user_var}=${user_vars[$user_var]}"
          echo
        fi
      fi
    done
    
  } > "$temp_config"
  
  # Validate the new config by checking syntax
  if ! bash -n "$temp_config" 2>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error: Generated configuration has syntax errors${CHIEF_NO_COLOR}"
    rm -f "$temp_config"
    return 1
  fi
  
  # Apply the changes
  mv "$temp_config" "$CHIEF_CONFIG" || {
    echo -e "${CHIEF_COLOR_RED}Error: Failed to update configuration file${CHIEF_NO_COLOR}"
    rm -f "$temp_config"
    return 1
  }
  
  echo -e "${CHIEF_COLOR_GREEN}✓ Configuration updated successfully${CHIEF_NO_COLOR}"
  
  if [[ -n "$backup_file" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}✓ Backup saved: ${backup_file}${CHIEF_NO_COLOR}"
  fi
  
  # Reload Chief configuration
  echo -e "\n${CHIEF_COLOR_BLUE}Reloading Chief...${CHIEF_NO_COLOR}"
  if __chief_load_library --verbose; then
    echo -e "${CHIEF_COLOR_GREEN}✓ Chief reloaded successfully with updated configuration${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_YELLOW}⚠ Configuration updated but reload had issues${CHIEF_NO_COLOR}"
  fi
  
  echo
  echo -e "${CHIEF_COLOR_CYAN}Configuration update complete!${CHIEF_NO_COLOR}"
  if [[ ${#new_options[@]} -gt 0 ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Added ${#new_options[@]} new configuration option(s)${CHIEF_NO_COLOR}"
  fi
  if [[ ${#renamed_options[@]} -gt 0 ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Renamed ${#renamed_options[@]} configuration option(s)${CHIEF_NO_COLOR}"
  fi
}

function chief.plugins-root() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Change directory (cd) into the Chief plugins directory.

${CHIEF_COLOR_GREEN}Plugin Directory Types:${CHIEF_NO_COLOR}
- Local plugins: ~/chief_plugins/ (default)
- Remote plugins: Git repository clone location
- Custom: User-defined CHIEF_CFG_PLUGINS path

${CHIEF_COLOR_BLUE}Current Plugin Directory:${CHIEF_NO_COLOR}
$CHIEF_CFG_PLUGINS

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME        # Navigate to plugins directory
  ls -la          # List all plugin files
  vim my_plugin   # Edit a plugin file
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  # Determine the correct plugin directory based on plugin type
  local plugin_dir
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" && -n ${CHIEF_CFG_PLUGINS_GIT_PATH} ]]; then
    plugin_dir="${CHIEF_CFG_PLUGINS_PATH}/${CHIEF_CFG_PLUGINS_GIT_PATH}"
  else
    plugin_dir=${CHIEF_CFG_PLUGINS_PATH}
  fi

  if [[ ! -d "$plugin_dir" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Plugin directory does not exist: $plugin_dir"
    echo -e "${CHIEF_COLOR_BLUE}Creating directory...${CHIEF_NO_COLOR}"
    mkdir -p "$plugin_dir"
  fi

  cd "$plugin_dir"
  echo -e "${CHIEF_COLOR_GREEN}Changed directory to plugin directory: $plugin_dir${CHIEF_NO_COLOR}"
}

function chief.plugin() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [OPTIONS] [plugin_name]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit a Chief plugin file with automatic reload on changes.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  plugin_name  Name of plugin to edit (without _chief-plugin.sh suffix)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --code, --vscode  Use VSCode editor (requires 'code' command)
  -?, --help      Show this help

${CHIEF_COLOR_GREEN}Available Plugins:${CHIEF_NO_COLOR}
$(__chief_get_plugins)

${CHIEF_COLOR_MAGENTA}Plugin Naming Convention:${CHIEF_NO_COLOR}
- File format: <name>_chief-plugin.sh
- Function format: <name>.<function_name>()
- Must be executable and sourced

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Edit default plugin
  $FUNCNAME mytools            # Edit mytools_chief-plugin.sh
  $FUNCNAME --code aws         # Edit aws_chief-plugin.sh with VSCode
  $FUNCNAME --vscode mytools   # Edit mytools_chief-plugin.sh with VSCode

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your preferred editor (vi by default)
- VSCode support with --code/--vscode flag
- Automatically reloads plugin on save
- Creates new plugin if it doesn't exist
"

  # Parse arguments
  local use_vscode=""
  local plugin_name=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      -\?|--help)
        echo -e "${USAGE}"
        return
        ;;
      --code|--vscode)
        use_vscode="vscode"
        shift
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error: Unknown option: $1${CHIEF_NO_COLOR}"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        plugin_name="$1"
        shift
        ;;
    esac
  done

  # Determine plugin name
  if [[ -z "$plugin_name" ]]; then
    plugin_name="default"
  fi

  __chief_edit_plugin "$plugin_name" "$use_vscode"
}

function chief.bash_profile() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit your ~/.bash_profile file with automatic reload on changes.

${CHIEF_COLOR_GREEN}What is .bash_profile:${CHIEF_NO_COLOR}
- Login shell initialization script
- Executed when you start a new terminal session
- Contains environment variables, aliases, functions
- Preferred over .bashrc for login shells

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your preferred \$EDITOR
- Automatically sources file on save
- Detects and reports syntax errors
- Creates file if it doesn't exist

${CHIEF_COLOR_MAGENTA}Best Practices:${CHIEF_NO_COLOR}
- Put personal variables here (not in shared plugins)
- Set PATH modifications
- Configure personal aliases and functions
- Source other configuration files

${CHIEF_COLOR_YELLOW}File Location:${CHIEF_NO_COLOR}
~/.bash_profile
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  chief.edit-file "$HOME/.bash_profile"
}

function chief.bashrc() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit your ~/.bashrc file with automatic reload on changes.

${CHIEF_COLOR_GREEN}What is .bashrc:${CHIEF_NO_COLOR}
- Non-login shell initialization script
- Executed for interactive non-login shells
- Contains aliases, functions, and interactive settings
- Sourced by terminal multiplexers and some terminals

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your preferred \$EDITOR
- Automatically sources file on save
- Detects and reports syntax errors
- Creates file if it doesn't exist

${CHIEF_COLOR_MAGENTA}Usage Notes:${CHIEF_NO_COLOR}
- .bash_profile is preferred for login shells (Chief recommendation)
- .bashrc is better for non-login interactive shells
- Some systems source .bashrc from .bash_profile

${CHIEF_COLOR_YELLOW}File Location:${CHIEF_NO_COLOR}
~/.bashrc

${CHIEF_COLOR_BLUE}Recommendation:${CHIEF_NO_COLOR}
Use chief.bash_profile for most Chief and personal configurations.
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  chief.edit-file "$HOME/.bashrc"
}

function chief.profile() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit your ~/.profile file with automatic reload on changes.

${CHIEF_COLOR_GREEN}What is .profile:${CHIEF_NO_COLOR}
- POSIX-compliant shell initialization script
- Executed by login shells (bash, dash, zsh, etc.)
- Contains environment variables and paths
- Most portable shell configuration file

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your preferred \$EDITOR
- Automatically sources file on save
- Detects and reports syntax errors
- Creates file if it doesn't exist

${CHIEF_COLOR_MAGENTA}Compatibility:${CHIEF_NO_COLOR}
- Works with any POSIX-compliant shell
- Avoid bash-specific features in this file
- Use for environment variables and paths
- Shell-agnostic configurations

${CHIEF_COLOR_YELLOW}File Location:${CHIEF_NO_COLOR}
~/.profile

${CHIEF_COLOR_BLUE}Best Practice:${CHIEF_NO_COLOR}
Use ~/.profile for cross-shell environment settings and ~/.bash_profile for bash-specific configurations.
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  chief.edit-file "$HOME/.profile"
}

function chief.reload() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Reload the entire Chief utility library and environment with verbose output.

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Reloads all Chief core libraries and plugins
- Refreshes environment variables and functions
- Updates configuration changes
- Provides verbose feedback during reload

${CHIEF_COLOR_BLUE}Use Cases:${CHIEF_NO_COLOR}
- After modifying Chief configuration
- When plugins are added or updated
- After updating Chief installation
- Troubleshooting environment issues

${CHIEF_COLOR_MAGENTA}What Gets Reloaded:${CHIEF_NO_COLOR}
- Chief core library functions
- All configured plugins
- Environment variables
- Color schemes and prompts
- SSH key configurations

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Reload Chief environment
  chief.config && $FUNCNAME   # Edit config then reload

${CHIEF_COLOR_BLUE}Alternative:${CHIEF_NO_COLOR}
Restart your terminal session for a complete reset.
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_BLUE}Reloading Chief environment...${CHIEF_NO_COLOR}"
  __chief_load_library --verbose
  echo -e "${CHIEF_COLOR_GREEN}Chief environment reloaded successfully${CHIEF_NO_COLOR}"
}

# Show Chief statistics and status
function __chief_show_chief_stats() {
  local total_functions=$(compgen -A function | grep "^chief\." | wc -l | tr -d ' ')
  local loaded_plugins=$(__chief_get_plugins)
  local plugin_count=0
  
  if [[ -n "$loaded_plugins" ]]; then
    plugin_count=$(echo "$loaded_plugins" | tr ',' '\n' | wc -l | tr -d ' ')
  fi
  
  echo -e "${CHIEF_COLOR_BLUE}Chief Status:${CHIEF_NO_COLOR}"
  echo -e "• Functions available: ${CHIEF_COLOR_CYAN}$total_functions${CHIEF_NO_COLOR}"
  echo -e "• Plugins loaded: ${CHIEF_COLOR_CYAN}$plugin_count${CHIEF_NO_COLOR} ($loaded_plugins)"
  echo -e "• Configuration: ${CHIEF_COLOR_CYAN}$CHIEF_CONFIG${CHIEF_NO_COLOR}"
}

# Show core Chief commands
function __chief_show_core_commands() {
  echo -e "${CHIEF_COLOR_YELLOW}Core Chief Commands:${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Configuration & Setup:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR}        Edit Chief configuration file"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.config-set${CHIEF_NO_COLOR}    Set configuration variables directly"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.config-update${CHIEF_NO_COLOR} Update config with new options from template"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.reload${CHIEF_NO_COLOR}        Reload Chief environment"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.update${CHIEF_NO_COLOR}        Update Chief to latest version"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.uninstall${CHIEF_NO_COLOR}     Remove Chief from system"
  echo
  echo -e "${CHIEF_COLOR_CYAN}File Management:${CHIEF_NO_COLOR} ${CHIEF_COLOR_BLUE}(auto-reloads after editing)${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.edit-file${CHIEF_NO_COLOR}     Edit any file with auto-reload detection"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.bash_profile${CHIEF_NO_COLOR}  Edit ~/.bash_profile"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.bashrc${CHIEF_NO_COLOR}        Edit ~/.bashrc"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.profile${CHIEF_NO_COLOR}       Edit ~/.profile"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Plugin Management:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugins-root${CHIEF_NO_COLOR}   Navigate to plugins directory"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugin${CHIEF_NO_COLOR}        Create/edit plugins"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugin -?${CHIEF_NO_COLOR}     List available plugins"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Utilities:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.whereis${CHIEF_NO_COLOR}       Find aliases, functions, and variables"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.hints${CHIEF_NO_COLOR}         Show quick tips and workflow"
  echo
  echo -e "${CHIEF_COLOR_BLUE}Usage tip:${CHIEF_NO_COLOR} All commands support ${CHIEF_COLOR_GREEN}-?${CHIEF_NO_COLOR} or ${CHIEF_COLOR_GREEN}--help${CHIEF_NO_COLOR} for detailed help"
}

# Show plugin-related help
function __chief_show_plugin_help() {
  echo -e "${CHIEF_COLOR_YELLOW}Plugin Management:${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR} All commands below should be prefixed with ${CHIEF_COLOR_GREEN}chief.${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Plugin Commands:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}plugins${CHIEF_NO_COLOR}              Navigate to plugins directory"
  echo -e "  ${CHIEF_COLOR_GREEN}plugin${CHIEF_NO_COLOR}               Edit default plugin"
  echo -e "  ${CHIEF_COLOR_GREEN}plugin <name>${CHIEF_NO_COLOR}        Create/edit named plugin"
  echo -e "  ${CHIEF_COLOR_GREEN}plugin -?${CHIEF_NO_COLOR}            List all plugins"
  echo
  
  local loaded_plugins=$(__chief_get_plugins)
  if [[ -n "$loaded_plugins" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Currently Loaded Plugins:${CHIEF_NO_COLOR}"
    echo -e "  ${CHIEF_COLOR_CYAN}$loaded_plugins${CHIEF_NO_COLOR}"
    echo
  fi
  
  echo -e "${CHIEF_COLOR_CYAN}Available Plugin Functions:${CHIEF_NO_COLOR}"
  
  # Check for each plugin category and show organized functions
  local found_plugins=false
  
  if compgen -A function | grep -q "^chief\.git_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}Git Plugin:${CHIEF_NO_COLOR}"
    echo "    git_branch, git_commit, git_clone, git_tag, git_delete-branch"
    echo "    git_delete-tag, git_legend, git_rename-branch, git_reset-soft"
    echo "    git_reset-hard, git_set-url, git_untrack, git_update, git_cred-cache"
    echo "    git_amend, git_url"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.ssl_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}SSL Plugin:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(requires openssl)${CHIEF_NO_COLOR}"
    echo "    ssl_create-ca, ssl_create-tls-cert, ssl_renew-tls-cert, ssl_view-cert, ssl_get-cert"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.vault_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}Vault Plugin:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(requires ansible-vault)${CHIEF_NO_COLOR}"
    echo "    vault_file-edit, vault_file-load"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.aws_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}AWS Plugin:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(requires aws CLI)${CHIEF_NO_COLOR}"
    echo "    aws_set-role, aws_export-creds"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.ssh_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}SSH Plugin:${CHIEF_NO_COLOR}"
    echo "    ssh_create-keypair, ssh_get-publickey, ssh_rm-host, ssh_load_keys"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.python_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}Python Plugin:${CHIEF_NO_COLOR}"
    echo "    python_create-ve, python_start-ve, python_stop-ve, python_ve-dep"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.oc_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}OpenShift Plugin:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(requires oc CLI)${CHIEF_NO_COLOR}"
    echo "    oc_login, oc_get-all-objects, oc_clean-olm, oc_clean-replicasets"
    echo "    oc_approve-csrs, oc_show-stuck-resources, oc_delete-stuck-ns"
    echo "    OpenShift cluster management and maintenance"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.etc_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}Utilities Plugin:${CHIEF_NO_COLOR}"
    echo "    etc_ask-yes-or-no, etc_spinner, etc_prompt, etc_mount-share"
    echo "    etc_isvalid-ip, etc_broadcast, etc_at-run, etc_folder-diff"
    echo "    etc_shared-term_create, etc_shared-term_connect, etc_chmod-f, etc_chmod-d"
    echo "    etc_create-bootusb, etc_copy-dotfiles, etc_create-cipher, type-writer"
    found_plugins=true
  fi
  
  if [[ "$found_plugins" == false ]]; then
    echo -e "  ${CHIEF_COLOR_YELLOW}No plugin functions loaded yet${CHIEF_NO_COLOR}"
    echo
    echo -e "${CHIEF_COLOR_BLUE}To get started:${CHIEF_NO_COLOR}"
    echo -e "  • Run ${CHIEF_COLOR_GREEN}chief.plugin -?${CHIEF_NO_COLOR} to see available plugins"
    echo -e "  • Create your first plugin: ${CHIEF_COLOR_GREEN}chief.plugin mytools${CHIEF_NO_COLOR}"
  fi
  
  echo
  echo -e "${CHIEF_COLOR_BLUE}Plugin Development:${CHIEF_NO_COLOR}"
  echo -e "• Plugin location: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PLUGINS_PATH:-~/.chief_plugins}${CHIEF_NO_COLOR}"
  echo -e "• Template: ${CHIEF_COLOR_CYAN}${CHIEF_DEFAULT_PLUGIN_TEMPLATE}${CHIEF_NO_COLOR}"
  echo -e "• Edit config: ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR} to set CHIEF_CFG_PLUGINS_PATH"
}

# Show configuration help
function __chief_show_configuration_help() {
  echo -e "${CHIEF_COLOR_YELLOW}Chief Configuration:${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR} All configuration variables below should be prefixed with ${CHIEF_COLOR_GREEN}CHIEF_CFG_${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Configuration File:${CHIEF_NO_COLOR}"
  echo -e "  Location: ${CHIEF_COLOR_CYAN}$CHIEF_CONFIG${CHIEF_NO_COLOR}"
  echo -e "  Edit: ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR}"
  echo -e "  Set directly: ${CHIEF_COLOR_GREEN}chief.config_set <option> <value>${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(omit CHIEF_CFG_ prefix)${CHIEF_NO_COLOR}"
  echo
  
  echo -e "${CHIEF_COLOR_CYAN}Display & Interface:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}BANNER${CHIEF_NO_COLOR}               Show/hide startup banner (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}HINTS${CHIEF_NO_COLOR}                Show/hide startup hints (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}VERBOSE${CHIEF_NO_COLOR}              Enable verbose output (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}COLORED_LS${CHIEF_NO_COLOR}           Enable colored ls output (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}CONFIG_SET_INTERACTIVE${CHIEF_NO_COLOR} Enable confirmation prompts for config_set (true/false)"
  echo
  
  echo -e "${CHIEF_COLOR_CYAN}Prompt Configuration:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}PROMPT${CHIEF_NO_COLOR}               Enable/disable Chief prompt (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}COLORED_PROMPT${CHIEF_NO_COLOR}       Enable colored prompts (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}GIT_PROMPT${CHIEF_NO_COLOR}           Show git status in prompt (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}MULTILINE_PROMPT${CHIEF_NO_COLOR}     Use multi-line prompt layout (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}SHORT_PATH${CHIEF_NO_COLOR}           Show short paths in prompt (true/false)"
  echo
  
  echo -e "${CHIEF_COLOR_CYAN}Plugin Management:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}PLUGINS${CHIEF_NO_COLOR}              Plugin directory path"
  echo -e "  ${CHIEF_COLOR_GREEN}PLUGINS_TYPE${CHIEF_NO_COLOR}         Plugin type (local/remote)"
  echo -e "  ${CHIEF_COLOR_GREEN}PLUGIN_DEFAULT${CHIEF_NO_COLOR}       Default plugin file path"
  echo -e "  ${CHIEF_COLOR_GREEN}PLUGIN_TEMPLATE${CHIEF_NO_COLOR}      Plugin template file path"
  echo
  
  echo -e "${CHIEF_COLOR_CYAN}Remote Plugin Options:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(when PLUGINS_TYPE=remote)${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}PLUGINS_GIT_REPO${CHIEF_NO_COLOR}     Git repository URL for remote plugins"
  echo -e "  ${CHIEF_COLOR_GREEN}PLUGINS_GIT_BRANCH${CHIEF_NO_COLOR}   Git branch to use (default: main)"
  echo -e "  ${CHIEF_COLOR_GREEN}PLUGINS_GIT_PATH${CHIEF_NO_COLOR}     Local path for remote plugin cache"
  echo -e "  ${CHIEF_COLOR_GREEN}PLUGINS_GIT_AUTOUPDATE${CHIEF_NO_COLOR} Auto-update remote plugins (true/false)"
  echo
  
  echo -e "${CHIEF_COLOR_CYAN}System & Security:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}AUTOCHECK_UPDATES${CHIEF_NO_COLOR}    Auto-check for Chief updates (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}SSH_KEYS_PATH${CHIEF_NO_COLOR}        Path to SSH keys directory (keys must end in .key)"
  echo -e "  ${CHIEF_COLOR_GREEN}ALIAS${CHIEF_NO_COLOR}                Custom alias for chief commands"
  echo
  
  echo -e "${CHIEF_COLOR_CYAN}Current Settings:${CHIEF_NO_COLOR}"
  echo -e "  Prompt: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PROMPT:-false}${CHIEF_NO_COLOR} | Git prompt: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_GIT_PROMPT:-true}${CHIEF_NO_COLOR} | Multi-line: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_MULTILINE_PROMPT:-false}${CHIEF_NO_COLOR}"
  echo -e "  Short path: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_SHORT_PATH:-false}${CHIEF_NO_COLOR} | Hints: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_HINTS:-true}${CHIEF_NO_COLOR} | Banner: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_BANNER:-true}${CHIEF_NO_COLOR}"
  echo -e "  Plugins type: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PLUGINS_TYPE:-local}${CHIEF_NO_COLOR} | Auto-update: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_AUTOCHECK_UPDATES:-false}${CHIEF_NO_COLOR}"
  if [[ -n "$CHIEF_CFG_ALIAS" ]]; then
    echo -e "  Custom alias: ${CHIEF_COLOR_CYAN}$CHIEF_CFG_ALIAS${CHIEF_NO_COLOR}"
  fi
  if [[ "$CHIEF_CFG_PLUGINS_TYPE" == "remote" ]]; then
    echo -e "  Remote repo: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PLUGINS_GIT_REPO:-not set}${CHIEF_NO_COLOR}"
    echo -e "  Remote branch: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PLUGINS_GIT_BRANCH:-main}${CHIEF_NO_COLOR}"
    echo -e "  Remote auto-update: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE:-false}${CHIEF_NO_COLOR}"
  fi
  echo
  
  echo -e "${CHIEF_COLOR_BLUE}Configuration Commands:${CHIEF_NO_COLOR}"
  echo -e "• Edit config file: ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR}"
  echo -e "• Set config directly: ${CHIEF_COLOR_GREEN}chief.config_set <option> <value>${CHIEF_NO_COLOR}"
  echo -e "• List all config vars: ${CHIEF_COLOR_GREEN}chief.config_set --list${CHIEF_NO_COLOR}"
  echo -e "• Update config with latest options: ${CHIEF_COLOR_GREEN}chief.config_update${CHIEF_NO_COLOR}"
  echo -e "• View current config: ${CHIEF_COLOR_GREEN}cat $CHIEF_CONFIG${CHIEF_NO_COLOR}"
  echo -e "• Reload after changes: ${CHIEF_COLOR_GREEN}chief.reload${CHIEF_NO_COLOR}"
  echo -e "• Test prompt: ${CHIEF_COLOR_GREEN}chief.git.legend${CHIEF_NO_COLOR} (if git prompt enabled)"
  echo
  echo -e "${CHIEF_COLOR_BLUE}Configuration Examples:${CHIEF_NO_COLOR}"
  echo -e "• ${CHIEF_COLOR_GREEN}chief.config_set banner false${CHIEF_NO_COLOR}     # Disable startup banner (with prompt)"
  echo -e "• ${CHIEF_COLOR_GREEN}chief.config_set --yes prompt true${CHIEF_NO_COLOR}      # Enable Chief prompt (no prompt)"  
  echo -e "• ${CHIEF_COLOR_GREEN}chief.config_set colored_ls true${CHIEF_NO_COLOR}  # Enable colored ls (with prompt)"
  echo -e "• ${CHIEF_COLOR_GREEN}chief.config_set config_set_interactive false${CHIEF_NO_COLOR} # Disable prompts globally"
}

# Show compact command reference
function __chief_show_compact_reference() {
  echo -e "${CHIEF_COLOR_YELLOW}Chief Quick Reference:${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR} All commands below should be prefixed with ${CHIEF_COLOR_GREEN}chief.${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Core Commands:${CHIEF_NO_COLOR}"
  echo "  config, config_set, reload, update, uninstall, whereis, hints, help"
  echo
  echo -e "${CHIEF_COLOR_CYAN}File Editors:${CHIEF_NO_COLOR}"
  echo "  edit-file, bash_profile, bashrc, profile"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Plugin Management:${CHIEF_NO_COLOR}"
  echo "  plugin [name], plugins_root (navigate), plugin -? (list)"
  echo
  
  # Show loaded plugin categories
  local loaded_plugins=$(__chief_get_plugins)
  if [[ -n "$loaded_plugins" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Loaded Plugins:${CHIEF_NO_COLOR}"
    
    # Check for common plugin types and show them organized
    local plugin_categories=()
    
    if compgen -A function | grep -q "^chief\.git\."; then
      plugin_categories+=("git (git.branch, git.commit, git.clone, git.legend)")
    fi
    
    if compgen -A function | grep -q "^chief\.vault"; then
      plugin_categories+=("vault (vault.file-edit, vault.file-load) *requires ansible-vault")
    fi
    
    if compgen -A function | grep -q "^chief\.ssh"; then
      plugin_categories+=("ssh (ssh.create_keypair, ssh.get_publickey)")
    fi
    
    if compgen -A function | grep -q "^chief\.python"; then
      plugin_categories+=("python (python.create_ve, python.start_ve, python.stop_ve)")
    fi
    
    if compgen -A function | grep -q "^chief\.oc\."; then
      plugin_categories+=("oc (oc.login, oc.clusters) *requires OpenShift CLI")
    fi
    
    if compgen -A function | grep -q "^chief\.etc"; then
      plugin_categories+=("etc (etc.folder_sync, etc.ask_yes_or_no, etc.spinner, etc.prompt)")
    fi
    
    if [[ ${#plugin_categories[@]} -gt 0 ]]; then
      for category in "${plugin_categories[@]}"; do
        echo "  $category"
      done
    else
      echo "  $loaded_plugins"
    fi
    echo
  else
    echo -e "${CHIEF_COLOR_CYAN}Plugins:${CHIEF_NO_COLOR}"
    echo "  No plugins loaded yet - try 'chief.plugin -?' to see available"
    echo
  fi
  
  echo -e "${CHIEF_COLOR_BLUE}Quick Tips:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.[tab][tab]${CHIEF_NO_COLOR} - see all commands"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.help${CHIEF_NO_COLOR} - detailed help system"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR} - customize settings"
}

# Search through Chief commands and help
function __chief_search_help() {
  local search_term="$1"
  
  if [[ -z "$search_term" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Please provide a search term"
    echo -e "${CHIEF_COLOR_BLUE}Usage:${CHIEF_NO_COLOR} chief.help --search <term>"
    return 1
  fi
  
  echo -e "${CHIEF_COLOR_CYAN}Searching for: ${CHIEF_COLOR_YELLOW}$search_term${CHIEF_NO_COLOR}"
  echo
  
  # Search function names
  local matching_functions=($(compgen -A function | grep -i "chief.*$search_term" | sort))
  if [[ ${#matching_functions[@]} -gt 0 ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Matching Functions:${CHIEF_NO_COLOR}"
    for func in "${matching_functions[@]}"; do
      echo -e "  ${CHIEF_COLOR_CYAN}$func${CHIEF_NO_COLOR}"
    done
    echo
  fi
  
  # Search aliases
  local matching_aliases=($(compgen -A alias | grep -i "chief.*$search_term" | sort))
  if [[ ${#matching_aliases[@]} -gt 0 ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Matching Aliases:${CHIEF_NO_COLOR}"
    for alias_name in "${matching_aliases[@]}"; do
      echo -e "  ${CHIEF_COLOR_CYAN}$alias_name${CHIEF_NO_COLOR}"
    done
    echo
  fi
  
  if [[ ${#matching_functions[@]} -eq 0 && ${#matching_aliases[@]} -eq 0 ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}No matches found for '$search_term'${CHIEF_NO_COLOR}"
    echo
    echo -e "${CHIEF_COLOR_BLUE}Try:${CHIEF_NO_COLOR}"
    echo -e "• ${CHIEF_COLOR_GREEN}chief.help commands${CHIEF_NO_COLOR} - see all core commands"
    echo -e "• ${CHIEF_COLOR_GREEN}chief.help plugins${CHIEF_NO_COLOR} - see plugin commands"
    echo -e "• ${CHIEF_COLOR_GREEN}chief.[tab][tab]${CHIEF_NO_COLOR} - bash completion"
  fi
}

function chief.whereis() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} chief.whereis <name>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Find where environment variables, functions, and aliases are defined across your system and Chief configuration.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  name    Name to search for (functions, variables, aliases)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -?, --help      Show this help

${CHIEF_COLOR_GREEN}Search Locations:${CHIEF_NO_COLOR}
  ${CHIEF_COLOR_MAGENTA}System Startup Scripts:${CHIEF_NO_COLOR}
    • ~/.bashrc, ~/.bash_profile, ~/.bash_login, ~/.profile
    • /etc/bashrc, /etc/bash.bashrc, /etc/profile
    • ~/.bashrc.d/*.sh, ~/.bash/*.sh
    
  ${CHIEF_COLOR_MAGENTA}Chief Core Files:${CHIEF_NO_COLOR}
    • \$CHIEF_CONFIG (your configuration)
    • \$CHIEF_PATH/chief.sh (main script)
    • \$CHIEF_PATH/libs/core/chief_library.sh (core library)
    • \$CHIEF_PATH/libs/core/plugins/*.sh (core plugins)
    
  ${CHIEF_COLOR_MAGENTA}User Plugin Directories:${CHIEF_NO_COLOR}
    • \$CHIEF_CFG_PLUGINS_PATH/*.sh (configured: ${CHIEF_CFG_PLUGINS_PATH:-"not set"})
    • ~/.chief_plugins/*.sh (default location)
    • ~/.local/share/chief/plugins/*.sh (XDG standard)

${CHIEF_COLOR_BLUE}Search Patterns:${CHIEF_NO_COLOR}
  Variables:  export VAR=, VAR=
  Functions:  function name(), name()
  Aliases:    alias name=

${CHIEF_COLOR_GREEN}Status Indicators:${CHIEF_NO_COLOR}
  ${CHIEF_SYMBOL_CHECK} Currently loaded and active
  ${CHIEF_SYMBOL_CROSS} Found in files but not loaded

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.whereis PATH           # Find PATH variable
  chief.whereis git_update     # Find git_update function  
  chief.whereis ll             # Find ll alias
  chief.whereis JAVA_HOME      # Find Java environment

${CHIEF_COLOR_BLUE}Output Features:${CHIEF_NO_COLOR}
- Shows exact file locations and line numbers
- Indicates if definitions are currently active
- Warns about duplicate definitions
- Cross-references runtime status with file locations"

  if [[ -z $1 ]] || [[ $1 == "-?" ]] || [[ $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return
  fi

  local name="$1"
  local total_found=0
  
  # Build search file list
  local search_files=()
  
  # System startup scripts
  for file in ~/.bashrc ~/.bash_profile ~/.bash_login ~/.profile /etc/bashrc /etc/bash.bashrc /etc/profile; do
    [[ -f "$file" ]] && search_files+=("$file")
  done
  
  # Shell config directories  
  for dir in ~/.bashrc.d ~/.bash; do
    if [[ -d "$dir" ]]; then
      while IFS= read -r -d '' file; do
        search_files+=("$file")
      done < <(find "$dir" -name "*.sh" -o -name "*.bash" -type f -print0 2>/dev/null)
    fi
  done
  
  # Chief core files
  for file in "${CHIEF_CONFIG}" "${CHIEF_PATH}/chief.sh" "${CHIEF_PATH}/libs/core/chief_library.sh"; do
    [[ -f "$file" ]] && search_files+=("$file")
  done
  
  # Chief core plugins
  if [[ -d "${CHIEF_PATH}/libs/core/plugins" ]]; then
    while IFS= read -r -d '' file; do
      search_files+=("$file")
    done < <(find "${CHIEF_PATH}/libs/core/plugins" -name "*.sh" -type f -print0 2>/dev/null)
  fi
  
  # User plugins
  # Determine the correct plugin directory for search
  local configured_plugin_dir
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" && -n ${CHIEF_CFG_PLUGINS_GIT_PATH} ]]; then
    configured_plugin_dir="${CHIEF_CFG_PLUGINS_PATH}/${CHIEF_CFG_PLUGINS_GIT_PATH}"
  else
    configured_plugin_dir=${CHIEF_CFG_PLUGINS_PATH}
  fi
  
  for plugin_dir in "${configured_plugin_dir}" ~/.chief_plugins ~/.local/share/chief/plugins; do
    if [[ -n "$plugin_dir" && -d "$plugin_dir" ]]; then
      while IFS= read -r -d '' file; do
        search_files+=("$file")
      done < <(find "$plugin_dir" -name "*.sh" -type f -print0 2>/dev/null)
    fi
  done

  echo -e "${CHIEF_COLOR_CYAN}Searching for: ${CHIEF_COLOR_YELLOW}${name}${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_CYAN}Checking ${#search_files[@]} files...${CHIEF_NO_COLOR}"
  echo

  # Search all files for definitions
  for file in "${search_files[@]}"; do
    if [[ -f "$file" && -r "$file" ]]; then
      local matches
      # Search for: export VAR=, VAR=, function VAR(), VAR(), alias VAR=
      matches=$(grep -n -E "(^|[[:space:]])(export[[:space:]]+${name}[=[:space:]]|${name}[[:space:]]*=|function[[:space:]]+${name}[[:space:]]*\\(|${name}[[:space:]]*\\(|alias[[:space:]]+${name}[=[:space:]])" "$file" 2>/dev/null)
      
      if [[ -n "$matches" ]]; then
        echo -e "${CHIEF_COLOR_GREEN}Found in:${CHIEF_NO_COLOR} $file"
        while IFS=: read -r line_num line_content; do
          echo -e "  ${CHIEF_COLOR_CYAN}Line ${line_num}:${CHIEF_NO_COLOR} ${line_content}"
          ((total_found++))
        done <<< "$matches"
        echo
      fi
    fi
  done

  # Check current runtime status
  local is_var=false is_func=false is_alias=false
  
  # Environment variable (only check if valid bash variable name)
  if [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && [[ -n "${!name}" ]]; then
    is_var=true
  fi
  
  # Function
  if declare -f "$name" >/dev/null 2>&1; then
    is_func=true
  fi
  
  # Alias
  if alias "$name" >/dev/null 2>&1; then
    is_alias=true
  fi

  # Show runtime status
  if $is_var || $is_func || $is_alias; then
    echo -e "${CHIEF_COLOR_GREEN}CURRENTLY LOADED:${CHIEF_NO_COLOR}"
    
    if $is_var; then
      echo -e "  ${CHIEF_SYMBOL_CHECK} Variable: ${name}=${!name}"
    fi
    
    if $is_func; then
      echo -e "  ${CHIEF_SYMBOL_CHECK} Function: ${name}()"
    fi
    
    if $is_alias; then
      local alias_def
      alias_def=$(alias "$name" 2>/dev/null)
      echo -e "  ${CHIEF_SYMBOL_CHECK} Alias: ${alias_def}"
    fi
    echo
  fi

  # Summary
  if [[ $total_found -eq 0 ]]; then
    echo -e "${CHIEF_COLOR_RED}No definitions found for '${name}'${CHIEF_NO_COLOR}"
    if ! $is_var && ! $is_func && ! $is_alias; then
      echo -e "${CHIEF_COLOR_YELLOW}Not currently loaded in memory${CHIEF_NO_COLOR}"
    fi
  else
    echo -e "${CHIEF_COLOR_GREEN}Found ${total_found} definition(s)${CHIEF_NO_COLOR}"
    if [[ $total_found -gt 1 ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}WARNING: Multiple definitions detected${CHIEF_NO_COLOR}"
    fi
    
    if ! $is_var && ! $is_func && ! $is_alias; then
      echo -e "${CHIEF_COLOR_YELLOW}Found in files but not currently loaded${CHIEF_NO_COLOR}"
    fi
  fi
}

########################################################################
# DEVELOPMENT FUNCTIONS - NOT FOR USER USE
########################################################################

# INTERNAL: Version bump function for Chief development
function __chief.bump() {
  local usage="Usage: $FUNCNAME <new_version> [--dry-run] [--backup]

${CHIEF_COLOR_RED}WARNING: DEVELOPMENT FUNCTION ONLY${CHIEF_NO_COLOR}
This function is for Chief developers only and modifies core files.

Arguments:
  new_version    Version to bump to (e.g., v4.0, v4.0.0) - MUST start with 'v'
                 OR use special keywords: 'release' or 'next-dev [target_version]'

Options:
  --dry-run     Show what would be changed without making changes
  --backup      Create backup files before modifying (default: no backups)
  --skip-tests  Skip test validation (NOT recommended for releases)
  
Examples:
  $FUNCNAME v4.0 --dry-run           # Preview changes
  $FUNCNAME v4.0.0                   # Bump version (no backups)
  $FUNCNAME v4.0.0 --backup          # Bump version with backups
  $FUNCNAME v4.1.0                   # Standard semantic version
  
  # For dev workflow:
  $FUNCNAME release                   # Convert v3.0.4-dev → v3.0.4 for release
  $FUNCNAME release --dry-run         # Preview release conversion
  $FUNCNAME release --skip-tests      # Emergency release without test validation (NOT recommended)
  $FUNCNAME next-dev                  # Convert v3.0.4 → v3.0.5-dev for next development cycle
  $FUNCNAME next-dev v3.1.1           # Convert v3.1.0 → v3.1.1-dev for patch development cycle
  $FUNCNAME next-dev --dry-run        # Preview next dev cycle setup
  
Note: This function only handles version updates. Create GitHub releases manually for tagging and publishing."

  # Parse arguments
  local new_version=""
  local target_version=""
  local dry_run=false
  local create_backups=false
  local skip_tests=false
  local positional_args=()
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-h)
        echo -e "$usage"
        return 0
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --backup)
        create_backups=true
        shift
        ;;
      --skip-tests)
        skip_tests=true
        shift
        ;;
      -*)
        __chief_print_error "Unknown option: $1"
        echo -e "$usage"
        return 1
        ;;
      *)
        positional_args+=("$1")
        shift
        ;;
    esac
  done
  
  # Handle positional arguments
  if [[ ${#positional_args[@]} -eq 0 ]]; then
    __chief_print_error "New version is required"
    echo -e "$usage"
    return 1
  elif [[ ${#positional_args[@]} -eq 1 ]]; then
    new_version="${positional_args[0]}"
  elif [[ ${#positional_args[@]} -eq 2 && "${positional_args[0]}" == "next-dev" ]]; then
    new_version="${positional_args[0]}"
    target_version="${positional_args[1]}"
  else
    __chief_print_error "Too many arguments"
    echo -e "$usage"
    return 1
  fi
  
  
  # Get current version early for keyword processing
  local current_version="$CHIEF_VERSION"
  
  # Handle special keywords
  if [[ "$new_version" == "release" ]]; then
    if [[ "$current_version" =~ ^(v[0-9]+\.[0-9]+(\.[0-9]+)?)-dev$ ]]; then
      new_version="${BASH_REMATCH[1]}"
      __chief_print_info "Release mode: Converting $current_version → $new_version"
    else
      __chief_print_error "Current version ($current_version) is not a -dev version"
      return 1
    fi
  elif [[ "$new_version" == "next-dev" ]]; then
    # Allow both release versions (v3.1.1) and dev versions (v3.1.1-dev) for next-dev workflow
    if [[ "$current_version" =~ ^v([0-9]+)\.([0-9]+)(\.([0-9]+))?(-dev)?$ ]]; then
      local major="${BASH_REMATCH[1]}"
      local minor="${BASH_REMATCH[2]}"
      local patch="${BASH_REMATCH[4]:-0}"
      
      if [[ -n "$target_version" ]]; then
        # Use provided target version
        if [[ ! "$target_version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
          __chief_print_error "Invalid target version format: $target_version"
          __chief_print_error "Expected format: v4.0 or v4.0.0 (must be prefixed with 'v')"
          return 1
        fi
        new_version="${target_version}-dev"
        __chief_print_info "Next dev mode: Converting $current_version → $new_version (custom target)"
      else
        # Auto-increment minor version for next development cycle
        ((minor++))
        new_version="v${major}.${minor}.0-dev"
        __chief_print_info "Next dev mode: Converting $current_version → $new_version (auto-increment)"
      fi
    else
      __chief_print_error "Current version ($current_version) is not a valid release version"
      return 1
    fi
  fi
  
  # Validate version format (MUST be prefixed with 'v')
  # Accept v4.0, v4.0.0 formats, and -dev versions for development workflow
  if [[ ! "$new_version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?(-dev)?$ ]]; then
    __chief_print_error "Invalid version format: $new_version"
    __chief_print_error "Expected format: v4.0 or v4.0.0 (must be prefixed with 'v'), optionally with -dev suffix"
    return 1
  fi
  
  # Normalize to full semantic version (add .0 if missing patch version)
  if [[ "$new_version" =~ ^v[0-9]+\.[0-9]+$ ]]; then
    new_version="${new_version}.0"
  fi
  
  # Test validation for releases only
  local is_release_workflow=false
  local is_next_dev_workflow=false
  
  if [[ "${positional_args[0]}" == "release" ]] || [[ ! "$new_version" =~ -dev$ ]]; then
    is_release_workflow=true
  elif [[ "${positional_args[0]}" == "next-dev" ]]; then
    is_next_dev_workflow=true
  fi
  
  # Only run tests for release workflows (next-dev skips tests since it follows a successful release)
  if ! $dry_run && ! $skip_tests && $is_release_workflow; then
    local test_script="${CHIEF_PATH}/test/run-tests.sh"
    
    if [[ -f "$test_script" ]]; then
      __chief_print_info "Running test suite (required for releases)..."
      
      if ! "$test_script"; then
        __chief_print_error "Test suite failed!"
        __chief_print_error "Cannot proceed with release while tests are failing."
        __chief_print_info "Fix failing tests or use --skip-tests (NOT recommended)"
        return 1
      else
        __chief_print_success "All tests passed! ✅"
        echo ""
      fi
    else
      __chief_print_warn "Test suite not found at: $test_script"
      __chief_print_warn "Proceeding without test validation (not recommended)"
    fi
  elif $skip_tests && $is_release_workflow; then
    __chief_print_warn "⚠️  SKIPPING TESTS FOR RELEASE - THIS IS DANGEROUS!"
    __chief_print_warn "Release versions should always pass tests before deployment."
    echo ""
  elif $is_next_dev_workflow; then
    __chief_print_info "Skipping tests for next-dev (tests passed in previous release cycle)"
    echo ""
  fi
  
  # Set version file path
  local version_file="${CHIEF_PATH}/VERSION"
  
  __chief_print_info "Chief Development Version Bump"
  __chief_print_info "Current version: $current_version"
  __chief_print_info "New version: $new_version"
  __chief_print_info "Dry run: $dry_run"
  echo ""
  
  # Check if versions are the same  
  if [[ "$current_version" == "$new_version" ]]; then
    __chief_print_warn "Version is already $new_version"
    if ! $dry_run; then
      __chief_print_info "Re-applying version to ensure consistency..."
    fi
  fi
  
  # Files to update with version references
  local files_to_update=(
    "${CHIEF_PATH}/VERSION"
    "${CHIEF_PATH}/README.md"
    "${CHIEF_PATH}/docs/index.md"
    "${CHIEF_PATH}/docs/getting-started.md"
  )
  
  # Special handling for next-dev workflow
  local is_next_dev=false
  if [[ "${positional_args[0]}" == "next-dev" ]]; then
    is_next_dev=true
    
    # Note: Using release-notes structure instead of UPDATES file
    if ! $dry_run; then
      __chief_print_info "Using release-notes structure for version tracking"
      
      # Update configuration for development workflow
      local config_file="${CHIEF_CONFIG}"
      if [[ -f "$config_file" ]]; then
        # Update UPDATE_BRANCH to dev for development workflow
        if grep -q "^CHIEF_CFG_UPDATE_BRANCH=" "$config_file"; then
          sed -i.tmp_config 's/^CHIEF_CFG_UPDATE_BRANCH=.*/CHIEF_CFG_UPDATE_BRANCH="dev"/' "$config_file"
          rm -f "${config_file}.tmp_config" 2>/dev/null
          __chief_print_info "Updated CHIEF_CFG_UPDATE_BRANCH to 'dev' for development workflow"
        else
          echo 'CHIEF_CFG_UPDATE_BRANCH="dev"' >> "$config_file"
          __chief_print_info "Added CHIEF_CFG_UPDATE_BRANCH='dev' to configuration"
        fi
      fi
      
      # Release notes will be managed manually in release-notes/ directory
    elif $dry_run; then
      __chief_print_info "Would update CHIEF_CFG_UPDATE_BRANCH to 'dev' for development workflow"
    fi
    
    # Create version-specific release notes file  
    local release_notes_dir="${CHIEF_PATH}/release-notes"
    local release_notes_file="${release_notes_dir}/${new_version}.md"
    
    if ! $dry_run; then
      # Ensure release-notes directory exists
      mkdir -p "$release_notes_dir"
      
      # Create new release notes file if it doesn't exist
      if [[ ! -f "$release_notes_file" ]]; then
        __chief_print_info "Creating new release notes: release-notes/${new_version}.md"
        
        cat > "$release_notes_file" << EOF
# Chief ${new_version} Release Notes

## 🚀 What's New

### 🔧 Version ${new_version} Development

- Ready for development work on ${new_version}

## 📋 Upgrade Notes

### For Developers

- This is a development version - features and changes will be documented as they are implemented

---

**Full details**: See [release-notes](../release-notes/) directory for complete changelog and version history.
EOF
      else
        __chief_print_info "Release notes file already exists: release-notes/${new_version}.md"
      fi
    fi
    
    if $dry_run; then
      __chief_print_info "Would create new release notes file: release-notes/${new_version}.md"
    fi
  fi

  # Special handling for release workflow - transform dev release notes to final
  if $is_release_workflow && [[ "${positional_args[0]}" == "release" ]]; then
    # Update configuration for release workflow
    if ! $dry_run; then
      local config_file="${CHIEF_CONFIG}"
      if [[ -f "$config_file" ]]; then
        # Update UPDATE_BRANCH to main for release workflow
        if grep -q "^CHIEF_CFG_UPDATE_BRANCH=" "$config_file"; then
          sed -i.tmp_config 's/^CHIEF_CFG_UPDATE_BRANCH=.*/CHIEF_CFG_UPDATE_BRANCH="main"/' "$config_file"
          rm -f "${config_file}.tmp_config" 2>/dev/null
          __chief_print_info "Updated CHIEF_CFG_UPDATE_BRANCH to 'main' for stable release tracking"
        else
          echo 'CHIEF_CFG_UPDATE_BRANCH="main"' >> "$config_file"
          __chief_print_info "Added CHIEF_CFG_UPDATE_BRANCH='main' to configuration"
        fi
      fi
    elif $dry_run; then
      __chief_print_info "Would update CHIEF_CFG_UPDATE_BRANCH to 'main' for stable release tracking"
    fi
    
    local release_notes_dir="${CHIEF_PATH}/release-notes"
    local dev_release_notes="${release_notes_dir}/${new_version}-dev.md"
    local final_release_notes="${release_notes_dir}/${new_version}.md"
    
    if [[ -f "$dev_release_notes" ]]; then
      if ! $dry_run; then
        __chief_print_info "Transforming development release notes to final release..."
        __chief_print_info "  ${new_version}-dev.md → ${new_version}.md"
        
        # Transform the content: remove -dev references and update status
        sed -e "s/${new_version}-dev/${new_version}/g" \
            -e 's/## 🚀 What'\''s New in Development/## 🚀 What'\''s New in '"${new_version}"'/g' \
            -e 's/**Status:** Development in progress/**Status:** Released/g' \
            -e 's/**Target Release:** '"${new_version}"'/**Release Date:** '"${new_version}"'/g' \
            "$dev_release_notes" > "$final_release_notes"
        
        # Remove the development version file
        rm "$dev_release_notes"
        __chief_print_success "Release notes updated for ${new_version} release"
      else
        __chief_print_info "Would transform: ${new_version}-dev.md → ${new_version}.md"
        __chief_print_info "Would update content to reflect released status"
      fi
    elif [[ ! -f "$final_release_notes" ]]; then
      if ! $dry_run; then
        __chief_print_warn "No development release notes found at: ${dev_release_notes}"
        __chief_print_info "Creating basic release notes for ${new_version}..."
        
        mkdir -p "$release_notes_dir"
        cat > "$final_release_notes" << EOF
# Chief ${new_version} Release Notes

## 🚀 What's New in ${new_version}

### 🔧 Version ${new_version} Release

- Release version ${new_version}

## 📋 Upgrade Notes

### For Users

- This is a release version

---

**Status:** Released  
**Release Date:** ${new_version}  
**Breaking Changes:** TBD  
**New Features:** TBD
EOF
        __chief_print_info "Created basic release notes: release-notes/${new_version}.md"
      else
        __chief_print_info "Would create basic release notes: release-notes/${new_version}.md"
      fi
    else
      __chief_print_info "Final release notes already exist: release-notes/${new_version}.md"
    fi
  fi

  # Update each file
  local updated_count=0
  for file in "${files_to_update[@]}"; do
    if [[ ! -f "$file" ]]; then
      __chief_print_warn "File not found, skipping: $(basename "$file")"
      continue
    fi
    
    # Note: No special UPDATES handling needed - using release-notes structure
    
    # Check if file already has the new version (both regular and badge formats)
    # Handle badge URL encoding with proper -dev suffix handling
    local badge_current=""
    local badge_new="Download-Release%20${new_version}"
    
    # For release workflow: current version might have -dev, new version won't
    if [[ "${positional_args[0]}" == "release" ]]; then
      badge_current="Download-Release%20${current_version}"
    # For next-dev workflow: current version won't have -dev, new version will
    elif [[ "${positional_args[0]}" == "next-dev" ]]; then
      badge_current="Download-Release%20${current_version}"
    else
      # Default case
      badge_current="Download-Release%20${current_version}"
    fi
    
    # Handle dev badge updates for two-badge structure
    local dev_badge_current=""
    local dev_badge_new=""
    
    # For release workflow: v3.1.1-dev → v3.1.1, dev badge should show next dev version  
    if [[ "${positional_args[0]}" == "release" && "$current_version" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)-dev$ ]]; then
      local major="${BASH_REMATCH[1]}"
      local minor="${BASH_REMATCH[2]}"
      local patch="${BASH_REMATCH[3]}"
      # Next development cycle: increment minor version for next dev
      ((minor++))
      dev_badge_current="Dev%20Branch-${current_version}"
      dev_badge_new="Dev%20Branch-v${major}.${minor}.0"
    # For next-dev workflow: v3.1.1 → v3.1.2-dev, dev badge should show the new dev version
    elif [[ "${positional_args[0]}" == "next-dev" ]]; then
      # Current version would be release version, new version would be dev version
      dev_badge_current="Dev%20Branch-.*"  # Pattern to match any current dev badge
      dev_badge_new="Dev%20Branch-${new_version}"
    fi
    
    # Check if file already has the new version (check version first, then badges if they exist)
    local has_new_version=false
    local has_badges=false
    local badge_needs_update=false
    
    if grep -q "$new_version" "$file" 2>/dev/null; then
      has_new_version=true
    fi
    
    # Check if file has badges at all
    if grep -q "shields\.io\|badge" "$file" 2>/dev/null; then
      has_badges=true
      # If it has badges, check if they need updating
      if ! grep -q "$badge_new" "$file" 2>/dev/null; then
        badge_needs_update=true
      fi
    fi
    
    # File is up to date if version is correct AND (no badges OR badges are correct)
    if $has_new_version && (! $has_badges || ! $badge_needs_update); then
      __chief_print_info "$(basename "$file"): Already up to date ($new_version)"
      continue
    fi
    
    if $dry_run; then
      local changes=""
      if grep -q "$current_version" "$file" 2>/dev/null; then
        changes="version"
      fi
      if grep -q "$badge_current" "$file" 2>/dev/null; then
        if [[ -n "$changes" ]]; then
          changes="$changes + badges"
        else
          changes="badges"
        fi
      fi
      
      # Check for dev badge changes
      if [[ -n "$dev_badge_current" && -n "$dev_badge_new" ]]; then
        if [[ "$dev_badge_current" == *".*"* ]]; then
          # Pattern matching - check if file has any dev badge
          if grep -q "Dev%20Branch-.*" "$file" 2>/dev/null; then
            if [[ -n "$changes" ]]; then
              changes="$changes + dev badges"
            else
              changes="dev badges"
            fi
          fi
        else
          # Exact match
          if grep -q "$dev_badge_current" "$file" 2>/dev/null; then
            if [[ -n "$changes" ]]; then
              changes="$changes + dev badges"
            else
              changes="dev badges"
            fi
          fi
        fi
      fi
      __chief_print_info "$(basename "$file"): Would update $changes ($current_version → $new_version)"
      continue
    fi
    
    # Create backup if requested
    if $create_backups; then
      cp "$file" "${file}.backup.$(date +%s)"
    fi
    
    # Perform replacements (both regular version and badge URLs)
    local success=true
    
    # Update regular version references
    if ! sed -i.tmp1 "s/${current_version}/${new_version}/g" "$file" 2>/dev/null; then
      success=false
    fi
    
    # Update badge URL-encoded versions - improved to handle -dev suffix variations
    if $success; then
      # Try exact replacement first
      if ! sed -i.tmp2 "s/${badge_current}/${badge_new}/g" "$file" 2>/dev/null; then
        # If that fails, try a more flexible pattern-based replacement
        if [[ "${positional_args[0]}" == "next-dev" ]]; then
          # For next-dev, we need to add -dev to the version
          if ! sed -i.tmp2 "s|Download-Release%20${current_version}\([^-]\)|${badge_new}\1|g" "$file" 2>/dev/null; then
            success=false
          fi
        elif [[ "${positional_args[0]}" == "release" ]]; then
          # For release, we need to remove -dev from the version
          if ! sed -i.tmp2 "s|Download-Release%20${current_version}|${badge_new}|g" "$file" 2>/dev/null; then
            success=false
          fi
        else
          success=false
        fi
      fi
    fi
    
    # Update dev badge if we have dev badge changes
    if $success && [[ -n "$dev_badge_current" && -n "$dev_badge_new" ]]; then
      # Check if dev badge exists in file
      local dev_badge_exists=false
      if grep -q "Dev%20Branch-" "$file" 2>/dev/null; then
        dev_badge_exists=true
      fi
      
      if $dev_badge_exists; then
        # Update existing dev badge
        if [[ "$dev_badge_current" == *".*"* ]]; then
          # Use regex replacement for pattern matching - improved pattern
          if ! sed -i.tmp_dev "s|Dev%20Branch-v[0-9][^-]*\(-dev\)\?|${dev_badge_new}|g" "$file" 2>/dev/null; then
            success=false
          fi
        else
          # Use exact string replacement
          if ! sed -i.tmp_dev "s/${dev_badge_current}/${dev_badge_new}/g" "$file" 2>/dev/null; then
            success=false
          fi
        fi
      else
        # Add dev badge if it doesn't exist (for next-dev workflow in README.md)
        if [[ "${positional_args[0]}" == "next-dev" && "$(basename "$file")" == "README.md" ]]; then
          # Insert dev badge after the release badge - simplified pattern
          if ! sed -i.tmp_dev "s|\(Download-Release%20[^-]*\(-dev\)\?[^]]*\)]\([^)]*\))\(.*\)Documentation|\1]]\3) [![Dev Branch](https://img.shields.io/badge/${dev_badge_new}-orange.svg?style=social)](https://github.com/randyoyarzabal/chief/tree/dev)\4Documentation|g" "$file" 2>/dev/null; then
            success=false
          fi
        fi
      fi
    fi
    
    # For release bumps (not next-dev), remove "(Unreleased)" markers
    if $success && [[ "$1" == "release" ]]; then
      # Handle different unreleased patterns
      if ! sed -i.tmp3 "s/## Unreleased (${new_version})/## ${new_version}/g" "$file" 2>/dev/null; then
        success=false
      fi
      if $success && ! sed -i.tmp4 "s/# Chief ${new_version} Release Notes (Unreleased)/# Chief ${new_version} Release Notes/g" "$file" 2>/dev/null; then
        success=false
      fi
    fi
    
    # Handle README.md content changes for dev vs release versions
    if $success && [[ "$(basename "$file")" == "README.md" ]]; then
      if [[ "$1" == "release" ]]; then
        # RELEASE: Remove dev-specific content from README
        # 1. Remove "(Development Version)" from title
        if ! sed -i.tmp5 "s/# 🚀 Chief (Development Version)/# 🚀 Chief/g" "$file" 2>/dev/null; then
          success=false
        fi
        
        # 2. Remove warning box (multi-line pattern)
        if $success; then
          # Use perl for multi-line replacement to remove the warning block
          if ! perl -i -pe 'BEGIN{undef $/;} s/\n> ⚠️ \*\*Warning\*\*: This is the development branch.*?\[main branch\]\(.*?\)\.\n//smg' "$file" 2>/dev/null; then
            success=false
          fi
        fi
        
        # 3. Simplify installation section
        if $success; then
          # Replace development install section with simple install
          if ! sed -i.tmp6 's/## ⚡ Quick Install (Development Version)/## ⚡ Quick Install/g' "$file" 2>/dev/null; then
            success=false
          fi
          
          # Remove the dev install block and stable alternative, keep only main install
          if $success; then
            # Use perl to replace the complex install section
            perl -i -pe 'BEGIN{undef $/;} s/```bash\n# Install development version \(may be unstable\)\nbash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/dev\/tools\/install\.sh\)"\n```\n\n\*\*For stable release\*\*, use:\n```bash\n# Install stable version from main branch\nbash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/main\/tools\/install\.sh\)"\n```/```bash\nbash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/main\/tools\/install\.sh\)"\n```/smg' "$file" 2>/dev/null || success=false
          fi
        fi
        
      elif [[ "$1" == "next-dev" ]]; then
        # NEXT-DEV: Add dev-specific content to README
        # 1. Add "(Development Version)" to title
        if ! sed -i.tmp5 "s/# 🚀 Chief$/# 🚀 Chief (Development Version)/g" "$file" 2>/dev/null; then
          success=false
        fi
        
        # 2. Add warning box after title
        if $success; then
          # Insert warning after the title and description
          if ! sed -i.tmp6 '/^\*\*Bash Plugin Manager & Terminal Enhancement Tool\*\*$/a\\n> ⚠️ **Warning**: This is the development branch. Features may be unstable. For stable releases, use the [main branch](https://github.com/randyoyarzabal/chief/tree/main).' "$file" 2>/dev/null; then
            success=false
          fi
        fi
        
        # 3. Expand installation section
        if $success; then
          # Update install section title
          if ! sed -i.tmp7 's/## ⚡ Quick Install$/## ⚡ Quick Install (Development Version)/g' "$file" 2>/dev/null; then
            success=false
          fi
          
          # Replace simple install with dev install section
          if $success; then
            # This is complex, so use perl for multi-line replacement
            perl -i -pe 'BEGIN{undef $/;} s/```bash\nbash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/main\/tools\/install\.sh\)"\n```/```bash\n# Install development version (may be unstable)\nbash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/dev\/tools\/install\.sh\)"\n```\n\n**For stable release**, use:\n```bash\n# Install stable version from main branch\nbash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/main\/tools\/install\.sh\)"\n```/smg' "$file" 2>/dev/null || success=false
          fi
        fi
      fi
    fi
    
    if $success; then
      rm -f "${file}.tmp1" "${file}.tmp2" "${file}.tmp3" "${file}.tmp4" "${file}.tmp5" "${file}.tmp6" "${file}.tmp7" "${file}.tmp_dev" 2>/dev/null
      if [[ "$(basename "$file")" == "README.md" ]]; then
        __chief_print_success "$(basename "$file"): Updated $current_version → $new_version (including badges and content structure)"
      else
        __chief_print_success "$(basename "$file"): Updated $current_version → $new_version (including badges)"
      fi
      ((updated_count++))
    else
      # Restore backup on failure if it exists
      if $create_backups; then
        local backup_file="${file}.backup.$(date +%s)"
        if [[ -f "$backup_file" ]]; then
          mv "$backup_file" "$file" 2>/dev/null
        fi
      fi
      rm -f "${file}.tmp1" "${file}.tmp2" "${file}.tmp3" "${file}.tmp4" "${file}.tmp5" "${file}.tmp6" "${file}.tmp7" "${file}.tmp_dev" 2>/dev/null
      __chief_print_error "$(basename "$file"): Failed to update"
      return 1
    fi
  done
  
  
  # Summary
  echo ""
  if $dry_run; then
    __chief_print_info "Dry run completed. No files were modified."
    __chief_print_info "Run without --dry-run to apply changes."
  else
    __chief_print_success "Version bump completed: $current_version → $new_version"
    __chief_print_info "Files updated: $updated_count"
    
    # Clean up old backups (keep only the 3 most recent) - only if backups were created
    if $create_backups; then
      local backup_files
      backup_files=$(find "${CHIEF_PATH}" -name "*.backup.*" -type f 2>/dev/null | sort)
      if [[ -n "$backup_files" ]]; then
        local total_backups
        total_backups=$(echo "$backup_files" | wc -l | tr -d ' ')
        if [[ "$total_backups" -gt 3 ]]; then
          local files_to_delete=$((total_backups - 3))
          echo "$backup_files" | head -n "$files_to_delete" | xargs rm -f 2>/dev/null || true
          __chief_print_info "Cleaned up old backup files (kept 3 most recent)"
        fi
      fi
    fi
    
    # Different next steps for dev vs release versions
    if [[ "$new_version" =~ -dev$ ]]; then
      __chief_print_info "📋 Next steps for development version ($new_version):"
      __chief_print_info "  1. ✅ Ready for development work on $new_version"
      __chief_print_info "  2. 📄 README.md converted to dev format (added warnings/dev structure)"
      __chief_print_info "  3. 🔄 Update branch set to 'dev' (will track development updates)"
      __chief_print_info "  4. When ready to release, run: __chief.bump release"
    else
      __chief_print_info "🚀 Release version ready ($new_version):"
      __chief_print_info "  📝 Badges now show release version (no -dev suffix)"
      __chief_print_info "  📄 README.md converted to release format (removed dev warnings/structure)"
      __chief_print_info "  🔄 Update branch set to 'main' (will track stable releases)"
      __chief_print_info "  📋 Next steps to publish release:"
      __chief_print_info "  1. 🔄 Create PR: dev → main (for release)"
      __chief_print_info "  2. 📦 Create GitHub release from tag for publishing"
      __chief_print_info ""
      __chief_print_info "📋 Copy-paste for GitHub release description:"
      __chief_print_info "────────────────────────────────────────────────────"
      __chief_print_info "See [$new_version release notes](https://github.com/randyoyarzabal/chief/blob/main/release-notes/$new_version.md)"
      __chief_print_info "────────────────────────────────────────────────────"
      __chief_print_info ""
      __chief_print_info "  7. 🔄 Run: __chief.bump next-dev (to start next development cycle)"
    fi
  fi
}
