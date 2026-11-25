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
# Core plugins that need tools or accounts most users don't have (aws, openshift, vault) are
# simply listed in the template's CHIEF_CFG_PLUGINS_DISABLED_CORE, so new installs start with
# them off. One rule for every core plugin: loaded unless it's in the disabled list.
# Contrib plugins: optional plugins shipped with Chief for specific teams or workflows.
# Chief scans this directory on every load, but every contrib plugin is OFF until
# `chief.plugin enable contrib.<name>` (persisted in CHIEF_CFG_PLUGINS_ENABLED_CONTRIB).
CHIEF_PLUGINS_CONTRIB="${CHIEF_PATH}/libs/contrib/plugins"
# Dev plugins: maintainer tooling (e.g. chief.release_*). Never loaded for users: only when
# Chief's own checkout is on the "dev" branch AND CHIEF_CFG_DEV_TOOLS=true. See __chief_dev_tools_state.
CHIEF_PLUGINS_DEV="${CHIEF_PATH}/libs/dev/plugins"
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

# Detect if Chief is running in disconnected mode
function __chief_is_disconnected_mode() {
  # Check if Chief directory is not a git repository
  if [[ -d "${CHIEF_PATH}" ]] && ! [[ -d "${CHIEF_PATH}/.git" ]]; then
    return 0  # true - disconnected mode (no git repository)
  fi
  
  return 1  # false - connected mode (git repository present)
}

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
  
  # Optional keys: unset before re-sourcing config so removed/commented assignments do not stick.
  unset CHIEF_CFG_ALIAS
  __chief_load_file ${CHIEF_CONFIG}

  __chief_load_file ${CHIEF_LIBRARY} 

  # Set a default alias if none defined.
  if [[ -n ${CHIEF_CFG_ALIAS} ]]; then
    __chief_framework_print "aliased as ${CHIEF_CFG_ALIAS}." "$1"
  fi

  __chief_load_plugins 'core' "$1"
  __chief_load_plugins 'contrib' "$1"
  __chief_load_dev_tools "$1"

  if [[ -z ${CHIEF_CFG_PLUGINS_TYPE} ]]; then
    # If not set, default to local plugins.
    CHIEF_CFG_PLUGINS_TYPE=${CHIEF_DEFAULT_PLUGINS_TYPE}
  fi

  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]]; then
    __chief_load_remote_plugins "$1"
  elif [[ ${CHIEF_CFG_PLUGINS_TYPE} == "local" ]]; then
    __chief_discover_shared_secrets_file
    __chief_load_plugins 'user' "$1"
  fi

  __chief_print_shared_secrets_summary "$1"
  __chief_framework_print "library reloaded." "$1"
}

# Is CHIEF_CFG_UPDATE_BRANCH in auto mode? Empty or "auto" = follow the checkout.
function __chief_update_branch_auto() {
  [[ -z "${CHIEF_CFG_UPDATE_BRANCH:-}" || "${CHIEF_CFG_UPDATE_BRANCH}" == auto ]]
}

# The branch Chief updates from. Auto mode (the default): whatever branch Chief's own checkout
# is on, so switching between dev and main is just "git -C ~/.chief switch dev" (or main) with
# no config change. On a tag or detached HEAD there's no branch to follow, so: main.
# A branch name in CHIEF_CFG_UPDATE_BRANCH pins it instead (and chief.update offers to switch).
function __chief_update_branch() {
  if __chief_update_branch_auto; then
    local branch
    branch="$(git -C "${CHIEF_PATH}" symbolic-ref --short -q HEAD 2>/dev/null)"
    echo "${branch:-main}"
  else
    echo "${CHIEF_CFG_UPDATE_BRANCH}"
  fi
}

function __chief_dev_tools_state() {
  # Usage: __chief_dev_tools_state
  #
  # Developer usage: Prints whether maintainer dev tools (libs/dev/plugins) may load:
  #   active  - Chief's checkout is on the dev branch and CHIEF_CFG_DEV_TOOLS=true
  #   off     - CHIEF_CFG_DEV_TOOLS is not true (the default)
  #   branch  - the switch is on, but the checkout is not on the dev branch (main, a tag, ...)
  #   missing - this checkout has no libs/dev/plugins (e.g. a release archive)
  [[ "${CHIEF_CFG_DEV_TOOLS:-false}" == true ]] || { echo off; return 0; }
  [[ -d "${CHIEF_PLUGINS_DEV}" ]] || { echo missing; return 0; }
  local branch
  branch="$(git -C "${CHIEF_PATH}" symbolic-ref --short -q HEAD 2>/dev/null)"
  if [[ "$branch" == dev ]]; then echo active; else echo branch; fi
}

function __chief_load_dev_tools() {
  # Usage: __chief_load_dev_tools [--verbose]
  #
  # Developer usage: Sources libs/dev/plugins/*_chief-plugin.sh only when __chief_dev_tools_state
  # is "active". Users (main branch, release archives, switch off) never get these functions.
  [[ "$(__chief_dev_tools_state)" == active ]] || return 0
  local plugin names=""
  for plugin in "${CHIEF_PLUGINS_DEV}/"*"${CHIEF_PLUGIN_SUFFIX}"; do
    [[ -f "$plugin" ]] || continue
    __chief_load_file "$plugin"
    plugin="${plugin##*/}"
    names+="${names:+, }${CHIEF_COLOR_MAGENTA}${plugin%%_*}${CHIEF_NO_COLOR}"
  done
  [[ -n "$names" ]] && __chief_framework_print "dev: ${names}" "$1"
  return 0
}

function __chief_check_bash_version() {
  # Usage: __chief_check_bash_version
  #
  # Developer usage: Warns (never blocks) when Chief is loaded by a Bash older than 4.0.
  # - macOS ships Bash 3.2, which lacks 'declare -A' / 'declare -g' used by Chief and many plugins.
  #   Without this warning the only symptom is cryptic "declare: -A: invalid option" errors.
  # - Prints to stderr. Disable with CHIEF_CFG_BASH_WARN=false.
  # - Test hook: CHIEF_TEST_BASH_VERSINFO_MAJOR overrides the detected major version.
  local major="${CHIEF_TEST_BASH_VERSINFO_MAJOR:-${BASH_VERSINFO[0]:-0}}"
  (( major >= 4 )) && return 0
  [[ "${CHIEF_CFG_BASH_WARN:-true}" == "false" ]] && return 0

  local brew_bash="" cand
  for cand in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$cand" ]] && { brew_bash="$cand"; break; }
  done

  echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Chief needs Bash 4.0+, but this shell is Bash ${BASH_VERSION:-unknown} (${BASH:-bash})." >&2
  echo -e "Some Chief plugins and commands will fail (e.g. ${CHIEF_COLOR_RED}declare: -A: invalid option${CHIEF_NO_COLOR})." >&2
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo -e "macOS ships Bash 3.2. To fix:" >&2
    if [[ -z "$brew_bash" ]]; then
      echo -e "  1. Install a current Bash:  ${CHIEF_COLOR_CYAN}brew install bash${CHIEF_NO_COLOR}" >&2
      brew_bash="/opt/homebrew/bin/bash"
    else
      echo -e "  1. A newer Bash is already installed at ${CHIEF_COLOR_CYAN}${brew_bash}${CHIEF_NO_COLOR}." >&2
    fi
    echo -e "  2. Make your terminal use it. Either set the terminal's command / shell to" >&2
    echo -e "     ${CHIEF_COLOR_CYAN}${brew_bash} -l${CHIEF_NO_COLOR}, or put this at the top of ~/.bash_profile:" >&2
    echo -e "       ${CHIEF_COLOR_GREEN}if [[ \$- == *i* ]] && (( BASH_VERSINFO[0] < 4 )) && [[ -x ${brew_bash} ]]; then exec ${brew_bash} -l; fi${CHIEF_NO_COLOR}" >&2
  else
    echo -e "Upgrade Bash with your package manager (for example: apt-get install bash, dnf install bash)." >&2
  fi
  echo -e "Silence this warning with: ${CHIEF_COLOR_CYAN}chief.config-set -y BASH_WARN=false${CHIEF_NO_COLOR}" >&2
  return 0
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
    echo -e "${1}"
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

function __chief_get_command_prefix() {
  # Usage: __chief_get_command_prefix
  # 
  # Developer usage: Returns the appropriate command prefix for help text
  # - Returns alias prefix if CHIEF_CFG_ALIAS is set (e.g., "cf.")
  # - Returns "chief." if no alias is configured
  # - Used internally by help functions to display correct command names
  #
  # Returns:
  #   string - Command prefix with trailing dot (e.g., "chief." or "cf.")
  
  if [[ -n ${CHIEF_CFG_ALIAS} ]]; then
    local alias=$(__chief_lower ${CHIEF_CFG_ALIAS})
    echo "${alias}."
  else
    echo "chief."
  fi
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

# Resolve GUI editor command for --code/--vscode flag.
# Priority: CHIEF_CFG_EDITOR_GUI_CMD → cursor --wait → code --wait
# Returns: command string (e.g. "cursor --wait") or empty if none available
function __chief_get_gui_editor() {
  if [[ -n "${CHIEF_CFG_EDITOR_GUI_CMD}" ]]; then
    echo "${CHIEF_CFG_EDITOR_GUI_CMD}"
    return
  fi
  if command -v cursor >/dev/null 2>&1; then
    echo "cursor --wait"
    return
  fi
  if command -v code >/dev/null 2>&1; then
    echo "code --wait"
    return
  fi
  echo ""
}

function __chief_get_default_editor() {
  # Usage: __chief_get_default_editor
  # 
  # Determines the default editor to use with smart fallback logic
  # Priority: CHIEF_CFG_DEFAULT_EDITOR_PATH → $EDITOR → vim (if available) → vi
  # Returns: Editor command to use
  local editor_cmd="vi"  # ultimate fallback
  
  # Check Chief-specific editor configuration first
  if [[ -n "${CHIEF_CFG_DEFAULT_EDITOR_PATH}" ]]; then
    echo "${CHIEF_CFG_DEFAULT_EDITOR_PATH}"
    return
  fi
  
  # Check system $EDITOR environment variable
  if [[ -n "${EDITOR}" ]]; then
    echo "${EDITOR}"
    return
  fi
  
  # Check if vim is available, prefer it over vi
  if command -v vim >/dev/null 2>&1; then
    echo "vim"
    return
  fi
  
  # Final fallback to vi
  echo "vi"
}

function chief.edit-file() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <file> [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit any file with automatic reload detection and sourcing. Ideal for shell scripts,
configuration files, and any file that needs to be reloaded after editing.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  file           Path to the file to edit (required)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --vscode, -v   Use GUI editor (Cursor if available, else VSCode 'code'; config: CHIEF_CFG_EDITOR_GUI_CMD)
  -?, --help     Show this help message

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Automatically detects file changes using timestamps
- Sources/reloads the file if modifications are detected  
- Respects CHIEF_CFG_DEFAULT_EDITOR_PATH, \$EDITOR, then falls back to vim/vi
- Works with any text file type
- Cross-platform compatible (Linux/macOS)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME ~/.bashrc                    # Edit bashrc with configured editor
  $FUNCNAME ~/.bashrc --vscode           # Edit bashrc with Cursor/VSCode
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
  local editor_cmd
  if [[ "$editor_option" == "vscode" ]]; then
    editor_cmd="$(__chief_get_gui_editor)"
    if [[ -z "$editor_cmd" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Warning: No GUI editor found (tried CHIEF_CFG_EDITOR_GUI_CMD, cursor, code). Falling back to default editor.${CHIEF_NO_COLOR}"
      editor_cmd="$(__chief_get_default_editor)"
    fi
  else
    editor_cmd="$(__chief_get_default_editor)"
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

# Discover portable team secrets under the configured plugins directory (sets CHIEF_SECRETS_FILE; no output).
function __chief_discover_shared_secrets_file() {
  local dir_base secrets_path
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" && -n ${CHIEF_CFG_PLUGINS_GIT_PATH:-} ]]; then
    dir_base="${CHIEF_CFG_PLUGINS_PATH}/${CHIEF_CFG_PLUGINS_GIT_PATH}"
  else
    dir_base="${CHIEF_CFG_PLUGINS_PATH:-}"
  fi
  secrets_path=""
  if [[ -n "$dir_base" && -f "${dir_base}/.chief_shared-secrets" ]]; then
    secrets_path="${dir_base}/.chief_shared-secrets"
  elif [[ -n "$dir_base" && -f "${dir_base}/.chief_shared-vault" ]]; then
    secrets_path="${dir_base}/.chief_shared-vault"
  fi
  if [[ -n "$secrets_path" ]]; then
    export CHIEF_SECRETS_FILE="$secrets_path"
  else
    unset CHIEF_SECRETS_FILE
  fi
}

# End of load: one-line hint if a portable secrets file exists (still requires secrets_file-load).
function __chief_print_shared_secrets_summary() {
  local verbose_flag="$1"
  [[ -n "${CHIEF_SECRETS_FILE:-}" && -f "${CHIEF_SECRETS_FILE}" ]] || return 0
  local prefix base_msg legacy_note=""
  prefix="$(__chief_get_command_prefix)"
  local loaded=""
  if declare -F __chief_secrets_loaded_desc >/dev/null; then
    loaded="$(__chief_secrets_loaded_desc "${CHIEF_SECRETS_FILE}")"
  fi
  if [[ -n "$loaded" ]]; then
    base_msg="The core ${CHIEF_COLOR_CYAN}secrets${CHIEF_NO_COLOR} plugin found a shared secrets file under your plugins tree: ${loaded}."
  else
    base_msg="The core ${CHIEF_COLOR_CYAN}secrets${CHIEF_NO_COLOR} plugin auto-detected a shared vault file under your plugins tree (not applied to this shell yet). Run ${CHIEF_COLOR_CYAN}${prefix}secrets_file-load${CHIEF_NO_COLOR} to load; see ${CHIEF_COLOR_CYAN}${prefix}help${CHIEF_NO_COLOR} for details."
  fi
  if [[ "${CHIEF_SECRETS_FILE##*/}" == ".chief_shared-vault" ]] && [[ -z "${CHIEF_SECRETS_WARNED_LEGACY_DISCOVERY:-}" ]]; then
    export CHIEF_SECRETS_WARNED_LEGACY_DISCOVERY=1
    legacy_note="${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} rename .chief_shared-vault → .chief_shared-secrets when you can. "
  fi
  __chief_framework_print "${legacy_note}${base_msg}" "$verbose_flag"
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
        echo -e "${CHIEF_COLOR_YELLOW}Force update: local changes will be lost.${CHIEF_NO_COLOR}"
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
You can run 'chief.plugins-update' anytime or set CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=true"; then
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
      echo -e "${CHIEF_COLOR_YELLOW}Warning: Remote plugins are not set to auto-update (CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=false). Run ${CHIEF_COLOR_CYAN}chief.plugins-update${CHIEF_COLOR_YELLOW} to update.${CHIEF_NO_COLOR}"
    fi
  fi
  __chief_discover_shared_secrets_file

  # Load plugins from the remote repository.
  __chief_load_plugins 'user' "$1"
}

# Returns 0 if the given plugin is disabled (should not load), 1 if enabled.
# Usage: __chief_plugin_disabled <module> <plugin_name>
#   module: 'core' or 'user'
#   plugin_name: e.g. 'git', 'bc'
# Normalize disabled list: accept comma- or space-separated; output space-separated.
function __chief_plugin_normalize_disabled_list() {
  echo "$1" | tr ',' ' ' | xargs
}

# Format plugin list for display: pipe- or space-separated -> comma-space separated (consistent everywhere).
function __chief_format_plugin_list() {
  local list="$1"
  [[ -z "$list" ]] && echo "" && return
  echo "$list" | tr '|' ' ' | xargs | sed 's/ /, /g'
}

# Returns 0 if <name> is in <list> (comma- or space-separated, case-insensitive).
# Usage: __chief_plugin_in_list <name> <list>
function __chief_plugin_in_list() {
  local n list
  n=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  list="$(__chief_plugin_normalize_disabled_list "$2")"
  list=" $(echo "$list" | tr '[:upper:]' '[:lower:]') "
  [[ -n "$n" && "$list" == *" $n "* ]]
}

function __chief_plugin_disabled() {
  local module="$1"
  local name="$2"
  local list=""
  [[ -z "$name" ]] && return 1
  if [[ "$module" == 'contrib' ]]; then
    # Contrib plugins are all opt-in: off unless listed in CHIEF_CFG_PLUGINS_ENABLED_CONTRIB.
    __chief_plugin_in_list "$name" "${CHIEF_CFG_PLUGINS_ENABLED_CONTRIB:-}" && return 1
    return 0
  fi
  if [[ "$module" == 'core' ]]; then
    list="${CHIEF_CFG_PLUGINS_DISABLED_CORE:-}"
  elif [[ "$module" == 'user' ]]; then
    list="${CHIEF_CFG_PLUGINS_DISABLED_USER:-}"
  else
    return 1
  fi
  __chief_plugin_in_list "$name" "$list"
}

# Update disabled-plugins list in config: add or remove a name. Persists and reloads.
# Usage: __chief_plugin_enable_disable <module> <plugin_name> <enable|disable>
function __chief_plugin_enable_disable() {
  local module="$1"
  local name="$2"
  local action="$3"
  local config_key list current new_value
  name=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  # Contrib plugins are tracked in an ENABLED list (they're all off by default).
  if [[ "$module" == 'contrib' ]]; then
    if [[ ! -f "${CHIEF_PLUGINS_CONTRIB}/${name}${CHIEF_PLUGIN_SUFFIX}" ]]; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} no contrib plugin named ${CHIEF_COLOR_CYAN}${name}${CHIEF_NO_COLOR} (available: $(__chief_format_plugin_list "$(__chief_get_contrib_plugins all)"))" >&2
      return 1
    fi
    current="$(__chief_plugin_normalize_disabled_list "${CHIEF_CFG_PLUGINS_ENABLED_CONTRIB:-}")"
    if [[ "$action" == "enable" ]]; then
      if ! __chief_plugin_disabled contrib "$name"; then
        echo -e "${CHIEF_COLOR_YELLOW}Plugin ${CHIEF_COLOR_CYAN}${name}${CHIEF_NO_COLOR} is already enabled."
        return 0
      fi
      new_value="$(echo "$current $name" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ' | xargs)"
    else
      if __chief_plugin_disabled contrib "$name"; then
        echo -e "${CHIEF_COLOR_YELLOW}Plugin ${CHIEF_COLOR_CYAN}${name}${CHIEF_NO_COLOR} is already disabled."
        return 0
      fi
      new_value=$(echo "$current" | tr ' ' '\n' | grep -v "^$" | grep -v "^${name}$" | tr '\n' ' ')
      new_value="$(echo "$new_value" | xargs)"
    fi
    chief.config-set --yes plugins_enabled_contrib "$new_value"
    return
  fi

  if [[ "$module" == 'core' ]]; then
    config_key="plugins_disabled_core"
    current="${CHIEF_CFG_PLUGINS_DISABLED_CORE:-}"
  elif [[ "$module" == 'user' ]]; then
    config_key="plugins_disabled_user"
    current="${CHIEF_CFG_PLUGINS_DISABLED_USER:-}"
  else
    echo -e "${CHIEF_COLOR_RED}Error: module must be 'core', 'contrib' or 'user'${CHIEF_NO_COLOR}" >&2
    return 1
  fi
  current="$(__chief_plugin_normalize_disabled_list "$current")"
  if [[ "$action" == "disable" ]]; then
    if __chief_plugin_disabled "$module" "$name"; then
      echo -e "${CHIEF_COLOR_YELLOW}Plugin ${CHIEF_COLOR_CYAN}${name}${CHIEF_NO_COLOR} is already disabled."
      return 0
    fi
    new_value="$(echo "$current $name" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ' | xargs)"
  else
    if ! __chief_plugin_disabled "$module" "$name"; then
      echo -e "${CHIEF_COLOR_YELLOW}Plugin ${CHIEF_COLOR_CYAN}${name}${CHIEF_NO_COLOR} is already enabled."
      return 0
    fi
    new_value=$(echo "$current" | tr ' ' '\n' | grep -v "^$" | grep -v "^${name}$" | tr '\n' ' ')
    new_value="$(echo "$new_value" | xargs)"
  fi
  chief.config-set --yes "$config_key" "$new_value"
}

# Source the library/plugin module passed.
function __chief_load_plugins() {
  # Usage: __chief_load_plugins <plug-in module> (user/core)
  #
  # Developer usage: Loads plugins from the user or core directory
  # - Checks if the plugin module is valid
  # - Sets the directory path based on the module
  # - Loads plugins from the directory (respects CHIEF_CFG_PLUGINS_DISABLED_*)
  #
  # Arguments:
  #   module - The plugin module to load (user/core)
  #
  # Options:
  #   --verbose - Display detailed loading information
  local plugin_file
  local plugin_name
  local dir_path
  local load_flag
  local loaded_list=""
  local disabled_list=""
  local missing_list=""

  load_flag=false # Default to false, unless plugin switch is defined.
  if [[ $1 == 'core' ]]; then
    dir_path=${CHIEF_PLUGINS_CORE}
    load_flag=true
  elif [[ $1 == 'contrib' ]]; then
    # Always scanned; each contrib plugin is off unless enabled (see __chief_plugin_disabled).
    dir_path=${CHIEF_PLUGINS_CONTRIB}
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
    __chief_framework_print "plugins: ${1} is not a valid plug-in module." "$2"
    return 1
  fi

  local plugins=() # Array to hold plugin names
  local sorted_plugins=() # Array to hold sorted plugin names
  if ! ${load_flag}; then
    __chief_framework_print "plugins: ${1} not enabled." "$2"
  else
    # Check for existence of plugin folder requested
    if [[ -d ${dir_path} ]]; then
      for plugin in "${dir_path}/"*"${CHIEF_PLUGIN_SUFFIX}"; do
        plugins+=("${plugin}") # Collect plugin names
      done

      # Sort the plugins alphabetically
      sorted_plugins=($(printf '%s\n' "${plugins[@]}"|sort))

      for plugin in "${sorted_plugins[@]}"; do
        plugin_file=${plugin##*/}
        plugin_name=${plugin_file%%_*}

        if __chief_plugin_disabled "$1" "$plugin_name"; then
          [[ -n ${disabled_list} ]] && disabled_list+=", "
          disabled_list+="${CHIEF_COLOR_YELLOW}${plugin_name}${CHIEF_NO_COLOR}"
          continue
        fi
        # A plugin that is a symlink to a file that isn't there (e.g. a link into a
        # checkout that only exists on some machines). Skip it without failing the
        # load, and warn in interactive shells; disabling the plugin marks it as
        # intended and silences the warning (the disabled check above runs first).
        if [[ -L ${plugin} && ! -e ${plugin} ]]; then
          [[ -n ${missing_list} ]] && missing_list+=", "
          missing_list+="${CHIEF_COLOR_YELLOW}${plugin_name}${CHIEF_NO_COLOR}"
          if [[ $- == *i* ]]; then
            local disable_name="${plugin_name}"
            [[ $1 != 'user' ]] && disable_name="${1}.${plugin_name}"
            echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} plugin '${plugin_name}' is a link to a file that isn't here ($(readlink "${plugin}")); skipped. If that's intended, silence this with: ${CHIEF_COLOR_CYAN}chief.plugin disable ${disable_name}${CHIEF_NO_COLOR}" >&2
          fi
          continue
        fi
        if [[ -f ${plugin} ]]; then
          [[ -n ${loaded_list} ]] && loaded_list+=", "
          loaded_list+="${CHIEF_COLOR_GREEN}${plugin_name}${CHIEF_NO_COLOR}"
          __chief_load_file "${plugin}" # Apply alias and source the plugin
        fi
      done

      # One summary line: loaded names + disabled (plugin stdout may appear above this line)
      local summary_line=""
      if [[ -n ${loaded_list} ]]; then
        summary_line+="${loaded_list}"
      fi
      if [[ -n ${disabled_list} ]]; then
        [[ -n ${summary_line} ]] && summary_line+=" · "
        summary_line+="off: ${disabled_list}"
      fi
      if [[ -n ${missing_list} ]]; then
        [[ -n ${summary_line} ]] && summary_line+=" · "
        summary_line+="missing: ${missing_list}"
      fi
      if [[ -z ${summary_line} ]]; then
        summary_line="${CHIEF_COLOR_YELLOW}(no plugins)${CHIEF_NO_COLOR}"
      fi
      __chief_framework_print "${1}: ${summary_line}" "$2"
    else
      __chief_framework_print "$1 plugins directory does not exist." "$2"
    fi
  fi
}

# Returns user plugins only (from CHIEF_CFG_PLUGINS_PATH). See __chief_get_core_plugins for built-in.
__chief_get_plugins() {
  # Usage: __chief_get_plugins
  #
  # Returns: A string of user plugin names separated by '|'
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

    # Loop through sorted plugins and print them (only enabled)
    for plugin in "${sorted_plugins[@]}"; do
      plugin_file=${plugin##*/}
      plugin_name=${plugin_file%%_*}
      __chief_plugin_disabled 'user' "$plugin_name" && continue
      plugin_list_str="$plugin_list_str|$plugin_name" # Append plugin name
    done
    plugin_list_str=$(echo ${plugin_list_str#?}) # Trim first character
  fi
  echo "${plugin_list_str}" # Return the plugin list string
}

# Returns core (built-in) plugin names from Chief's libs/core/plugins. Only enabled (not disabled) plugins.
__chief_get_core_plugins() {
  # Usage: __chief_get_core_plugins
  #
  # Returns: A string of core plugin names separated by '|'
  local plugin_file
  local plugin_name
  local plugin_list_str
  local dir_path="${CHIEF_PLUGINS_CORE}"

  local plugins=()
  local sorted_plugins=()

  if [[ -d ${dir_path} ]]; then
    for plugin in "${dir_path}/"*"${CHIEF_PLUGIN_SUFFIX}"; do
      [[ -f ${plugin} ]] && plugins+=("${plugin}")
    done
    sorted_plugins=($(printf '%s\n' "${plugins[@]}"|sort))
    for plugin in "${sorted_plugins[@]}"; do
      plugin_file=${plugin##*/}
      plugin_name=${plugin_file%%_*}
      __chief_plugin_disabled 'core' "$plugin_name" && continue
      plugin_list_str="$plugin_list_str|$plugin_name"
    done
    plugin_list_str=$(echo ${plugin_list_str#?})
  fi
  echo "${plugin_list_str}"
}

# Returns contrib plugin names from libs/contrib/plugins, '|'-separated.
# Usage: __chief_get_contrib_plugins [enabled|disabled|all]   (default: enabled)
__chief_get_contrib_plugins() {
  local want="${1:-enabled}" plugin plugin_file plugin_name out=""
  [[ -d ${CHIEF_PLUGINS_CONTRIB} ]] || return 0
  for plugin in "${CHIEF_PLUGINS_CONTRIB}/"*"${CHIEF_PLUGIN_SUFFIX}"; do
    [[ -f ${plugin} ]] || continue
    plugin_file=${plugin##*/}
    plugin_name=${plugin_file%%_*}
    if [[ $want == all ]]; then
      out+="|${plugin_name}"
    elif __chief_plugin_disabled 'contrib' "$plugin_name"; then
      [[ $want == disabled ]] && out+="|${plugin_name}"
    else
      [[ $want == enabled ]] && out+="|${plugin_name}"
    fi
  done
  echo "${out#|}"
}

# Returns core plugin names that are OFF (in CHIEF_CFG_PLUGINS_DISABLED_CORE). Space-separated.
__chief_get_core_plugins_disabled() {
  local plugin plugin_file plugin_name out=""
  [[ -d ${CHIEF_PLUGINS_CORE} ]] || return 0
  for plugin in "${CHIEF_PLUGINS_CORE}/"*"${CHIEF_PLUGIN_SUFFIX}"; do
    [[ -f ${plugin} ]] || continue
    plugin_file=${plugin##*/}
    plugin_name=${plugin_file%%_*}
    __chief_plugin_disabled 'core' "$plugin_name" || continue
    out+=" ${plugin_name}"
  done
  echo "${out# }"
}

# True if absolute $2 is $1 or inside $1 (path prefix with boundary).
__chief_path_is_under_or_equal() {
  local base="$1"
  local path="$2"
  base="${base%/}"
  path="${path%/}"
  [[ "$path" == "$base" ]] && return 0
  [[ "$path" == "${base}/"* ]]
}

# Echo a relative path from directory $1 to existing path $2 (for ln -sf targets in repos).
# Both sides are resolved to physical paths (symlinked directories followed), because the kernel
# resolves a relative symlink target from the link's physical directory, not its logical path.
# Returns 0 on success; 1 if paths are unrelated (e.g. different volume roots — caller uses absolute).
__chief_relpath_from_dir_to_path() {
  local from_dir="$1"
  local to_path="$2"
  local from_abs to_abs to_dir to_base
  [[ -d "$from_dir" ]] || return 1
  from_abs="$(cd "$from_dir" && pwd -P)" || return 1
  to_dir="$(dirname "$to_path")"
  to_base="$(basename "$to_path")"
  [[ -e "$to_path" ]] || return 1
  to_abs="$(cd "$to_dir" && pwd -P)/$to_base" || return 1
  from_abs="${from_abs%/}"
  to_abs="${to_abs%/}"

  if __chief_path_is_under_or_equal "$from_abs" "$to_abs"; then
    if [[ "$to_abs" == "$from_abs" ]]; then
      echo "."
    else
      echo "${to_abs#"${from_abs}/"}"
    fi
    return 0
  fi

  local up=""
  while ! __chief_path_is_under_or_equal "$from_abs" "$to_abs"; do
    local parent
    parent="$(dirname "$from_abs")"
    if [[ "$parent" == "$from_abs" ]]; then
      return 1
    fi
    from_abs="$parent"
    up="../${up}"
  done

  if [[ "$to_abs" == "$from_abs" ]]; then
    printf '%s\n' "$up"
    return 0
  fi
  printf '%s%s\n' "$up" "${to_abs#"${from_abs}/"}"
  return 0
}

# Edit a plugin file and reload into memory if changed.
#   Note, will only succeed if plug-in is enabled in settings.
# Usage: __chief_edit_plugin <plug-in name> [editor_option] [existing_file_path]
function __chief_edit_plugin() {
  # Usage: __chief_edit_plugin <plugin_name> [editor_option] [existing_file_path]
  # Arguments:
  #   plugin_name - Name of the plugin to edit
  #   editor_option - Optional: 'vscode' to use VSCode, otherwise uses default editor
  #   existing_file_path - Optional: path to existing script; creates a symlink at the plugin path
  #     instead of a new file. Prefers a relative symlink target when the script is under the same
  #     directory tree as the plugin dir (portable for git). Otherwise uses an absolute target.
  local plugin_name
  local plugin_file
  local editor_option=${2}
  local existing_file="${3}"

  # Normal case: plugin name is first argument
  plugin_name=$(__chief_lower "${1}")

  # If first arg looks like an absolute path and no third arg, treat as existing file and derive plugin name (handles old parsing)
  if [[ -z "$existing_file" && "$1" == /* ]]; then
    if [[ -f "$1" ]]; then
      existing_file="$1"
      plugin_name=$(__chief_lower "$(basename "$1" .sh)")
      plugin_name=${plugin_name%_chief-plugin}
    fi
  fi

  # Check if plugins are enabled.
  if [[ -z ${CHIEF_CFG_PLUGINS_PATH} ]]; then
    echo "Chief plugins are not enabled."
    return
  fi
  # Use same logic as __chief_load_plugins for consistency
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" && -n ${CHIEF_CFG_PLUGINS_GIT_PATH} ]]; then
    plugin_file="${CHIEF_CFG_PLUGINS_PATH}/${CHIEF_CFG_PLUGINS_GIT_PATH}/${plugin_name}${CHIEF_PLUGIN_SUFFIX}"
  else
    plugin_file="${CHIEF_CFG_PLUGINS_PATH}/${plugin_name}${CHIEF_PLUGIN_SUFFIX}"
  fi

  # Symlink mode: third parameter is path to existing file → symlink at plugin path (relative target when portable)
  if [[ -n "$existing_file" ]]; then
    local existing_abs
    if command -v realpath >/dev/null 2>&1; then
      existing_abs="$(realpath "$existing_file" 2>/dev/null)" || existing_abs=""
    fi
    if [[ -z "$existing_abs" ]]; then
      # Portable fallback: resolve to absolute path
      if [[ -d "$(dirname "$existing_file")" ]]; then
        existing_abs="$(cd "$(dirname "$existing_file")" && pwd -P)/$(basename "$existing_file")"
      else
        existing_abs="$existing_file"
      fi
    fi
    if [[ ! -f "$existing_abs" ]]; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Target file does not exist: $existing_file"
      return 1
    fi
    if [[ -f "$plugin_file" && ! -L "$plugin_file" ]]; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Plugin file already exists as a regular file: $plugin_file"
      echo -e "${CHIEF_COLOR_YELLOW}Remove or rename it first to create a symlink.${CHIEF_NO_COLOR}"
      return 1
    fi
    if ! mkdir -p "$(dirname "$plugin_file")"; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unable to create plugin directory."
      return 1
    fi
    local link_target="$existing_abs"
    local link_dir
    link_dir="$(dirname "$plugin_file")"
    local rel_target=""
    local plugins_root_abs=""
    plugins_root_abs="$(cd "${CHIEF_CFG_PLUGINS_PATH}" 2>/dev/null && pwd -P)" || plugins_root_abs=""
    # Relative target only when the script lives inside the plugins tree (portable for git clones).
    # Anything outside it would need ../../.. hops that depend on this machine's layout, so use absolute.
    if [[ -n "$plugins_root_abs" ]] && __chief_path_is_under_or_equal "$plugins_root_abs" "$existing_abs" \
      && rel_target="$(__chief_relpath_from_dir_to_path "$link_dir" "$existing_abs")"; then
      link_target="$rel_target"
      echo -e "${CHIEF_COLOR_BLUE}Using relative symlink (portable for git / other machines).${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} Target is outside the plugins directory; using absolute symlink (not portable if committed to a repo)."
    fi
    if ln -sf "$link_target" "$plugin_file"; then
      # Safety net: never leave a dangling link. If a relative target doesn't resolve, fall back to absolute.
      if [[ ! -e "$plugin_file" && "$link_target" != "$existing_abs" ]]; then
        echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Relative target did not resolve; using absolute target instead."
        link_target="$existing_abs"
        ln -sf "$link_target" "$plugin_file"
      fi
      if [[ ! -e "$plugin_file" ]]; then
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Symlink does not resolve: ${plugin_file} → ${link_target}"
        rm -f "$plugin_file"
        return 1
      fi
      echo -e "${CHIEF_COLOR_GREEN}Symlink created:${CHIEF_NO_COLOR} ${plugin_file} → ${link_target}"
      echo -e "${CHIEF_COLOR_BLUE}Plugin will load on next Chief reload. Edit with:${CHIEF_NO_COLOR} chief.plugin $plugin_name"
    else
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to create symlink: $plugin_file"
      return 1
    fi
    return
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
# Banner indicators: short "label: value" texts shown to the right of the logo, one per logo
# line, in the order of CHIEF_CFG_BANNER_INDICATORS. Each prints nothing when it has nothing
# to say (e.g. alias with no alias set), so it takes no line.
function __chief_banner_indicator() {
  case "$1" in
    alias)
      [[ -n ${CHIEF_CFG_ALIAS:-} ]] && printf '%s' "alias: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_ALIAS}${CHIEF_NO_COLOR}"
      ;;
    plugins)
      # What's loaded (core + contrib + user) and what's turned off, then where user
      # plugins come from. Auto-update off is a normal choice, so it isn't shown in red.
      local on=0 off=0 source
      on=$(( $(__chief_list_count "$(__chief_get_core_plugins)") \
           + $(__chief_list_count "$(__chief_get_contrib_plugins enabled)") \
           + $(__chief_list_count "$(__chief_get_plugins)") ))
      off=$(( $(__chief_list_count "$(__chief_get_core_plugins_disabled)") \
            + $(__chief_list_count "$(__chief_plugin_normalize_disabled_list "${CHIEF_CFG_PLUGINS_DISABLED_USER:-}")") ))
      if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]]; then
        if ${CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE:-false}; then
          source="git, ${CHIEF_COLOR_GREEN}auto-update${CHIEF_NO_COLOR}"
        else
          source="git, manual update"
        fi
      else
        source="local"
      fi
      local counts="${CHIEF_COLOR_CYAN}${on} on${CHIEF_NO_COLOR}"
      (( off > 0 )) && counts+=", ${off} off"
      printf '%s' "plugins: ${counts} · ${source}"
      ;;
    tracking)
      if __chief_is_disconnected_mode; then
        printf '%s' "mode: ${CHIEF_COLOR_RED}disconnected ${CHIEF_COLOR_YELLOW}(no git)${CHIEF_NO_COLOR}"
      else
        local update_branch auto_tag=""
        update_branch="$(__chief_update_branch)"
        __chief_update_branch_auto && auto_tag=", auto"
        if [[ "${update_branch}" == "dev" ]]; then
          printf '%s' "tracking: ${CHIEF_COLOR_YELLOW}${update_branch} ${CHIEF_COLOR_RED}(bleeding-edge${auto_tag})${CHIEF_NO_COLOR}"
        elif [[ "${update_branch}" == "main" ]]; then
          printf '%s' "tracking: ${CHIEF_COLOR_GREEN}${update_branch} ${CHIEF_COLOR_CYAN}(stable${auto_tag})${CHIEF_NO_COLOR}"
        else
          printf '%s' "tracking: ${CHIEF_COLOR_CYAN}${update_branch} ${CHIEF_COLOR_YELLOW}(custom${auto_tag})${CHIEF_NO_COLOR}"
        fi
      fi
      ;;
    secrets)
      __chief_banner_secrets
      ;;
  esac
}

# Count the items in a list separated by "|", "," or spaces. Prints 0 for an empty list.
function __chief_list_count() {
  local items
  read -r -a items <<<"${1//[|,]/ }"
  echo "${#items[@]}"
}

# The "secrets" indicator: loaded / loaded (N) / loaded, silent / not loaded. At start-up it
# says "found" instead: the banner prints before ~/.bash_profile gets a chance to load them.
# Hidden when the secrets plugin is off, or there's no secrets file and nothing is loaded.
function __chief_banner_secrets() {
  declare -F __chief_secrets_loaded_desc >/dev/null || return 0
  local n=${#CHIEF_SECRETS_LOADED[@]} silent=false f
  if (( n > 0 )); then
    for f in "${!CHIEF_SECRETS_LOADED[@]}"; do
      [[ "${CHIEF_SECRETS_LOADED[$f]##*|}" == "yes" ]] && silent=true
    done
    local text="secrets: ${CHIEF_COLOR_GREEN}loaded"
    (( n > 1 )) && text+=" (${n})"
    $silent && text+="${CHIEF_NO_COLOR}, ${CHIEF_COLOR_YELLOW}silent"
    printf '%s' "${text}${CHIEF_NO_COLOR}"
    return 0
  fi
  local file="${CHIEF_SECRETS_FILE:-}"
  if [[ -z "$file" || ! -f "$file" ]]; then
    if [[ -f "$HOME/.chief_user-secrets" ]]; then
      file="$HOME/.chief_user-secrets"
    elif [[ -f "$HOME/.chief_user-vault" ]]; then
      file="$HOME/.chief_user-vault"
    else
      return 0
    fi
  fi
  if [[ "${__chief_starting:-}" == "1" ]]; then
    printf '%s' "secrets: ${CHIEF_COLOR_CYAN}found${CHIEF_NO_COLOR}"
  else
    printf '%s' "secrets: ${CHIEF_COLOR_CYAN}not loaded${CHIEF_NO_COLOR}"
  fi
}

function __chief.banner {
  # Which indicators, in order. Unset: the default list. Set but empty: logo and version only.
  local list="${CHIEF_CFG_BANNER_INDICATORS-alias plugins tracking secrets}"
  list="${list//,/ }"
  # Older configs: an explicit false on the per-line switches still hides that indicator.
  [[ "${CHIEF_CFG_BANNER_SHOW_PLUGINS:-true}" == "false" ]] && list=" ${list} " && list="${list// plugins / }"
  [[ "${CHIEF_CFG_BANNER_SHOW_TRACKING:-true}" == "false" ]] && list=" ${list} " && list="${list// tracking / }"

  # Up to 4 indicators, one per logo line; any beyond that share the last line, joined by " · ".
  local slots=() name text
  for name in $list; do
    text="$(__chief_banner_indicator "$name")"
    [[ -z "$text" ]] && continue
    if (( ${#slots[@]} < 4 )); then
      slots+=("$text")
    else
      slots[3]+=" · ${text}"
    fi
  done

  # CHIEF_CFG_BANNER_STYLE=compact: a 13-column logo (box-drawing characters) that leaves
  # about 12 more columns for the indicators on narrow screens. Indicators sit beside the
  # 3 logo lines (bottom-aligned, extras sharing the last line) and the version goes under
  # the logo, using the space below it. Anything else: the full logo (default).
  if [[ "${CHIEF_CFG_BANNER_STYLE:-full}" == "compact" ]]; then
    # Pre-padded to the same visual width (printf pads by bytes, not characters).
    local small=(
      '┌─┐┬ ┬┬┌─┐┌─┐  '
      '│  ├─┤│├┤ ├┤   '
      '└─┘┴ ┴┴└─┘└    '
    )
    if (( ${#slots[@]} > 3 )); then
      slots[2]+=" · ${slots[3]}"
      unset 'slots[3]'
    fi
    local j cfirst=$(( 3 - ${#slots[@]} ))
    for j in 0 1 2; do
      local cslot=""
      (( j >= cfirst )) && cslot="${slots[$((j - cfirst))]:-}"
      echo -e "${CHIEF_COLOR_YELLOW}${small[$j]}${CHIEF_NO_COLOR}${cslot}${CHIEF_NO_COLOR}"
    done
    echo -e "${CHIEF_VERSION} [${PLATFORM}]"
    __chief_stale_hint
    return 0
  fi

  # Full logo, lines padded to one width so the indicators line up in a single column.
  local art=(
    '        __    _      ____'
    '  _____/ /_  (_)__  / __/'
    ' / ___/ __ \/ / _ \/ /_'
    '/ /__/ / / / /  __/ __/'
  )
  # Bottom-align: with fewer than 4 indicators they sit next to the logo's body, ending
  # just above the version line (the long-standing look), not at its top edge.
  local i pad first=$(( 4 - ${#slots[@]} ))
  for i in 0 1 2 3; do
    pad="$(printf '%-26s' "${art[$i]}")"
    local slot=""
    (( i >= first )) && slot="${slots[$((i - first))]:-}"
    echo -e "${CHIEF_COLOR_YELLOW}${pad}${CHIEF_NO_COLOR}${slot}${CHIEF_NO_COLOR}"
  done
  echo -e "${CHIEF_COLOR_YELLOW}\___/_/ /_/_/\___/_/ ${CHIEF_NO_COLOR}${CHIEF_VERSION} [${PLATFORM}]"
  __chief_stale_hint
}

# Did Chief's files change since this shell loaded them (a manual branch switch, git pull,
# or an update from another terminal)? Compare the loaded version with the VERSION file on
# disk and, if they differ, say how to catch up. Shown under the banner (chief.help,
# chief.status, start-up); silent when they match.
function __chief_stale_hint() {
  local on_disk
  on_disk="$(grep -o 'CHIEF_VERSION="[^"]*"' "${CHIEF_PATH}/VERSION" 2>/dev/null | head -1 | cut -d'"' -f2)"
  [[ -n "$on_disk" && -n "${CHIEF_VERSION:-}" && "$on_disk" != "$CHIEF_VERSION" ]] || return 0
  echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} ${CHIEF_PATH} is now ${on_disk}, but this shell loaded ${CHIEF_VERSION}. Run: ${CHIEF_COLOR_GREEN}chief.reload${CHIEF_NO_COLOR}"
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
    local cmd_prefix=$(__chief_get_command_prefix)
    # If plugins are not set to auto-update, display a message.
    if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]] && ! ${CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE}; then   
      echo -e "${CHIEF_COLOR_GREEN}${cmd_prefix}[tab]${CHIEF_NO_COLOR} for available commands."
      echo -e "${CHIEF_COLOR_GREEN}${cmd_prefix}plugins-update${CHIEF_NO_COLOR} to update/load plugins. | ${CHIEF_COLOR_GREEN}${cmd_prefix}update${CHIEF_NO_COLOR} to update Chief."
    else
      echo -e "${CHIEF_COLOR_GREEN}${cmd_prefix}[tab]${CHIEF_NO_COLOR} for available commands. | ${CHIEF_COLOR_GREEN}${cmd_prefix}update${CHIEF_NO_COLOR} to update Chief.${CHIEF_NO_COLOR}"
    fi
    local user_plugin_list=$(__chief_get_plugins)
    if [[ ${user_plugin_list} != "" ]]; then
      echo -e "${CHIEF_COLOR_GREEN}User plugins: ${CHIEF_COLOR_CYAN}${user_plugin_list}${CHIEF_NO_COLOR}"
    fi
    # Show branch tracking status (only if not already shown in banner)
    if $show_tracking; then
      local update_branch
      update_branch="$(__chief_update_branch)"
      if __chief_update_branch_auto; then
        # Auto mode: switching is a checkout away; no config change needed.
        local other=main
        [[ "${update_branch}" == "main" ]] && other=dev
        echo -e "${CHIEF_COLOR_CYAN}Tracking: ${CHIEF_COLOR_GREEN}${update_branch}${CHIEF_COLOR_CYAN} (auto: follows ${CHIEF_PATH}) | switch: ${CHIEF_COLOR_GREEN}git -C ${CHIEF_PATH} switch ${other}${CHIEF_NO_COLOR}"
      elif [[ "${update_branch}" == "dev" ]]; then
        echo -e "${CHIEF_COLOR_CYAN}Tracking: ${CHIEF_COLOR_YELLOW}${update_branch}${CHIEF_COLOR_RED} (bleeding-edge)${CHIEF_COLOR_CYAN} branch | ${CHIEF_COLOR_GREEN}chief.config-set update_branch main${CHIEF_COLOR_CYAN} for stable${CHIEF_NO_COLOR}"
      elif [[ "${update_branch}" == "main" ]]; then
        echo -e "${CHIEF_COLOR_CYAN}Tracking: ${CHIEF_COLOR_GREEN}${update_branch}${CHIEF_COLOR_CYAN} (stable) branch | ${CHIEF_COLOR_GREEN}chief.config-set update_branch dev${CHIEF_COLOR_CYAN} for latest features${CHIEF_NO_COLOR}"
      else
        echo -e "${CHIEF_COLOR_CYAN}Tracking: ${CHIEF_COLOR_CYAN}${update_branch}${CHIEF_COLOR_YELLOW} (custom)${CHIEF_COLOR_CYAN} branch | ${CHIEF_COLOR_GREEN}chief.config-set update_branch main${CHIEF_COLOR_CYAN} for stable${CHIEF_NO_COLOR}"
      fi
    fi
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Essential Commands:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR} to edit configuration file | ${CHIEF_COLOR_GREEN}chief.config-set <option> <value>${CHIEF_NO_COLOR} to set config directly
    - ${CHIEF_COLOR_GREEN}chief.config-update${CHIEF_NO_COLOR} to update config with new template options"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.help${CHIEF_NO_COLOR} for comprehensive help | ${CHIEF_COLOR_GREEN}chief.help --compact${CHIEF_NO_COLOR} for quick reference"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.whereis <name>${CHIEF_NO_COLOR} to find any function/alias location"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.secrets_*${CHIEF_NO_COLOR} to encrypt/decrypt secrets file (ansible-vault or gpg) | ${CHIEF_COLOR_GREEN}chief.vault_*${CHIEF_NO_COLOR} for HashiCorp Vault read/write"
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Quick Customization:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config-set prompt true${CHIEF_NO_COLOR} for git-aware prompt | ${CHIEF_COLOR_GREEN}chief.git_legend${CHIEF_NO_COLOR} for colors"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config-set multiline_prompt true${CHIEF_NO_COLOR} for multi-line prompt"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config-set short_path true${CHIEF_NO_COLOR} for compact directory paths"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config-set --list${CHIEF_NO_COLOR} to see all available configuration options"
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Plugin Management:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugin [name]${CHIEF_NO_COLOR} to create/edit plugins | ${CHIEF_COLOR_GREEN}chief.plugin -?${CHIEF_NO_COLOR} to list"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugin status${CHIEF_NO_COLOR} to see enabled/disabled plugins"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugins-root${CHIEF_NO_COLOR} to navigate to plugins directory"
    local _core_dis _user_dis _c_fmt _u_fmt
    _core_dis="$(__chief_plugin_normalize_disabled_list "${CHIEF_CFG_PLUGINS_DISABLED_CORE:-}")"
    _user_dis="$(__chief_plugin_normalize_disabled_list "${CHIEF_CFG_PLUGINS_DISABLED_USER:-}")"
    if [[ -n "$_core_dis" ]] || [[ -n "$_user_dis" ]]; then
      _c_fmt="$(__chief_format_plugin_list "${_core_dis:-}")"
      _u_fmt="$(__chief_format_plugin_list "${_user_dis:-}")"
      echo -e "- ${CHIEF_COLOR_YELLOW}Disabled:${CHIEF_NO_COLOR} ${CHIEF_COLOR_CYAN}core:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}${_c_fmt:-<none>}${CHIEF_NO_COLOR}; ${CHIEF_COLOR_CYAN}user:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}${_u_fmt:-<none>}${CHIEF_NO_COLOR}"
    fi
    echo ""
    if [[ ${1} != '--verbose' ]]; then
      echo -e "${CHIEF_COLOR_CYAN}** Run ${CHIEF_COLOR_GREEN}chief.config-set hints=false${CHIEF_COLOR_CYAN} to disable these hints. **${CHIEF_NO_COLOR}"
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
      local cmd_prefix=$(__chief_get_command_prefix)
      __chief.banner
      echo
      __chief_show_chief_stats
      echo
      echo -e "${CHIEF_COLOR_YELLOW}Available help categories:${CHIEF_NO_COLOR}"
      echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}help commands${CHIEF_NO_COLOR}  - Core commands and usage"
      echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}help plugins${CHIEF_NO_COLOR}   - Plugin management"
      echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}help config${CHIEF_NO_COLOR}    - Configuration options"
      echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}help --compact${CHIEF_NO_COLOR} - Quick reference"
      echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}hints${CHIEF_NO_COLOR}          - Quick tips and workflow"
      echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}status${CHIEF_NO_COLOR}         - Banner + stats (incl. disabled plugins)"
      echo
      echo -e "${CHIEF_COLOR_CYAN}Quick start: ${CHIEF_COLOR_GREEN}${cmd_prefix}[tab][tab]${CHIEF_NO_COLOR} to see all commands"
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

# Show Chief status (banner + stats including enabled/disabled plugins)
function chief.status() {
  __chief.banner
  echo
  __chief_show_chief_stats
  # Secrets loaded into this shell, and how (manually, by a start-up file, silently...).
  if declare -F __chief_secrets_loaded_report >/dev/null; then
    __chief_secrets_loaded_report
  else
    echo -e "${CHIEF_COLOR_MAGENTA}Secrets:${CHIEF_NO_COLOR} secrets plugin is off (chief.plugin enable core.secrets)"
  fi
  case "$(__chief_dev_tools_state)" in
    active)  echo -e "${CHIEF_COLOR_MAGENTA}Dev tools:${CHIEF_NO_COLOR} active (chief.release_status, chief.release_prepare, chief.release_publish)" ;;
    branch)  echo -e "${CHIEF_COLOR_MAGENTA}Dev tools:${CHIEF_NO_COLOR} on, but inactive: ${CHIEF_PATH} is not on the dev branch (they only load on dev)" ;;
    missing) echo -e "${CHIEF_COLOR_MAGENTA}Dev tools:${CHIEF_NO_COLOR} on, but this checkout has no libs/dev (release archive?)" ;;
  esac
}

# Directory Chief loads keys from: CHIEF_CFG_SSH_KEYS_PATH if set, otherwise ~/.ssh.
function __chief_ssh_keys_path() {
  echo "${CHIEF_CFG_SSH_KEYS_PATH:-$HOME/.ssh}"
}

# Should Chief load SSH keys at start-up / reload? CHIEF_CFG_SSH_LOAD_KEYS=true|false.
# Configs from before that switch existed don't have it: there, a set CHIEF_CFG_SSH_KEYS_PATH
# meant "auto-load", so keep honoring that.
function __chief_ssh_autoload_on() {
  if [[ -n "${CHIEF_CFG_SSH_LOAD_KEYS:-}" ]]; then
    [[ "${CHIEF_CFG_SSH_LOAD_KEYS}" == true ]]
    return
  fi
  [[ -n "${CHIEF_CFG_SSH_KEYS_PATH:-}" ]]
}

function __chief_load_ssh_keys() {
  local keys_path
  keys_path="$(__chief_ssh_keys_path)"
  __chief_print "Loading SSH keys from: ${keys_path}..." "$1"


  # Platform-specific SSH setup
  local load
  if [[ ${PLATFORM} == "MacOS" ]]; then
    load="/usr/bin/ssh-add --apple-use-keychain"
  elif [[ $(uname) == "Linux" ]]; then
    # Linux SSH agent setup
    load="/usr/bin/ssh-add"

    # Simple and reliable SSH agent setup
    if [[ -n "$SSH_AUTH_SOCK" ]] && ssh-add -l >/dev/null 2>&1; then
      # SSH agent is already running and accessible
      if ${CHIEF_CFG_VERBOSE} || [[ "${1}" == '--verbose' ]]; then
        __chief_print "Using existing SSH agent (PID: ${SSH_AGENT_PID:-unknown})" "$1"
      fi
    else
      # Start SSH agent using standard approach
      if ${CHIEF_CFG_VERBOSE} || [[ "${1}" == '--verbose' ]]; then
        __chief_print "Starting SSH agent..." "$1"
      fi
      eval "$(ssh-agent -s)" >/dev/null
      if ${CHIEF_CFG_VERBOSE} || [[ "${1}" == '--verbose' ]]; then
        __chief_print "SSH agent started (PID: ${SSH_AGENT_PID})" "$1"
      fi
    fi
  else
    # Default for other platforms
    load="/usr/bin/ssh-add"
  fi

  # Validate that the keys directory exists
  if [[ ! -d "${keys_path}" ]]; then
    __chief_print "SSH keys directory does not exist: ${keys_path}" "$1"
    return 1
  fi


  # Load SSH keys with custom naming conventions
  local key_count=0
  local loaded_keys=()
  local verbose_mode=false
  
  if ${CHIEF_CFG_VERBOSE} || [[ "${1}" == '--verbose' ]]; then
    verbose_mode=true
  fi
  
  # 1. Load keys with .key extension (Chief's preferred naming)
  for ssh_key in "${keys_path}"/*.key; do
    # Check if glob matched actual files
    if [[ -f "${ssh_key}" ]]; then
      local key_name=$(basename "$ssh_key")
      
      # Skip if already loaded (avoid duplicates)
      local already_loaded=false
      for loaded_key in "${loaded_keys[@]}"; do
        if [[ "$loaded_key" == "$key_name" ]]; then
          already_loaded=true
          break
        fi
      done
      
      if [[ "$already_loaded" == false ]]; then
        # Show loading message (like macOS)
        __chief_print "Loading key: ${ssh_key}" "$1"
        
        # Attempt to load the key
        if ${load} "${ssh_key}" 2>/dev/null; then
          loaded_keys+=("$key_name")
          ((key_count++))
        elif [[ "$verbose_mode" == true ]]; then
          # Only show errors in verbose mode
          local load_output
          load_output=$(${load} "${ssh_key}" 2>&1)
          __chief_print "Failed to load key: ${ssh_key}" "$1"
          __chief_print "Error: ${load_output}" "$1"
        fi
      fi
    fi
  done
  
  # 2. Load keys with .private extension (legacy support)
  for ssh_key in "${keys_path}"/*.private; do
    # Check if glob matched actual files
    if [[ -f "${ssh_key}" ]]; then
      local key_name=$(basename "$ssh_key")
      
      # Skip if already loaded (avoid duplicates)
      local already_loaded=false
      for loaded_key in "${loaded_keys[@]}"; do
        if [[ "$loaded_key" == "$key_name" ]]; then
          already_loaded=true
          break
        fi
      done
      
      if [[ "$already_loaded" == false ]]; then
        # Show loading message (like macOS)
        __chief_print "Loading key: ${ssh_key}" "$1"
        
        # Attempt to load the key
        if ${load} "${ssh_key}" 2>/dev/null; then
          loaded_keys+=("$key_name")
          ((key_count++))
        elif [[ "$verbose_mode" == true ]]; then
          # Only show errors in verbose mode
          local load_output
          load_output=$(${load} "${ssh_key}" 2>&1)
          __chief_print "Failed to load key: ${ssh_key}" "$1"
          __chief_print "Error: ${load_output}" "$1"
        fi
      fi
    fi
  done
  # Report results
  if [[ ${key_count} -eq 0 ]]; then
    if [[ "$verbose_mode" == true ]]; then
      __chief_print "No SSH keys found in ${keys_path}" "$1"
      __chief_print "Supported file patterns: *.key, *.private" "$1"
    fi
  else
    if [[ "$verbose_mode" == true ]]; then
      __chief_print "Loaded ${key_count} SSH key(s): ${loaded_keys[*]}" "$1"
    fi
  fi

  # Too many keys in the agent can exhaust the server's MaxAuthTries; explain the fix.
  # Explicit loads (--verbose) always show it; start-up shows it once per machine.
  if [[ "${1}" == '--verbose' ]]; then
    __chief_ssh_key_limit_hint "$(__chief_ssh_agent_key_count)" --always
  else
    __chief_ssh_key_limit_hint "$(__chief_ssh_agent_key_count)"
  fi
}

# Build Git / VirtualEnv prompt
function __chief_build_git_prompt() {
  # Usage: PROMPT_COMMAND='__chief_build_git_prompt'
  # Needed because PROMPT_COMMAND doesn't 'echo -e' and this also fixes the nasty
  # wrapping bug when the prompt is colorized and a VE is activated.
  # Note: Using \[ \] sequences for non-printing characters in prompts;
  # colors follow the same TTY / TERM / NO_COLOR rules as CHIEF_COLOR_*.
  local P_BLUE P_CYAN P_GREEN P_MAGENTA P_YELLOW P_NO_COLOR
  if ${CHIEF_CFG_COLORED_PROMPT}; then
    P_BLUE="\[${CHIEF_COLOR_BLUE}\]"
    P_CYAN="\[${CHIEF_COLOR_CYAN}\]"
    P_GREEN="\[${CHIEF_COLOR_GREEN}\]"
    P_MAGENTA="\[${CHIEF_COLOR_MAGENTA}\]"
    P_YELLOW="\[${CHIEF_COLOR_YELLOW}\]"
    P_NO_COLOR="\[${CHIEF_NO_COLOR}\]"
  else
    P_BLUE=''
    P_CYAN=''
    P_GREEN=''
    P_MAGENTA=''
    P_YELLOW=''
    P_NO_COLOR=''
  fi

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
  # Skip update checks in disconnected mode
  if __chief_is_disconnected_mode; then
    echo -e "${CHIEF_COLOR_YELLOW}Update checks disabled in disconnected mode.${CHIEF_NO_COLOR}"
    return 0
  fi
  
  cd ${CHIEF_PATH}
  local CHANGE_MSG="${CHIEF_COLOR_GREEN}**Chief updates available**${CHIEF_NO_COLOR}"

  # Branch to update from: the configured pin, or (auto) the checkout's own branch
  local TARGET_BRANCH
  TARGET_BRANCH="$(__chief_update_branch)"
  
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

# ANSI SGR colors (no tput): emit only when stdout is a color-capable TTY.
# Honors NO_COLOR (https://no-color.org/). Set CHIEF_FORCE_COLOR to a non-empty
# value to enable sequences when stdout is not a TTY (e.g. scripted demos).

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

__chief_stdout_color_ok() {
  [[ -z "${NO_COLOR:-}" ]] || return 1
  [[ -n "${CHIEF_FORCE_COLOR:-}" ]] && return 0
  [[ -t 1 && -n "${TERM:-}" && "${TERM}" != dumb ]]
}

if __chief_stdout_color_ok; then
  export CHIEF_COLOR_RED='\033[0;31m'
  export CHIEF_COLOR_BLUE='\033[0;34m'
  export CHIEF_COLOR_CYAN='\033[0;36m'
  export CHIEF_COLOR_GREEN='\033[0;32m'
  export CHIEF_COLOR_MAGENTA='\033[0;35m'
  export CHIEF_COLOR_ORANGE='\033[0;33m'
  export CHIEF_COLOR_YELLOW='\033[1;33m'
  export CHIEF_TEXT_BLINK='\033[5m'
  export CHIEF_NO_COLOR='\033[0m'
else
  export CHIEF_COLOR_RED=''
  export CHIEF_COLOR_BLUE=''
  export CHIEF_COLOR_CYAN=''
  export CHIEF_COLOR_GREEN=''
  export CHIEF_COLOR_MAGENTA=''
  export CHIEF_COLOR_ORANGE=''
  export CHIEF_COLOR_YELLOW=''
  export CHIEF_TEXT_BLINK=''
  export CHIEF_NO_COLOR=''
fi

# Gutter for framework status during load (lines without this prefix may be plugin output). Word "Chief" is reserved for rare bookends (e.g. chief.reload).
export CHIEF_FRAMEWORK_MSG_PREFIX="${CHIEF_COLOR_CYAN}│${CHIEF_NO_COLOR} "

function __chief_framework_print() {
  if ${CHIEF_CFG_VERBOSE} || [[ "${2}" == '--verbose' ]]; then
    echo -e "${CHIEF_FRAMEWORK_MSG_PREFIX}${1}"
  fi
}

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

# STEP PROGRESS (live task list)
########################################################################
# Shared progress UI for multi-step Chief commands. Steps are shown as they happen:
#   ✓ done   ⠋ running   · pending (status views)   ↷ skipped   ✗ failed   ○ would (dry run)
# Output is append-only: a finished step is printed once and never redrawn. In a terminal,
# only the line of the step that is running updates in place (spinner + detail), so nothing
# can be duplicated whatever the terminal size, locale, or other output. When stdout is not
# a terminal (pipe, file, CI), NO_COLOR is set, or CHIEF_STEPS_PLAIN=1, there is no spinner.
#
# Usage (internal, for Chief commands):
#   __chief_steps_begin "Title" "Step one" "Step two" ...
#   __chief_steps_start [detail]            mark the next step as running
#   __chief_steps_tick [detail]             advance the spinner (polling loops)
#   __chief_steps_done [detail]             ✓ the current step
#   __chief_steps_skip [reason]             ↷ the current step (already done / not needed)
#   __chief_steps_would [detail]            ○ the current step (dry run)
#   __chief_steps_fail "reason" [hint...]   ✗ the current step, print reason and hints; returns 1
#   __chief_steps_exec <command> [args...]  run a step's command with a spinner; output goes to
#                                           $__CHIEF_STEPS_LOG and is shown if it fails
#   __chief_steps_ask "Question?" [preview] pause on the current step for y/N; 0 = yes.
#                                           CHIEF_STEPS_ASSUME_YES=1 answers yes without asking.
#   __chief_steps_note "text"               print a line that stays (e.g. problems found)
#   __chief_steps_end ["Summary title" [line...]]  finish and print a summary
# Steps are taken in order; each start/done/skip/would/fail call applies to the current step.

__CHIEF_STEPS_NAMES=()
__CHIEF_STEPS_STATE=()
__CHIEF_STEPS_DETAIL=()
__CHIEF_STEPS_CUR=-1
__CHIEF_STEPS_LIVE=false
__CHIEF_STEPS_FRAME=0
__CHIEF_STEPS_COLS=80
__CHIEF_STEPS_SHOWING=false   # a running line is on screen (no newline yet)
__CHIEF_STEPS_LOG=""

function __chief_steps_cur_state() {
  ((__CHIEF_STEPS_CUR >= 0)) && echo "${__CHIEF_STEPS_STATE[__CHIEF_STEPS_CUR]}"
}

# Current terminal width (the real one, not a possibly stale $COLUMNS) into __CHIEF_STEPS_COLS.
function __chief_steps_width() {
  local size cols=""
  size="$(stty size </dev/tty 2>/dev/null)" && cols="${size##* }"
  [[ "$cols" =~ ^[0-9]+$ && "$cols" -gt 0 ]] || cols="${COLUMNS:-}"
  [[ "$cols" =~ ^[0-9]+$ && "$cols" -gt 0 ]] || cols="$(tput cols 2>/dev/null)"
  [[ "$cols" =~ ^[0-9]+$ && "$cols" -gt 0 ]] || cols=80
  __CHIEF_STEPS_COLS="$cols"
}

# Cut text to at most <max> characters. Used for the line that updates in place (it must
# not wrap, or "\r" would only clear its last row) and for question lines.
function __chief_steps_fit() { # <text> <max>
  local text="$1" max="$2"
  ((max < 4)) && max=4
  if ((${#text} > max)); then echo "${text:0:max-3}..."; else echo "$text"; fi
}

function __chief_steps_live_ok() {
  [[ -z "${CHIEF_STEPS_PLAIN:-}" && -z "${NO_COLOR:-}" ]] || return 1
  [[ -t 1 && -n "${TERM:-}" && "${TERM}" != dumb ]]
}

function __chief_steps_begin() {
  local title="$1"; shift
  __CHIEF_STEPS_NAMES=("$@")
  __CHIEF_STEPS_STATE=()
  __CHIEF_STEPS_DETAIL=()
  local i
  for ((i = 0; i < ${#__CHIEF_STEPS_NAMES[@]}; i++)); do
    __CHIEF_STEPS_STATE[i]="pending"
    __CHIEF_STEPS_DETAIL[i]=""
  done
  __CHIEF_STEPS_CUR=-1
  __CHIEF_STEPS_FRAME=0
  __CHIEF_STEPS_SHOWING=false
  __CHIEF_STEPS_LOG="${TMPDIR:-/tmp}/chief-steps.$$.log"
  : > "$__CHIEF_STEPS_LOG" 2>/dev/null
  __CHIEF_STEPS_LIVE=false
  if __chief_steps_live_ok; then
    __CHIEF_STEPS_LIVE=true
    __chief_steps_width
  fi
  [[ -n "$title" ]] && echo -e "${CHIEF_COLOR_CYAN}${title}${CHIEF_NO_COLOR}\n"
  return 0
}

# Build step i's line into __CHIEF_STEPS_LINE (colored) and __CHIEF_STEPS_PLAIN (no color).
function __chief_steps_line() {
  local i="$1" sym color text
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local name="${__CHIEF_STEPS_NAMES[i]}" detail="${__CHIEF_STEPS_DETAIL[i]}"
  case "${__CHIEF_STEPS_STATE[i]}" in
    done)    sym="✓"; color="$CHIEF_COLOR_GREEN" ;;
    running) sym="${frames[__CHIEF_STEPS_FRAME % 10]}"; color="$CHIEF_COLOR_CYAN" ;;
    skip)    sym="↷"; color="$CHIEF_COLOR_YELLOW" ;;
    fail)    sym="✗"; color="$CHIEF_COLOR_RED" ;;
    would)   sym="○"; color="$CHIEF_COLOR_BLUE" ;;
    ask)     sym="?"; color="$CHIEF_COLOR_YELLOW" ;;
    *)       sym="·"; color="" ;;
  esac
  text="$name"
  case "${__CHIEF_STEPS_STATE[i]}" in
    fail)    [[ -n "$detail" ]] && text+=": $detail" ;;
    would)   text="Would: $name"; [[ -n "$detail" ]] && text+=" ($detail)" ;;
    running) [[ -n "$detail" ]] && text+=" ($detail)"; text+="..." ;;
    *)       [[ -n "$detail" ]] && text+=" ($detail)" ;;
  esac
  # Only the in-place (running) line must fit on one row; finished lines may wrap freely.
  if $__CHIEF_STEPS_LIVE && [[ "${__CHIEF_STEPS_STATE[i]}" == running ]]; then
    text="$(__chief_steps_fit "$text" $((__CHIEF_STEPS_COLS - 5)))"
  fi
  __CHIEF_STEPS_PLAIN="  $sym $text"
  __CHIEF_STEPS_LINE="  ${color}${sym}${CHIEF_NO_COLOR} $text"
}

# Clear the running line (if one is on screen) so permanent output can be printed.
function __chief_steps_clear_running() {
  if $__CHIEF_STEPS_SHOWING; then
    printf '\r\033[K'
    __CHIEF_STEPS_SHOWING=false
  fi
}

# Show the running step's line in place (terminal mode only).
function __chief_steps_show_running() {
  $__CHIEF_STEPS_LIVE || return 0
  ((__CHIEF_STEPS_CUR >= 0)) || return 0
  [[ "${__CHIEF_STEPS_STATE[__CHIEF_STEPS_CUR]}" == running ]] || return 0
  __chief_steps_line "$__CHIEF_STEPS_CUR"
  printf '\r\033[K%b' "$__CHIEF_STEPS_LINE"
  __CHIEF_STEPS_SHOWING=true
}

# Set the current step's state. Running: shown in place. Anything else: printed once.
function __chief_steps_set() {
  local state="$1" detail="$2"
  ((__CHIEF_STEPS_CUR >= 0)) || return 0
  __CHIEF_STEPS_STATE[__CHIEF_STEPS_CUR]="$state"
  __CHIEF_STEPS_DETAIL[__CHIEF_STEPS_CUR]="$detail"
  if [[ "$state" == running ]]; then
    $__CHIEF_STEPS_LIVE && __chief_steps_width && __chief_steps_show_running
  elif [[ "$state" != ask ]]; then
    __chief_steps_clear_running
    __chief_steps_line "$__CHIEF_STEPS_CUR"
    printf '%b\n' "$__CHIEF_STEPS_LINE"
  fi
  return 0
}

function __chief_steps_start() {
  ((__CHIEF_STEPS_CUR < ${#__CHIEF_STEPS_NAMES[@]} - 1)) && __CHIEF_STEPS_CUR=$((__CHIEF_STEPS_CUR + 1))
  __chief_steps_set running "$1"
}

function __chief_steps_tick() {
  __CHIEF_STEPS_FRAME=$((__CHIEF_STEPS_FRAME + 1))
  [[ $# -gt 0 && $__CHIEF_STEPS_CUR -ge 0 ]] && __CHIEF_STEPS_DETAIL[__CHIEF_STEPS_CUR]="$1"
  __chief_steps_show_running
}

function __chief_steps_done()  { __chief_steps_set done "$1"; }
function __chief_steps_skip()  { __chief_steps_set skip "$1"; }

function __chief_steps_note() {
  __chief_steps_clear_running
  echo -e "$1"
  __chief_steps_show_running
}

function __chief_steps_would() {
  # A dry-run step may be marked without being started first.
  [[ "$(__chief_steps_cur_state)" == running ]] || __CHIEF_STEPS_CUR=$((__CHIEF_STEPS_CUR + 1))
  __chief_steps_set would "$1"
}

function __chief_steps_fail() {
  local reason="$1"; shift
  __chief_steps_set fail "$reason"
  local hint
  for hint in "$@"; do
    echo -e "    $hint"
  done
  return 1
}

function __chief_steps_exec() {
  local rc pid
  : > "$__CHIEF_STEPS_LOG" 2>/dev/null
  [[ "$(__chief_steps_cur_state)" == running ]] || __chief_steps_start
  if $__CHIEF_STEPS_LIVE; then
    # Run external commands in their own session, without the terminal, so nothing they
    # write straight to /dev/tty lands on the spinner line. Shell functions (e.g. git push
    # wrappers) keep the terminal so auth prompts still work.
    local -a runner=()
    if [[ "$(type -t "$1")" == file ]] && command -v perl >/dev/null 2>&1; then
      runner=(perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV or die "cannot run $ARGV[0]: $!\n"' --)
    fi
    # Start it from a short-lived subshell: a background job of the interactive shell itself
    # makes bash print "[1] 12345" (even with job control off), which breaks the spinner line.
    local rcfile="${__CHIEF_STEPS_LOG}.rc"
    rm -f "$rcfile"
    pid="$(
      { ${runner[@]+"${runner[@]}"} "$@" >>"$__CHIEF_STEPS_LOG" 2>&1 </dev/null; echo $? > "$rcfile"; } >/dev/null 2>&1 &
      echo $!
    )"
    while kill -0 "$pid" 2>/dev/null; do
      __chief_steps_tick
      sleep 0.1
    done
    rc="$(cat "$rcfile" 2>/dev/null)"
    rm -f "$rcfile"
    [[ "$rc" =~ ^[0-9]+$ ]] || rc=1
  else
    "$@" >>"$__CHIEF_STEPS_LOG" 2>&1 </dev/null; rc=$?
  fi
  return $rc
}

# One-command spinner: run <command>, show a spinner with <message> while it runs, then clear
# the line and put everything the command printed into the variable named <output_variable>.
# Returns the command's exit code. Same calling convention as chief.etc_spinner (which wraps
# this), but in core, so Chief's own start-up and SSH key loading don't depend on a plugin.
# Like the step helper: started from a short-lived subshell (no "[1] 12345" job notices),
# the line is fit to the terminal width, and there's no animation when not on a terminal.
# --legacy: the original Chief look, "message [|]" turning through | / - \ at the original pace.
# Usage: __chief_spin [--legacy] <message> <command> [output_variable]
function __chief_spin() {
  local __cs_legacy=false
  [[ "$1" == --legacy ]] && __cs_legacy=true && shift
  local __cs_msg="$1" __cs_cmd="$2" __cs_var="${3:-}" __cs_out __cs_rc __cs_pid __cs_f=0
  local -a __cs_frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local -a __cs_classic=('|' '/' '-' '\')
  __cs_out="$(mktemp "${TMPDIR:-/tmp}/chief-spin.XXXXXX")" || return 1
  if __chief_steps_live_ok; then
    __chief_steps_width
    __cs_msg="$(__chief_steps_fit "$__cs_msg" $((__CHIEF_STEPS_COLS - 6)))"
    __cs_pid="$(
      { eval "$__cs_cmd" >"$__cs_out" 2>&1; echo $? > "${__cs_out}.rc"; } >/dev/null 2>&1 &
      echo $!
    )"
    while kill -0 "$__cs_pid" 2>/dev/null; do
      if $__cs_legacy; then
        # Original look and pace: a new character about every 0.75s, checked every 0.25s.
        printf '\r\033[K%s [%s]' "$__cs_msg" "${__cs_classic[(__cs_f / 3) % 4]}"
        sleep 0.25
      else
        printf '\r\033[K%b%s%b %s' "$CHIEF_COLOR_CYAN" "${__cs_frames[__cs_f % 10]}" "$CHIEF_NO_COLOR" "$__cs_msg"
        sleep 0.1
      fi
      __cs_f=$((__cs_f + 1))
    done
    printf '\r\033[K'
    __cs_rc="$(cat "${__cs_out}.rc" 2>/dev/null)"
    rm -f "${__cs_out}.rc"
    [[ "$__cs_rc" =~ ^[0-9]+$ ]] || __cs_rc=1
  else
    # A subshell, as in terminal mode: an "exit" in the command must not end the caller.
    ( eval "$__cs_cmd" ) >"$__cs_out" 2>&1
    __cs_rc=$?
  fi
  if [[ -n "$__cs_var" ]]; then
    printf -v "$__cs_var" '%s' "$(cat "$__cs_out")"
  fi
  rm -f "$__cs_out"
  return "$__cs_rc"
}

# Show the tail of the step log, indented (used after a failed step).
function __chief_steps_show_log() {
  [[ -s "$__CHIEF_STEPS_LOG" ]] || return 0
  tail -n "${1:-15}" "$__CHIEF_STEPS_LOG" | sed 's/^/      /'
}

function __chief_steps_ask() {
  local question="$1" preview="${2:-}" answer
  if [[ "${CHIEF_STEPS_ASSUME_YES:-}" == 1 ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    __chief_steps_fail "needs confirmation" "No terminal to ask \"$question\"; re-run with --yes to confirm."
    return 1
  fi
  __chief_steps_clear_running
  if $__CHIEF_STEPS_LIVE; then
    # Print the preview and question with lines that never wrap, so after the answer
    # exactly those rows can be cleared again.
    __chief_steps_width
    local rows=0 line max=$((__CHIEF_STEPS_COLS - 1))
    if [[ -n "$preview" ]]; then
      while IFS= read -r line; do
        printf '%s\n' "$(__chief_steps_fit "$line" "$max")"
        rows=$((rows + 1))
      done < <(printf '%b\n' "$preview")
    fi
    read -r -p "  ? $(__chief_steps_fit "$question" $((__CHIEF_STEPS_COLS - 13))) [y/N] " answer
    rows=$((rows + 1))
    printf '\033[%dA\r\033[J' "$rows"
  else
    [[ -n "$preview" ]] && printf '%b\n' "$preview"
    read -r -p "  ? ${question} [y/N] " answer
  fi
  __chief_steps_show_running
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

function __chief_steps_end() {
  local title="${1:-}"; shift
  __chief_steps_clear_running
  [[ -n "$__CHIEF_STEPS_LOG" ]] && rm -f "$__CHIEF_STEPS_LOG" 2>/dev/null
  [[ -z "$title" ]] && return 0
  echo
  echo -e "${CHIEF_COLOR_GREEN}${title}${CHIEF_NO_COLOR}"
  local line
  for line in "$@"; do
    echo -e "  $line"
  done
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

function chief.ssh_load-keys() {
  local USAGE="Usage: $FUNCNAME

Load SSH keys from ~/.ssh (or CHIEF_CFG_SSH_KEYS_PATH if set) into ssh-agent.
To load them automatically at start-up: chief.config-set ssh_load_keys true
Supported key file patterns:
- *.key (Chief preferred naming)
- *.private (legacy support)
This supports RSA, ed25519, and other key types. Symlinks are allowed for selective loading.
Note: Standard SSH keys (id_rsa, id_ed25519, etc.) are automatically used by SSH clients and don't need to be loaded.

Many keys: SSH servers count every key offered and disconnect after MaxAuthTries (often 3-6), so with
${CHIEF_SSH_KEYS_WARN_AT}+ keys loaded the right one may never be tried (\"Too many authentication failures\").
Pin a key to each host so ssh offers only that key: chief.ssh_host-key <host> <key>
Check which hosts are pinned: chief.ssh_status
"

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  __chief_spin "Loading SSH keys..." "__chief_load_ssh_keys --verbose" tmp_out
  echo -e "${tmp_out}"
}

function chief.ssh_status() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Show SSH agent status and list loaded keys.

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Check if SSH agent is running
- List loaded SSH keys (same as ssh-add -l)
- Show SSH agent environment variables
- Diagnose SSH agent connection issues

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Show SSH agent status
  ssh-add -l                   # Direct command (equivalent)
"

  if [[ $1 == "-?" ]] || [[ $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_BLUE}SSH Agent Status:${CHIEF_NO_COLOR}"
  
  # Check environment variables
  if [[ -n "$SSH_AUTH_SOCK" ]]; then
    echo -e "• SSH_AUTH_SOCK: ${CHIEF_COLOR_GREEN}$SSH_AUTH_SOCK${CHIEF_NO_COLOR}"
  else
    echo -e "• SSH_AUTH_SOCK: ${CHIEF_COLOR_RED}Not set${CHIEF_NO_COLOR}"
  fi
  
  if [[ -n "$SSH_AGENT_PID" ]]; then
    echo -e "• SSH_AGENT_PID: ${CHIEF_COLOR_GREEN}$SSH_AGENT_PID${CHIEF_NO_COLOR}"
    
    # Check if process is still running
    if kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
      echo -e "• Agent Process: ${CHIEF_COLOR_GREEN}Running${CHIEF_NO_COLOR}"
    else
      echo -e "• Agent Process: ${CHIEF_COLOR_RED}Not running (stale PID)${CHIEF_NO_COLOR}"
    fi
  else
    echo -e "• SSH_AGENT_PID: ${CHIEF_COLOR_RED}Not set${CHIEF_NO_COLOR}"
  fi
  
  echo
  echo -e "${CHIEF_COLOR_BLUE}Loaded Keys:${CHIEF_NO_COLOR}"
  
  # Try to list keys
  local ssh_result
  if ssh_result=$(ssh-add -l 2>&1); then
    if [[ "$ssh_result" == "The agent has no identities." ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}No keys loaded in SSH agent${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_GREEN}$ssh_result${CHIEF_NO_COLOR}"
    fi
  else
    echo -e "${CHIEF_COLOR_RED}Error: $ssh_result${CHIEF_NO_COLOR}"
    echo
    echo -e "${CHIEF_COLOR_YELLOW}Troubleshooting:${CHIEF_NO_COLOR}"
    echo "• Try: eval \$(ssh-agent) && ssh-add"
    echo "• Or reload Chief: chief.reload"
    echo "• Or load Chief keys: chief.ssh_load-keys"
  fi

  # Key-limit check: many agent keys + hosts that don't pin a key
  local agent_keys cfg missing
  agent_keys=$(__chief_ssh_agent_key_count)
  cfg="${CHIEF_SSH_CONFIG:-$HOME/.ssh/config}"
  echo
  echo -e "${CHIEF_COLOR_BLUE}Key pinning (${cfg}):${CHIEF_NO_COLOR}"
  # Only matters when many keys are in the agent; stay quiet otherwise.
  if [[ "$agent_keys" -lt "${CHIEF_SSH_KEYS_WARN_AT}" ]]; then
    echo -e "${CHIEF_COLOR_GREEN}${agent_keys} key(s) in ssh-agent: under the limit, nothing to pin.${CHIEF_NO_COLOR}"
    return 0
  fi
  if [[ ! -f "$cfg" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}No ssh config file.${CHIEF_NO_COLOR} Pin a key to a host with: chief.ssh_host-key <host> <key>"
  else
    missing=$(__chief_ssh_hosts_without_identitiesonly "$cfg")
    if [[ "$missing" == "__ALL__" ]]; then
      echo -e "${CHIEF_COLOR_GREEN}All hosts use IdentitiesOnly (set under Host *).${CHIEF_NO_COLOR}"
    elif [[ -z "$missing" ]]; then
      echo -e "${CHIEF_COLOR_GREEN}Every named host pins its key (IdentitiesOnly yes).${CHIEF_NO_COLOR}"
    else
      echo -e "Hosts without ${CHIEF_COLOR_CYAN}IdentitiesOnly yes${CHIEF_NO_COLOR} (ssh may offer every agent key):"
      echo "$missing" | sed 's/^/  • /'
      echo -e "Fix one with: ${CHIEF_COLOR_GREEN}chief.ssh_host-key <host> <key>${CHIEF_NO_COLOR}   (preview with --dry-run)"
      __chief_ssh_key_names_line
    fi
  fi
}

# SSH servers count every key the client offers as one authentication attempt and disconnect
# after MaxAuthTries (OpenSSH default 6; many servers use fewer). With this many keys in the
# agent, the right key may never be offered ("Too many authentication failures").
CHIEF_SSH_KEYS_WARN_AT=3

# Number of identities currently in ssh-agent (0 if none or no agent).
function __chief_ssh_agent_key_count() {
  local out
  out=$(ssh-add -l 2>/dev/null) || { echo 0; return; }
  [[ -z "$out" || "$out" == "The agent has no identities."* ]] && { echo 0; return; }
  echo "$out" | grep -c .
}

# Explain the key-limit problem and the fix when many keys are loaded.
# Usage: __chief_ssh_key_limit_hint <key_count> [--always]
#   Without --always the hint is shown once per machine (marker under XDG state dir).
function __chief_ssh_key_limit_hint() {
  local count="${1:-0}"
  [[ "$count" -ge "${CHIEF_SSH_KEYS_WARN_AT}" ]] || return 0
  local marker="${XDG_STATE_HOME:-$HOME/.local/state}/chief/ssh-key-limit-hint-shown"
  if [[ "$2" != "--always" ]]; then
    [[ -f "$marker" ]] && return 0
    mkdir -p "$(dirname "$marker")" 2>/dev/null && touch "$marker" 2>/dev/null
  fi
  echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} ${count} keys are loaded in ssh-agent. Servers may stop before the right one is tried"
  echo -e "(\"Too many authentication failures\"). Pin one key per host:"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.ssh_status${CHIEF_NO_COLOR}                  list hosts that don't pin a key"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.ssh_host-key <host> <key>${CHIEF_NO_COLOR}   pin one (add --dry-run to preview)"
  __chief_ssh_key_names_line
}

# Print the key names chief.ssh_host-key accepts (from the keys directory), if any.
function __chief_ssh_key_names_line() {
  local dir f names=""
  dir="$(__chief_ssh_keys_path)"
  [[ -n "$dir" && -d "$dir" ]] || return 0
  for f in "$dir"/*.key; do
    [[ -e "$f" ]] || continue
    f="${f##*/}"; names="${names:+$names, }${f%.key}"
  done
  [[ -n "$names" ]] && echo -e "  Your keys: ${CHIEF_COLOR_CYAN}${names}${CHIEF_NO_COLOR}"
  return 0
}

# Print hosts from an ssh config that don't set "IdentitiesOnly yes" (one per line).
# Wildcard patterns are skipped. Prints "__ALL__" if "Host *" sets IdentitiesOnly yes.
# Usage: __chief_ssh_hosts_without_identitiesonly [config_file]
function __chief_ssh_hosts_without_identitiesonly() {
  local cfg="${1:-${CHIEF_SSH_CONFIG:-$HOME/.ssh/config}}"
  [[ -f "$cfg" ]] || return 0
  awk '
    function flush() {
      if (in_host) {
        if (star && only) { global = 1 }
        else if (!star && !only) { for (i = 1; i <= nh; i++) missing[++nm] = hosts[i] }
      }
      in_host = 0; nh = 0; only = 0; star = 0
    }
    {
      line = $0; sub(/#.*/, "", line)
      if (line ~ /^[ \t]*$/) next
      kw = tolower(line); sub(/^[ \t]*/, "", kw); split(kw, parts, /[ \t=]+/)
      if (parts[1] == "host" || parts[1] == "match") {
        flush()
        if (parts[1] == "host") {
          in_host = 1
          n = split(line, toks, /[ \t=]+/)
          for (i = 1; i <= n; i++) {
            t = toks[i]; if (t == "" || tolower(t) == "host") continue
            if (t == "*") star = 1
            else if (t !~ /[*?!]/) hosts[++nh] = t
          }
        }
        next
      }
      if (parts[1] == "identitiesonly" && tolower(parts[2]) == "yes") only = 1
    }
    END {
      flush()
      if (global) { print "__ALL__"; exit }
      for (i = 1; i <= nm; i++) print missing[i]
    }' "$cfg"
}

# Pin a key to a host in ~/.ssh/config (IdentityFile + IdentitiesOnly yes).
function chief.ssh_host-key() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <host> <key> [--dry-run] [--yes]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Tell ssh which key to use for a host, so it only offers that key. Adds (or updates) the host's
block in ~/.ssh/config with:
    IdentityFile <key>
    IdentitiesOnly yes

${CHIEF_COLOR_BLUE}Why:${CHIEF_NO_COLOR}
SSH servers count every key the client offers and disconnect after MaxAuthTries (often 3-6).
With several keys in ssh-agent, the right key may never be tried (\"Too many authentication
failures\"). With IdentitiesOnly, ssh offers only the pinned key; the agent still unlocks it.

${CHIEF_COLOR_GREEN}Arguments:${CHIEF_NO_COLOR}
  host   Host name as you type it in ssh/git (e.g. github.com, my-server)
  key    Path to a private key, or a key name in ~/.ssh or CHIEF_CFG_SSH_KEYS_PATH (github, github.key)

${CHIEF_COLOR_GREEN}Options:${CHIEF_NO_COLOR}
  --dry-run   Show the block that would be written; change nothing
  --yes, -y   Don't ask for confirmation
  -?, --help  Show this help

${CHIEF_COLOR_MAGENTA}Notes:${CHIEF_NO_COLOR}
- Existing IdentityFile/IdentitiesOnly lines in that host's block are replaced; other lines are kept.
- A new block goes before the first Host/Match line, where ssh reads specific hosts first.
- Refuses Host lines that list several hosts (edit those by hand).
- Backs up the config first (<config>.chief-backup.<timestamp>).

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME github.com github --dry-run
  $FUNCNAME github.com ~/.ssh/keys/github.key
  $FUNCNAME my-server work -y
"
  local host="" key="" dry_run=false assume_yes=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -\?|--help) echo -e "${USAGE}"; return 0 ;;
      --dry-run) dry_run=true ;;
      --yes|-y) assume_yes=true ;;
      -*) echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} unknown option: $1" >&2; return 1 ;;
      *) if [[ -z "$host" ]]; then host="$1"; elif [[ -z "$key" ]]; then key="$1"; else
           echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} too many arguments" >&2; return 1; fi ;;
    esac
    shift
  done
  if [[ -z "$host" || -z "$key" ]]; then
    echo -e "${USAGE}"; return 1
  fi
  if [[ "$host" =~ [[:space:],] ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} host must be a single name: $host" >&2; return 1
  fi

  # Resolve the key: a path, or a name in the keys directory (with or without .key)
  local key_path=""
  local candidate
  for candidate in "${key/#\~/$HOME}" \
                   "$(__chief_ssh_keys_path)/$key" \
                   "$(__chief_ssh_keys_path)/$key.key"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then key_path="$candidate"; break; fi
  done
  if [[ -z "$key_path" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} key not found: $key" >&2
    echo "Looked for it as a path and in $(__chief_ssh_keys_path)" >&2
    return 1
  fi
  [[ "$key_path" != /* ]] && key_path="$(cd "$(dirname "$key_path")" && pwd)/$(basename "$key_path")"
  local id_path="$key_path"
  [[ "$id_path" == "$HOME"/* ]] && id_path="~${id_path#$HOME}"

  local cfg="${CHIEF_SSH_CONFIG:-$HOME/.ssh/config}"
  local lines=() l
  if [[ -f "$cfg" ]]; then
    while IFS= read -r l || [[ -n "$l" ]]; do lines+=("$l"); done < "$cfg"
  fi

  # Find the host's block and the first Host/Match line
  local n=${#lines[@]} i host_idx=-1 first_block=-1 kw rest tok
  for ((i = 0; i < n; i++)); do
    l="${lines[i]%%#*}"
    read -r kw rest <<< "${l//=/ }"
    kw=$(echo "$kw" | tr '[:upper:]' '[:lower:]')
    [[ "$kw" == "host" || "$kw" == "match" ]] || continue
    [[ $first_block -lt 0 ]] && first_block=$i
    [[ "$kw" == "host" ]] || continue
    local toks=()
    read -r -a toks <<< "$rest"
    for tok in "${toks[@]}"; do
      if [[ "$tok" == "$host" ]]; then
        if [[ ${#toks[@]} -gt 1 ]]; then
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} line $((i + 1)) of $cfg covers several hosts: ${lines[i]}" >&2
          echo "Edit it by hand, or give $host its own Host block." >&2
          return 1
        fi
        host_idx=$i
      fi
    done
  done

  local new=() replaced=0 in_block=false action
  local pinned=("    IdentityFile ${id_path}" "    IdentitiesOnly yes")
  if [[ $host_idx -ge 0 ]]; then
    action="Update the existing 'Host ${host}' block (line $((host_idx + 1)))"
    for ((i = 0; i < n; i++)); do
      l="${lines[i]}"
      if [[ $i -eq $host_idx ]]; then
        new+=("$l" "${pinned[@]}"); in_block=true; continue
      fi
      if $in_block; then
        read -r kw rest <<< "${l%%#*}"
        kw=$(echo "${kw%%=*}" | tr '[:upper:]' '[:lower:]')
        if [[ "$kw" == "host" || "$kw" == "match" ]]; then
          in_block=false
        elif [[ "$kw" == "identityfile" || "$kw" == "identitiesonly" ]]; then
          ((replaced++)); continue
        fi
      fi
      new+=("$l")
    done
  else
    local block=("Host ${host}" "${pinned[@]}" "")
    if [[ $first_block -ge 0 ]]; then
      action="Add a 'Host ${host}' block before line $((first_block + 1))"
      for ((i = 0; i < n; i++)); do
        [[ $i -eq $first_block ]] && new+=("${block[@]}")
        new+=("${lines[i]}")
      done
    else
      action="Add a 'Host ${host}' block at the end"
      new=("${lines[@]}")
      [[ $n -gt 0 && -n "${lines[n - 1]}" ]] && new+=("")
      new+=("${block[@]:0:3}")
    fi
  fi

  echo -e "${CHIEF_COLOR_BLUE}${action} in ${cfg}:${CHIEF_NO_COLOR}"
  printf '  %s\n' "Host ${host}" "${pinned[@]}"
  [[ $replaced -gt 0 ]] && echo -e "  ${CHIEF_COLOR_YELLOW}(replaces ${replaced} existing IdentityFile/IdentitiesOnly line(s))${CHIEF_NO_COLOR}"
  if $dry_run; then
    echo -e "${CHIEF_COLOR_CYAN}Dry run: nothing changed.${CHIEF_NO_COLOR}"
    return 0
  fi
  if ! $assume_yes; then
    local confirm
    echo -en "${CHIEF_COLOR_YELLOW}Write this to ${cfg}? (y/n [n]): ${CHIEF_NO_COLOR}"
    read -r confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Cancelled."; return 0; }
  fi

  mkdir -p "$(dirname "$cfg")" && chmod 700 "$(dirname "$cfg")" 2>/dev/null
  if [[ -f "$cfg" ]]; then
    local backup="${cfg}.chief-backup.$(date +%Y%m%d_%H%M%S)"
    cp -p "$cfg" "$backup" || { echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} could not back up $cfg" >&2; return 1; }
    echo -e "Backup: ${backup}"
  fi
  local tmp="${cfg}.chief-tmp.$$"
  printf '%s\n' "${new[@]}" > "$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$cfg" || {
    rm -f "$tmp"; echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} could not write $cfg" >&2; return 1; }
  echo -e "${CHIEF_SYMBOL_CHECK:-✓} ${host} now uses only ${id_path}"
}

function chief.plugins-update() {
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
        echo -e "${CHIEF_COLOR_YELLOW}Force update: local changes will be lost.${CHIEF_NO_COLOR}"
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
- Follows the branch your Chief checkout is on (auto), or a pinned CHIEF_CFG_UPDATE_BRANCH

${CHIEF_COLOR_BLUE}Update Process:${CHIEF_NO_COLOR}
1. Check for available updates on the tracked branch
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
- Default \"auto\": follow whatever branch \$CHIEF_PATH is checked out on. Switch with
  git -C \$CHIEF_PATH switch dev   (or main); no config change needed
- Pin instead: CHIEF_CFG_UPDATE_BRANCH=\"main\" (stable), \"dev\" (bleeding-edge),
  or \"custom-branch\"; chief.update then offers to switch the checkout to it
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
  
  # Check for disconnected mode
  if __chief_is_disconnected_mode; then
    echo ""
    echo -e "${CHIEF_COLOR_RED}DISCONNECTED MODE DETECTED${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_YELLOW}Chief was installed with --local flag for disconnected environments.${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_CYAN}Automatic updates are disabled for security in disconnected environments.${CHIEF_NO_COLOR}"
    echo ""
    echo -e "${CHIEF_COLOR_BLUE}To update Chief in disconnected mode:${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_CYAN}  1. Download the latest Chief version on a connected system${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_CYAN}  2. Transfer the files to this disconnected system${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_CYAN}  3. Run: ./tools/install.sh --local --path \"${CHIEF_PATH}\"${CHIEF_NO_COLOR}"
    echo ""
    echo -e "${CHIEF_COLOR_GREEN}Current version: ${CHIEF_VERSION}${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_YELLOW}Manual update required for disconnected installations.${CHIEF_NO_COLOR}"
    return 0
  fi
  
  # Check if we need to switch branches first (regardless of updates)
  cd "${CHIEF_PATH}"
  # Pinned: offer to switch when the checkout differs. Auto: the checkout's branch is the target.
  local TARGET_BRANCH
  TARGET_BRANCH="$(__chief_update_branch)"
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
        echo -e "${CHIEF_COLOR_YELLOW}Try: chief.config-set update_branch <valid_branch_name>${CHIEF_NO_COLOR}"
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
      local template_changed=false
      git diff --name-only ORIG_HEAD HEAD 2>/dev/null | grep -q 'templates/chief_config_template.sh' && template_changed=true

      # Reload Chief to reflect the branch change and updates
      echo -e "${CHIEF_COLOR_BLUE}Reloading Chief to reflect branch change and updates...${CHIEF_NO_COLOR}"
      chief.reload
      cd - > /dev/null 2>&1
      echo -e "${CHIEF_COLOR_GREEN}Updated Chief to [${CHIEF_VERSION}] from ${TARGET_BRANCH} branch.${CHIEF_NO_COLOR}"
      if $template_changed; then
        echo ""
        echo -e "${CHIEF_COLOR_CYAN}Config template changed. Run ${CHIEF_COLOR_GREEN}chief.config-update${CHIEF_COLOR_CYAN} to add new options to your config.${CHIEF_NO_COLOR}"
        if chief.etc_ask-yes-or-no "Run chief.config-update now?"; then
          chief.config-update
        fi
      fi
      return 0
    else
      echo -e "${CHIEF_COLOR_YELLOW}Branch switch cancelled. Continuing with update check on current branch.${CHIEF_NO_COLOR}"
    fi
  fi
  
  # Now check for updates on the current/correct branch
  __chief_spin "Checking for updates..." "__chief_check_for_updates" tmp_out
  echo -e "${tmp_out}"
  if [[ ${tmp_out} == *"available"* ]]; then
    # chief.etc_ask-yes-or-no prints "Proceeding..." itself on yes.
    if chief.etc_ask-yes-or-no "Updates are available, update now?"; then

      # We're already in CHIEF_PATH and on the correct branch
      local TARGET_BRANCH
      TARGET_BRANCH="$(__chief_update_branch)"
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
          echo -e "${CHIEF_COLOR_YELLOW}Try: chief.config-set update_branch <valid_branch_name>${CHIEF_NO_COLOR}"
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
      local template_changed=false
      git diff --name-only ORIG_HEAD HEAD 2>/dev/null | grep -q 'templates/chief_config_template.sh' && template_changed=true

      chief.reload
      cd - > /dev/null 2>&1
      echo -e "${CHIEF_COLOR_GREEN}Updated Chief to [${CHIEF_VERSION}] from ${TARGET_BRANCH} branch.${CHIEF_NO_COLOR}"
      if $template_changed; then
        echo ""
        echo -e "${CHIEF_COLOR_CYAN}Config template changed. Run ${CHIEF_COLOR_GREEN}chief.config-update${CHIEF_COLOR_CYAN} to add new options to your config.${CHIEF_NO_COLOR}"
        if chief.etc_ask-yes-or-no "Run chief.config-update now?"; then
          chief.config-update
        fi
      fi
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
- CHIEF_CFG_BANNER_INDICATORS: Banner status items, in order: alias plugins tracking secrets
- CHIEF_CFG_BANNER_STYLE: Banner logo: full (default) or compact (narrow screens)
- CHIEF_CFG_BASH_WARN: Warn at start-up when running on Bash older than 4.0 (default true)
- CHIEF_CFG_PROMPT: Use Chief's custom prompt
- CHIEF_CFG_GIT_PROMPT: Git-aware prompt features
- CHIEF_CFG_MULTILINE_PROMPT: Enable multiline prompt
- CHIEF_CFG_PLUGINS_TYPE: 'local' or 'remote' plugins
- CHIEF_CFG_SSH_LOAD_KEYS: Auto-load SSH keys at start-up (from ~/.ssh or CHIEF_CFG_SSH_KEYS_PATH)
- And many more...

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your configured editor (CHIEF_CFG_DEFAULT_EDITOR_PATH or \$EDITOR)
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
  BANNER_INDICATORS         Banner status items, in order (e.g. \"alias plugins tracking secrets\"; \"\" for none)
  BANNER_STYLE              Banner logo: full or compact (smaller, for narrow screens)
  BASH_WARN                 Warn at start-up if Bash is older than 4.0 (true/false)
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
  PLUGINS_DISABLED_CORE     Space-separated list of core plugins to skip (e.g. \"ssl secrets vault\");
  PLUGINS_DISABLED_USER     Space-separated list of user plugins to skip (e.g. \"lab workmac\");
  PLUGINS_ENABLED_CONTRIB   Space-separated list of contrib plugins to load (e.g. \"cg\"); use chief.plugin enable contrib.<name>
  CG_HELPER_FUNCTIONS       [cg contrib plugin] Path to .helper_functions.sh in your local customer-success clone
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
- Most changes take effect immediately (Chief reloads after the change)
- Applied only when a terminal starts, so they need a new terminal: PROMPT, COLORED_PROMPT,
  GIT_PROMPT, SHORT_PATH, COLORED_LS, plus the start-up-only BANNER, HINTS,
  AUTOCHECK_UPDATES, BASH_WARN. SSH_LOAD_KEYS/SSH_KEYS_PATH: run chief.ssh_load-keys.
  For these Chief skips the reload (it couldn't apply them) and prints a Note instead.
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

  # Reload configuration, unless a reload can't apply this setting (it would only add noise).
  if ! __chief_config_reload_cant_apply "${config_var}"; then
    echo -e "${CHIEF_COLOR_BLUE}Reloading Chief configuration...${CHIEF_NO_COLOR}"
    if __chief_load_library --verbose; then
      echo -e "${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR} Configuration reloaded successfully"
    else
      echo -e "${CHIEF_COLOR_YELLOW}⚠${CHIEF_NO_COLOR} Configuration file updated but reload had issues"
    fi
  fi

  # Verify the change
  local current_value
  if current_value=$(grep "^${config_var}=" "${CHIEF_CONFIG}" 2>/dev/null | cut -d'=' -f2-); then
    echo -e "${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR} Confirmed: ${config_var}=${current_value}"
  else
    echo -e "${CHIEF_COLOR_YELLOW}⚠${CHIEF_NO_COLOR} Could not verify the configuration change"
  fi

  __chief_config_restart_note "${config_var}"
}

# Return 0 for settings that chief.config-set's reload (__chief_load_library) can't apply:
# chief.sh applies them once, at shell start-up (the prompt, ls colors, the banner, hints,
# the update check), and SSH keys load only at start-up or via chief.reload. config-set skips
# the reload for these, since it would only print noise.
# Usage: __chief_config_reload_cant_apply <CHIEF_CFG_VAR>
function __chief_config_reload_cant_apply() {
  case "$1" in
    CHIEF_CFG_PROMPT|CHIEF_CFG_COLORED_PROMPT|CHIEF_CFG_GIT_PROMPT|CHIEF_CFG_SHORT_PATH|CHIEF_CFG_COLORED_LS) return 0 ;;
    CHIEF_CFG_BANNER|CHIEF_CFG_HINTS|CHIEF_CFG_AUTOCHECK_UPDATES|CHIEF_CFG_BASH_WARN) return 0 ;;
    CHIEF_CFG_SSH_LOAD_KEYS|CHIEF_CFG_SSH_KEYS_PATH) return 0 ;;
  esac
  return 1
}

# Tell the user when a setting doesn't take effect in the current shell, and what to do.
# Usage: __chief_config_restart_note <CHIEF_CFG_VAR>
function __chief_config_restart_note() {
  local note=""
  case "$1" in
    CHIEF_CFG_PROMPT|CHIEF_CFG_COLORED_PROMPT|CHIEF_CFG_GIT_PROMPT|CHIEF_CFG_SHORT_PATH|CHIEF_CFG_COLORED_LS)
      note="$1 is applied when a terminal starts, so Chief didn't reload (it can't change this terminal; neither can chief.reload). Open a new terminal to see the change." ;;
    CHIEF_CFG_ALIAS)
      note="The new alias works now, but commands from a previous alias stay in this terminal. Open a new terminal for a clean set." ;;
    CHIEF_CFG_BANNER|CHIEF_CFG_HINTS|CHIEF_CFG_AUTOCHECK_UPDATES|CHIEF_CFG_BASH_WARN)
      note="$1 only matters when a terminal starts, so no reload was needed. You'll see the change in the next new terminal." ;;
    CHIEF_CFG_SSH_LOAD_KEYS|CHIEF_CFG_SSH_KEYS_PATH)
      note="$1 is used when a terminal starts and by chief.reload, so no reload was done now. To load keys now, run: chief.ssh_load-keys" ;;
  esac
  [[ -n "$note" ]] && echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} ${note}"
  return 0
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
      
      # Upgrade: before CHIEF_CFG_SSH_LOAD_KEYS existed, setting CHIEF_CFG_SSH_KEYS_PATH meant
      # "auto-load keys". Keep that behavior instead of the template's default (false).
      if [[ -z "$user_value" && "$var_name" == "CHIEF_CFG_SSH_LOAD_KEYS" && -n "${user_vars[CHIEF_CFG_SSH_KEYS_PATH]:-}" ]]; then
        user_value="true"
        echo "# Set on upgrade: this config already auto-loaded keys from CHIEF_CFG_SSH_KEYS_PATH"
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
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [OPTIONS] [plugin_name] [existing_file_path]
       $FUNCNAME enable <name>         Enable a user plugin (e.g. bc, lab)
       $FUNCNAME enable core.<name>    Enable a core plugin (e.g. core.ssl)
       $FUNCNAME disable <name>        Disable a user plugin (e.g. bc, lab)
       $FUNCNAME disable core.<name>   Disable a core plugin (e.g. core.ssl)
       $FUNCNAME enable contrib.<name> Enable a contrib plugin (off by default; e.g. contrib.cg)
       $FUNCNAME disable contrib.<name> Disable a contrib plugin
       $FUNCNAME status                Show enabled/disabled for core and user plugins

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit a Chief plugin file with automatic reload on changes.
Enable/disable core or user plugins so they are skipped when Chief loads.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  plugin_name         Name of plugin to edit (without _chief-plugin.sh suffix)
  existing_file_path  Optional: path to an existing script; Chief creates <name>_chief-plugin.sh
                      as a symlink to that file (same as manual ln -s into the plugins dir).
                      Symlink targets are relative when the script lives under the same directory
                      tree as the plugin file (portable for git / remote plugin repos). If no
                      relative path exists (e.g. target outside the tree or another volume),
                      Chief uses an absolute target and warns that committing it is not portable.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --code, --vscode  Use GUI editor (Cursor if available, else VSCode; set CHIEF_CFG_EDITOR_GUI_CMD to override)
  -?, --help      Show this help

${CHIEF_COLOR_GREEN}User plugins:${CHIEF_NO_COLOR} ${CHIEF_COLOR_BLUE}(editable; core built-in plugins: cf.help plugins)${CHIEF_NO_COLOR}
$(__chief_get_plugins)

${CHIEF_COLOR_MAGENTA}Plugin Naming Convention:${CHIEF_NO_COLOR}
- File format: <name>_chief-plugin.sh
- Function format: <name>.<function_name>()
- Must be executable and sourced

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Edit default plugin
  $FUNCNAME enable bc          # Enable user plugin bc
  $FUNCNAME disable core.ssl   # Disable core plugin ssl
  $FUNCNAME status             # List enabled/disabled plugins
  $FUNCNAME mytools            # Edit mytools_chief-plugin.sh
  $FUNCNAME pl /path/to/pl.sh  # Symlink existing script as pl_chief-plugin.sh (relative if portable)
  $FUNCNAME --code default     # Edit default_chief-plugin.sh with Cursor/VSCode

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your configured editor (respects CHIEF_CFG_DEFAULT_EDITOR_PATH, \$EDITOR)
- Cursor/VSCode support with --code/--vscode flag (Cursor preferred if in PATH)
- Automatically reloads plugin on save
- Creates new plugin from template if the plugin file does not exist yet
- Symlink mode (two arguments): installs a plugin symlink so Chief loads your existing script.
  For team or dotfiles repos, keep the script inside the same checkout as the plugins path so the
  symlink target is stored as a relative path (works after clone on another machine). Targets
  outside that tree use an absolute path; Chief warns that those links are host-specific.
"

  # --- Enable/disable/status subcommands (no options before the subcommand) ---
  if [[ $# -gt 0 ]]; then
    local subcmd=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$subcmd" in
      enable)
        shift
        if [[ -z "$1" ]]; then
          echo -e "${CHIEF_COLOR_RED}Error: ${CHIEF_NO_COLOR}chief.plugin enable requires a plugin name (e.g. bc or core.ssl)"
          return 1
        fi
        local name="$1"
        local module="user"
        if [[ "$name" == core.* ]]; then
          module="core"
          name="${name#core.}"
        elif [[ "$name" == contrib.* ]]; then
          module="contrib"
          name="${name#contrib.}"
        fi
        __chief_plugin_enable_disable "$module" "$name" "enable"
        return
        ;;
      disable)
        shift
        if [[ -z "$1" ]]; then
          echo -e "${CHIEF_COLOR_RED}Error: ${CHIEF_NO_COLOR}chief.plugin disable requires a plugin name (e.g. bc or core.ssl)"
          return 1
        fi
        local name="$1"
        local module="user"
        if [[ "$name" == core.* ]]; then
          module="core"
          name="${name#core.}"
        elif [[ "$name" == contrib.* ]]; then
          module="contrib"
          name="${name#contrib.}"
        fi
        __chief_plugin_enable_disable "$module" "$name" "disable"
        return
        ;;
      status|list)
        shift
        local core_all core_disabled user_all user_disabled c_fmt cdis_fmt u_fmt udis_fmt
        core_all=$(__chief_get_core_plugins)
        user_all=$(__chief_get_plugins)
        core_disabled="$(__chief_get_core_plugins_disabled)"
        user_disabled="$(__chief_plugin_normalize_disabled_list "${CHIEF_CFG_PLUGINS_DISABLED_USER:-}")"
        c_fmt="$(__chief_format_plugin_list "${core_all:-}")"
        cdis_fmt="$(__chief_format_plugin_list "${core_disabled:-}")"
        u_fmt="$(__chief_format_plugin_list "${user_all:-}")"
        udis_fmt="$(__chief_format_plugin_list "${user_disabled:-}")"
        echo -e "${CHIEF_COLOR_GREEN}Core (built-in):${CHIEF_NO_COLOR}"
        echo -e "  Enabled:  ${CHIEF_COLOR_CYAN}${c_fmt:-<none>}${CHIEF_NO_COLOR}"
        echo -e "  Disabled: ${CHIEF_COLOR_YELLOW}${cdis_fmt:-<none>}${CHIEF_NO_COLOR}"
        echo
        local k_fmt kdis_fmt
        k_fmt="$(__chief_format_plugin_list "$(__chief_get_contrib_plugins enabled)")"
        kdis_fmt="$(__chief_format_plugin_list "$(__chief_get_contrib_plugins disabled)")"
        echo -e "${CHIEF_COLOR_GREEN}Contrib (shipped, off by default):${CHIEF_NO_COLOR}"
        echo -e "  Enabled:  ${CHIEF_COLOR_CYAN}${k_fmt:-<none>}${CHIEF_NO_COLOR}"
        echo -e "  Disabled: ${CHIEF_COLOR_YELLOW}${kdis_fmt:-<none>}${CHIEF_NO_COLOR}"
        echo
        echo -e "${CHIEF_COLOR_GREEN}User plugins:${CHIEF_NO_COLOR}"
        echo -e "  Enabled:  ${CHIEF_COLOR_CYAN}${u_fmt:-<none>}${CHIEF_NO_COLOR}"
        echo -e "  Disabled: ${CHIEF_COLOR_YELLOW}${udis_fmt:-<none>}${CHIEF_NO_COLOR}"
        echo
        echo -e "${CHIEF_COLOR_BLUE}Use ${CHIEF_NO_COLOR}chief.plugin enable|disable <name>${CHIEF_COLOR_BLUE} or ${CHIEF_NO_COLOR}core.<name>${CHIEF_COLOR_BLUE} (e.g. bc, core.ssl, contrib.cg). Config updated; Chief reloads.${CHIEF_NO_COLOR}"
        return
        ;;
    esac
  fi

  # Parse arguments for edit flow
  local use_vscode=""
  local plugin_name=""
  local existing_path=""

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
        if [[ $# -gt 0 && $1 != -* ]]; then
          existing_path="$1"
          shift
        fi
        ;;
    esac
  done

  # Determine plugin name
  if [[ -z "$plugin_name" ]]; then
    plugin_name="default"
  fi

  __chief_edit_plugin "$plugin_name" "$use_vscode" "$existing_path"
}

function chief.bash_profile() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit your ~/.bash_profile file with automatic reload on changes.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -r, --reload      Reload ~/.bash_profile without editing
  -?, --help        Show this help

${CHIEF_COLOR_GREEN}What is .bash_profile:${CHIEF_NO_COLOR}
- Login shell initialization script
- Executed when you start a new terminal session
- Contains environment variables, aliases, functions
- Preferred over .bashrc for login shells

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your configured editor (CHIEF_CFG_DEFAULT_EDITOR_PATH or \$EDITOR)
- Automatically sources file on save
- Detects and reports syntax errors
- Creates file if it doesn't exist

${CHIEF_COLOR_MAGENTA}Best Practices:${CHIEF_NO_COLOR}
- Put personal variables here (not in shared plugins)
- Set PATH modifications
- Configure personal aliases and functions
- Source other configuration files

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                        # Edit ~/.bash_profile
  $FUNCNAME -r                     # Reload ~/.bash_profile
  $FUNCNAME --reload               # Reload ~/.bash_profile

${CHIEF_COLOR_YELLOW}File Location:${CHIEF_NO_COLOR}
~/.bash_profile
"

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      -r|--reload)
        if [[ -f "$HOME/.bash_profile" ]]; then
          echo -e "${CHIEF_COLOR_BLUE}Reloading ~/.bash_profile...${CHIEF_NO_COLOR}"
          source "$HOME/.bash_profile"
          echo -e "${CHIEF_COLOR_GREEN}Successfully reloaded ~/.bash_profile${CHIEF_NO_COLOR}"
        else
          echo -e "${CHIEF_COLOR_YELLOW}Warning: ~/.bash_profile does not exist${CHIEF_NO_COLOR}"
          return 1
        fi
        return
        ;;
      -\?|--help)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error: Unknown option: $1${CHIEF_NO_COLOR}"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        echo -e "${CHIEF_COLOR_RED}Error: Unexpected argument: $1${CHIEF_NO_COLOR}"
        echo -e "${USAGE}"
        return 1
        ;;
    esac
    shift
  done

  chief.edit-file "$HOME/.bash_profile"
}

function chief.bashrc() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit your ~/.bashrc file with automatic reload on changes.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -r, --reload      Reload ~/.bashrc without editing
  -?, --help        Show this help

${CHIEF_COLOR_GREEN}What is .bashrc:${CHIEF_NO_COLOR}
- Non-login shell initialization script
- Executed for interactive non-login shells
- Contains aliases, functions, and interactive settings
- Sourced by terminal multiplexers and some terminals

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your configured editor (CHIEF_CFG_DEFAULT_EDITOR_PATH or \$EDITOR)
- Automatically sources file on save
- Detects and reports syntax errors
- Creates file if it doesn't exist

${CHIEF_COLOR_MAGENTA}Usage Notes:${CHIEF_NO_COLOR}
- .bash_profile is preferred for login shells (Chief recommendation)
- .bashrc is better for non-login interactive shells
- Some systems source .bashrc from .bash_profile

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                        # Edit ~/.bashrc
  $FUNCNAME -r                     # Reload ~/.bashrc
  $FUNCNAME --reload               # Reload ~/.bashrc

${CHIEF_COLOR_YELLOW}File Location:${CHIEF_NO_COLOR}
~/.bashrc

${CHIEF_COLOR_BLUE}Recommendation:${CHIEF_NO_COLOR}
Use chief.bash_profile for most Chief and personal configurations.
"

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      -r|--reload)
        if [[ -f "$HOME/.bashrc" ]]; then
          echo -e "${CHIEF_COLOR_BLUE}Reloading ~/.bashrc...${CHIEF_NO_COLOR}"
          source "$HOME/.bashrc"
          echo -e "${CHIEF_COLOR_GREEN}Successfully reloaded ~/.bashrc${CHIEF_NO_COLOR}"
        else
          echo -e "${CHIEF_COLOR_YELLOW}Warning: ~/.bashrc does not exist${CHIEF_NO_COLOR}"
          return 1
        fi
        return
        ;;
      -\?|--help)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error: Unknown option: $1${CHIEF_NO_COLOR}"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        echo -e "${CHIEF_COLOR_RED}Error: Unexpected argument: $1${CHIEF_NO_COLOR}"
        echo -e "${USAGE}"
        return 1
        ;;
    esac
    shift
  done

  chief.edit-file "$HOME/.bashrc"
}

function chief.profile() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit your ~/.profile file with automatic reload on changes.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -r, --reload      Reload ~/.profile without editing
  -?, --help        Show this help

${CHIEF_COLOR_GREEN}What is .profile:${CHIEF_NO_COLOR}
- POSIX-compliant shell initialization script
- Executed by login shells (bash, dash, zsh, etc.)
- Contains environment variables and paths
- Most portable shell configuration file

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your configured editor (CHIEF_CFG_DEFAULT_EDITOR_PATH or \$EDITOR)
- Automatically sources file on save
- Detects and reports syntax errors
- Creates file if it doesn't exist

${CHIEF_COLOR_MAGENTA}Compatibility:${CHIEF_NO_COLOR}
- Works with any POSIX-compliant shell
- Avoid bash-specific features in this file
- Use for environment variables and paths
- Shell-agnostic configurations

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                        # Edit ~/.profile
  $FUNCNAME -r                     # Reload ~/.profile
  $FUNCNAME --reload               # Reload ~/.profile

${CHIEF_COLOR_YELLOW}File Location:${CHIEF_NO_COLOR}
~/.profile

${CHIEF_COLOR_BLUE}Best Practice:${CHIEF_NO_COLOR}
Use ~/.profile for cross-shell environment settings and ~/.bash_profile for bash-specific configurations.
"

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      -r|--reload)
        if [[ -f "$HOME/.profile" ]]; then
          echo -e "${CHIEF_COLOR_BLUE}Reloading ~/.profile...${CHIEF_NO_COLOR}"
          source "$HOME/.profile"
          echo -e "${CHIEF_COLOR_GREEN}Successfully reloaded ~/.profile${CHIEF_NO_COLOR}"
        else
          echo -e "${CHIEF_COLOR_YELLOW}Warning: ~/.profile does not exist${CHIEF_NO_COLOR}"
          return 1
        fi
        return
        ;;
      -\?|--help)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error: Unknown option: $1${CHIEF_NO_COLOR}"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        echo -e "${CHIEF_COLOR_RED}Error: Unexpected argument: $1${CHIEF_NO_COLOR}"
        echo -e "${USAGE}"
        return 1
        ;;
    esac
    shift
  done

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
- Reloads SSH keys if configured
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
- SSH key configurations

${CHIEF_COLOR_YELLOW}Not reloaded (open a new terminal instead):${CHIEF_NO_COLOR}
- The prompt: CHIEF_CFG_PROMPT, COLORED_PROMPT, GIT_PROMPT, SHORT_PATH
- ls colors: CHIEF_CFG_COLORED_LS
- Start-up only: CHIEF_CFG_BANNER, HINTS, AUTOCHECK_UPDATES, BASH_WARN
- Commands from a previous CHIEF_CFG_ALIAS stay until a new terminal

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Reload Chief environment
  chief.config && $FUNCNAME   # Edit config then reload

${CHIEF_COLOR_BLUE}Alternative:${CHIEF_NO_COLOR}
Open a new terminal for a complete reset.
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_CYAN}Chief${CHIEF_NO_COLOR} — ${CHIEF_COLOR_BLUE}reloading…${CHIEF_NO_COLOR}"
  __chief_load_library --verbose
  
  # Reload SSH keys if configured
  if __chief_ssh_autoload_on && ([[ ${PLATFORM} == "MacOS" ]] || [[ $(uname) == "Linux" ]]); then
    echo -e "${CHIEF_FRAMEWORK_MSG_PREFIX}${CHIEF_COLOR_BLUE}reloading SSH keys…${CHIEF_NO_COLOR}"
    __chief_load_ssh_keys --verbose
  fi
  
  echo -e "${CHIEF_COLOR_CYAN}Chief${CHIEF_NO_COLOR} — ${CHIEF_COLOR_GREEN}ready.${CHIEF_NO_COLOR}"
}

# Show Chief statistics and status
function __chief_show_chief_stats() {
  local total_functions=$(compgen -A function | grep "^chief\." | wc -l | tr -d ' ')
  local core_plugins=$(__chief_get_core_plugins)
  local user_plugins=$(__chief_get_plugins)
  local core_count=0
  local user_count=0
  local core_disabled user_disabled

  if [[ -n "$core_plugins" ]]; then
    core_count=$(echo "$core_plugins" | tr '|' '\n' | wc -l | tr -d ' ')
  fi
  if [[ -n "$user_plugins" ]]; then
    user_count=$(echo "$user_plugins" | tr '|' '\n' | wc -l | tr -d ' ')
  fi

  core_disabled="$(__chief_get_core_plugins_disabled)"
  user_disabled="$(__chief_plugin_normalize_disabled_list "${CHIEF_CFG_PLUGINS_DISABLED_USER:-}")"
  local contrib_on contrib_off
  contrib_on="$(__chief_get_contrib_plugins enabled)"
  contrib_off="$(__chief_get_contrib_plugins disabled)"

  echo -e "${CHIEF_COLOR_BLUE}Chief Status:${CHIEF_NO_COLOR}"
  echo -e "• Functions available: ${CHIEF_COLOR_CYAN}$total_functions${CHIEF_NO_COLOR}"
  echo -e "• Core (built-in): ${CHIEF_COLOR_CYAN}$core_count${CHIEF_NO_COLOR} ($(__chief_format_plugin_list "$core_plugins"))"
  local kon_fmt koff_fmt
  kon_fmt="$(__chief_format_plugin_list "$contrib_on")"
  koff_fmt="$(__chief_format_plugin_list "$contrib_off")"
  echo -e "• Contrib: ${CHIEF_COLOR_CYAN}on:${CHIEF_NO_COLOR} ${kon_fmt:-<none>}; ${CHIEF_COLOR_CYAN}off:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}${koff_fmt:-<none>}${CHIEF_NO_COLOR}"
  echo -e "• User plugins: ${CHIEF_COLOR_CYAN}$user_count${CHIEF_NO_COLOR} ($(__chief_format_plugin_list "$user_plugins"))"
  if [[ -n "$core_disabled" ]] || [[ -n "$user_disabled" ]]; then
    local cdis_fmt udis_fmt
    cdis_fmt="$(__chief_format_plugin_list "${core_disabled:-}")"
    udis_fmt="$(__chief_format_plugin_list "${user_disabled:-}")"
    echo -e "• Disabled plugins: ${CHIEF_COLOR_CYAN}core:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}${cdis_fmt:-<none>}${CHIEF_NO_COLOR}; ${CHIEF_COLOR_CYAN}user:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}${udis_fmt:-<none>}${CHIEF_NO_COLOR} ${CHIEF_COLOR_CYAN}(chief.plugin status)${CHIEF_NO_COLOR}"
  fi
  echo -e "• Configuration: ${CHIEF_COLOR_CYAN}$CHIEF_CONFIG${CHIEF_NO_COLOR}"
}

# Show core Chief commands
function __chief_show_core_commands() {
  local cmd_prefix=$(__chief_get_command_prefix)
  echo -e "${CHIEF_COLOR_YELLOW}Core Chief Commands:${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Configuration & Setup:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}config${CHIEF_NO_COLOR}        Edit Chief configuration file"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}config-set${CHIEF_NO_COLOR}    Set configuration variables directly"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}config-update${CHIEF_NO_COLOR} Update config with new options from template"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}reload${CHIEF_NO_COLOR}        Reload Chief environment"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}update${CHIEF_NO_COLOR}        Update Chief to latest version"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}uninstall${CHIEF_NO_COLOR}     Remove Chief from system"
  echo
  echo -e "${CHIEF_COLOR_CYAN}File Management:${CHIEF_NO_COLOR} ${CHIEF_COLOR_BLUE}(auto-reloads after editing)${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}edit-file${CHIEF_NO_COLOR}     Edit any file with auto-reload detection"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}bash_profile${CHIEF_NO_COLOR}  Edit ~/.bash_profile"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}bashrc${CHIEF_NO_COLOR}        Edit ~/.bashrc"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}profile${CHIEF_NO_COLOR}       Edit ~/.profile"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Plugin Management:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}plugins-root${CHIEF_NO_COLOR}   Navigate to plugins directory"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}plugin${CHIEF_NO_COLOR}        Create/edit plugins"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}plugin -?${CHIEF_NO_COLOR}     List available plugins | ${CHIEF_COLOR_GREEN}${cmd_prefix}plugin status${CHIEF_NO_COLOR} enabled/disabled"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Utilities:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}status${CHIEF_NO_COLOR}        Show Chief status (banner + stats, including disabled plugins)"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}whereis${CHIEF_NO_COLOR}       Find aliases, functions, and variables"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}hints${CHIEF_NO_COLOR}         Show quick tips and workflow"
  echo
  echo -e "${CHIEF_COLOR_BLUE}Usage tip:${CHIEF_NO_COLOR} All commands support ${CHIEF_COLOR_GREEN}-?${CHIEF_NO_COLOR} or ${CHIEF_COLOR_GREEN}--help${CHIEF_NO_COLOR} for detailed help"
}

# Show plugin-related help
function __chief_show_plugin_help() {
  local cmd_prefix=$(__chief_get_command_prefix)
  echo -e "${CHIEF_COLOR_YELLOW}Plugin Management:${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR} All commands below should be prefixed with ${CHIEF_COLOR_GREEN}${cmd_prefix}${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_MAGENTA}Core vs User plugins:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}Core (built-in)${CHIEF_NO_COLOR}  — Part of Chief; loaded from \$CHIEF_PATH/libs/core/plugins. Not editable via ${cmd_prefix}plugin."
  echo -e "  ${CHIEF_COLOR_GREEN}Contrib${CHIEF_NO_COLOR}          — Shipped with Chief in \$CHIEF_PATH/libs/contrib/plugins; off until ${cmd_prefix}plugin enable contrib.<name>."
  echo -e "  ${CHIEF_COLOR_GREEN}User plugins${CHIEF_NO_COLOR}     — Your plugins from CHIEF_CFG_PLUGINS_PATH; editable via ${cmd_prefix}plugin."
  echo
  echo -e "${CHIEF_COLOR_CYAN}Plugin Commands:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}plugins${CHIEF_NO_COLOR}              Navigate to plugins directory (user plugins only)"
  echo -e "  ${CHIEF_COLOR_GREEN}plugin${CHIEF_NO_COLOR}               Edit default plugin"
  echo -e "  ${CHIEF_COLOR_GREEN}plugin <name>${CHIEF_NO_COLOR}        Create/edit named user plugin"
  echo -e "  ${CHIEF_COLOR_GREEN}plugin enable [core.|contrib.]<name>${CHIEF_NO_COLOR}   Enable a plugin (load on reload)"
  echo -e "  ${CHIEF_COLOR_GREEN}plugin disable [core.|contrib.]<name>${CHIEF_NO_COLOR}  Disable a plugin (skip loading)"
  echo -e "  ${CHIEF_COLOR_GREEN}plugin status${CHIEF_NO_COLOR}         Show enabled/disabled plugins"
  echo -e "  ${CHIEF_COLOR_GREEN}plugin -?${CHIEF_NO_COLOR}            List user plugins"
  echo

  local core_plugins=$(__chief_get_core_plugins)
  local user_plugins=$(__chief_get_plugins)
  local core_disabled user_disabled contrib_on
  core_disabled="$(__chief_get_core_plugins_disabled)"
  user_disabled="$(__chief_plugin_normalize_disabled_list "${CHIEF_CFG_PLUGINS_DISABLED_USER:-}")"
  contrib_on="$(__chief_get_contrib_plugins enabled)"
  if [[ -n "$core_plugins" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Core (built-in):${CHIEF_NO_COLOR}"
    echo -e "  ${CHIEF_COLOR_CYAN}$(__chief_format_plugin_list "$core_plugins")${CHIEF_NO_COLOR}"
    echo
  fi
  if [[ -n "$contrib_on" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Contrib (enabled):${CHIEF_NO_COLOR}"
    echo -e "  ${CHIEF_COLOR_CYAN}$(__chief_format_plugin_list "$contrib_on")${CHIEF_NO_COLOR}"
    echo
  fi
  if [[ -n "$user_plugins" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}User plugins (loaded):${CHIEF_NO_COLOR}"
    echo -e "  ${CHIEF_COLOR_CYAN}$(__chief_format_plugin_list "$user_plugins")${CHIEF_NO_COLOR}"
    echo
  fi
  if [[ -n "$core_disabled" ]] || [[ -n "$user_disabled" ]]; then
    local cdis_fmt udis_fmt
    cdis_fmt="$(__chief_format_plugin_list "${core_disabled:-}")"
    udis_fmt="$(__chief_format_plugin_list "${user_disabled:-}")"
    echo -e "${CHIEF_COLOR_YELLOW}Disabled plugins (skipped on load):${CHIEF_NO_COLOR}"
    echo -e "  ${CHIEF_COLOR_CYAN}Core:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}${cdis_fmt:-<none>}${CHIEF_NO_COLOR}  |  ${CHIEF_COLOR_CYAN}User:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}${udis_fmt:-<none>}${CHIEF_NO_COLOR}"
    echo -e "  ${CHIEF_COLOR_CYAN}chief.plugin status${CHIEF_NO_COLOR} for full list | ${CHIEF_COLOR_GREEN}chief.plugin enable [core.]<name>${CHIEF_NO_COLOR} to re-enable"
    echo
  fi

  echo -e "${CHIEF_COLOR_CYAN}Core plugin functions:${CHIEF_NO_COLOR} ${CHIEF_COLOR_BLUE}(from built-in plugins above)${CHIEF_NO_COLOR}"
  
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
  
  if compgen -A function | grep -q "^chief\.secrets_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}Secrets Plugin:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(ansible-vault or gpg)${CHIEF_NO_COLOR}"
    echo "    secrets_file-edit, secrets_file-load"
    found_plugins=true
  fi
  if compgen -A function | grep -q "^chief\.vault_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}Vault Plugin:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(HashiCorp Vault CLI)${CHIEF_NO_COLOR}"
    echo "    vault_read-secret, vault_write-secret, vault_list-secrets"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.aws_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}AWS Plugin:${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(requires aws CLI)${CHIEF_NO_COLOR}"
    echo "    aws_set-role, aws_export-creds"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.ssh_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}SSH Plugin:${CHIEF_NO_COLOR}"
    echo "    ssh_create-keypair, ssh_get-publickey, ssh_rm-host, ssh_load-keys"
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
    echo "    oc_vault-kubeadmin, oc_whoami"
    found_plugins=true
  fi
  
  if compgen -A function | grep -q "^chief\.etc_"; then
    echo -e "  ${CHIEF_COLOR_GREEN}Utilities Plugin:${CHIEF_NO_COLOR}"
    echo "    etc_ask-yes-or-no, etc_spinner, etc_prompt, etc_mount-share"
    echo "    etc_isvalid-ip, etc_broadcast, etc_at-run, etc_folder-diff"
    echo "    etc_shared-term-create, etc_shared-term-connect, etc_chmod-f, etc_chmod-d"
    echo "    etc_create-bootusb, etc_copy-dotfiles, etc_create-cipher, type-writer"
    found_plugins=true
  fi
  
  if [[ "$found_plugins" == false ]]; then
    echo -e "  ${CHIEF_COLOR_YELLOW}No core plugin functions loaded yet${CHIEF_NO_COLOR}"
    echo
    echo -e "${CHIEF_COLOR_BLUE}User plugins:${CHIEF_NO_COLOR}"
    echo -e "  • Run ${CHIEF_COLOR_GREEN}${cmd_prefix}plugin -?${CHIEF_NO_COLOR} to see your user plugins"
    echo -e "  • Create your first user plugin: ${CHIEF_COLOR_GREEN}${cmd_prefix}plugin mytools${CHIEF_NO_COLOR}"
  fi

  echo
  echo -e "${CHIEF_COLOR_BLUE}User plugin development:${CHIEF_NO_COLOR}"
  echo -e "• User plugin location: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PLUGINS_PATH:-~/.chief_plugins}${CHIEF_NO_COLOR}"
  echo -e "• Template: ${CHIEF_COLOR_CYAN}${CHIEF_DEFAULT_PLUGIN_TEMPLATE}${CHIEF_NO_COLOR}"
  echo -e "• Edit config: ${CHIEF_COLOR_GREEN}${cmd_prefix}config${CHIEF_NO_COLOR} to set CHIEF_CFG_PLUGINS_PATH"
}

# Show configuration help
function __chief_show_configuration_help() {
  local cmd_prefix=$(__chief_get_command_prefix)
  echo -e "${CHIEF_COLOR_YELLOW}Chief Configuration:${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR} All configuration variables below should be prefixed with ${CHIEF_COLOR_GREEN}CHIEF_CFG_${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Configuration File:${CHIEF_NO_COLOR}"
  echo -e "  Location: ${CHIEF_COLOR_CYAN}$CHIEF_CONFIG${CHIEF_NO_COLOR}"
  echo -e "  Edit: ${CHIEF_COLOR_GREEN}${cmd_prefix}config${CHIEF_NO_COLOR}"
  echo -e "  Set directly: ${CHIEF_COLOR_GREEN}${cmd_prefix}config_set <option> <value>${CHIEF_NO_COLOR} ${CHIEF_COLOR_YELLOW}(omit CHIEF_CFG_ prefix)${CHIEF_NO_COLOR}"
  echo
  
  echo -e "${CHIEF_COLOR_CYAN}Display & Interface:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}BANNER${CHIEF_NO_COLOR}                 Show/hide startup banner (true/false)"
  echo -e "    ${CHIEF_COLOR_GREEN}BANNER_INDICATORS${CHIEF_NO_COLOR}    Banner status items, in order: alias plugins tracking secrets (\"\" for none)"
  echo -e "    ${CHIEF_COLOR_GREEN}BANNER_STYLE${CHIEF_NO_COLOR}         Banner logo: full or compact (smaller, for narrow screens)"
  echo -e "  ${CHIEF_COLOR_GREEN}BASH_WARN${CHIEF_NO_COLOR}              Warn at start-up if Bash is older than 4.0 (true/false)"
  echo -e "  ${CHIEF_COLOR_GREEN}HINTS${CHIEF_NO_COLOR}                  Show/hide startup hints (true/false)"
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
  echo -e "${CHIEF_COLOR_CYAN}Environment Variables:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}CHIEF_HOST${CHIEF_NO_COLOR}           Override hostname display in prompt (export CHIEF_HOST=\"my-server\")"
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
  echo -e "• Edit config file: ${CHIEF_COLOR_GREEN}${cmd_prefix}config${CHIEF_NO_COLOR}"
  echo -e "• Set config directly: ${CHIEF_COLOR_GREEN}${cmd_prefix}config_set <option> <value>${CHIEF_NO_COLOR}"
  echo -e "• List all config vars: ${CHIEF_COLOR_GREEN}${cmd_prefix}config_set --list${CHIEF_NO_COLOR}"
  echo -e "• Update config with latest options: ${CHIEF_COLOR_GREEN}${cmd_prefix}config-update${CHIEF_NO_COLOR}"
  echo -e "• View current config: ${CHIEF_COLOR_GREEN}cat $CHIEF_CONFIG${CHIEF_NO_COLOR}"
  echo -e "• Reload after changes: ${CHIEF_COLOR_GREEN}${cmd_prefix}reload${CHIEF_NO_COLOR}"
  echo -e "• Test prompt: ${CHIEF_COLOR_GREEN}${cmd_prefix}git.legend${CHIEF_NO_COLOR} (if git prompt enabled)"
  echo
  echo -e "${CHIEF_COLOR_BLUE}Configuration Examples:${CHIEF_NO_COLOR}"
  echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}config_set banner false${CHIEF_NO_COLOR}     # Disable startup banner (with prompt)"
  echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}config_set --yes prompt true${CHIEF_NO_COLOR}      # Enable Chief prompt (no prompt)"  
  echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}config_set colored_ls true${CHIEF_NO_COLOR}  # Enable colored ls (with prompt)"
  echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}config_set config_set_interactive false${CHIEF_NO_COLOR} # Disable prompts globally"
}

# Show compact command reference
function __chief_show_compact_reference() {
  local cmd_prefix=$(__chief_get_command_prefix)
  echo -e "${CHIEF_COLOR_YELLOW}Chief Quick Reference:${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR} All commands below should be prefixed with ${CHIEF_COLOR_GREEN}${cmd_prefix}${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Core Commands:${CHIEF_NO_COLOR}"
  echo "  config, config_set, reload, update, uninstall, status, whereis, hints, help"
  echo
  echo -e "${CHIEF_COLOR_CYAN}File Editors:${CHIEF_NO_COLOR}"
  echo "  edit-file, bash_profile, bashrc, profile"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Plugin Management:${CHIEF_NO_COLOR}"
  echo "  plugin [name], plugins_root (navigate), plugin -? (list), plugin status (enabled/disabled)"
  echo

  # Show core (built-in) and user plugin lists
  local core_list=$(__chief_get_core_plugins)
  local user_list=$(__chief_get_plugins)
  local core_disabled_compact user_disabled_compact
  core_disabled_compact="$(__chief_get_core_plugins_disabled)"
  user_disabled_compact="$(__chief_plugin_normalize_disabled_list "${CHIEF_CFG_PLUGINS_DISABLED_USER:-}")"
  if [[ -n "$core_list" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Core (built-in):${CHIEF_NO_COLOR}"
    echo "  $(__chief_format_plugin_list "$core_list")"
    echo
  fi
  local contrib_list=$(__chief_get_contrib_plugins enabled)
  if [[ -n "$contrib_list" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Contrib (enabled):${CHIEF_NO_COLOR}"
    echo "  $(__chief_format_plugin_list "$contrib_list")"
    echo
  fi
  if [[ -n "$user_list" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}User plugins:${CHIEF_NO_COLOR}"
    echo "  $(__chief_format_plugin_list "$user_list")"
    echo
  fi
  if [[ -n "$core_disabled_compact" ]] || [[ -n "$user_disabled_compact" ]]; then
    local cdis_fmt udis_fmt
    cdis_fmt="$(__chief_format_plugin_list "${core_disabled_compact:-}")"
    udis_fmt="$(__chief_format_plugin_list "${user_disabled_compact:-}")"
    echo -e "${CHIEF_COLOR_YELLOW}Disabled (skipped):${CHIEF_NO_COLOR} ${CHIEF_COLOR_CYAN}core:${CHIEF_NO_COLOR} ${cdis_fmt:-<none>}; ${CHIEF_COLOR_CYAN}user:${CHIEF_NO_COLOR} ${udis_fmt:-<none>}"
    echo
  fi
  if [[ -z "$core_list" && -z "$user_list" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Plugins:${CHIEF_NO_COLOR}"
    echo "  No user plugins loaded - try '${cmd_prefix}plugin -?' to see/create user plugins; core: ${cmd_prefix}help plugins"
    echo
  fi
  
  echo -e "${CHIEF_COLOR_BLUE}Quick Tips:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}[tab][tab]${CHIEF_NO_COLOR} - see all commands"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}help${CHIEF_NO_COLOR} - detailed help system"
  echo -e "  ${CHIEF_COLOR_GREEN}${cmd_prefix}config${CHIEF_NO_COLOR} - customize settings"
}

# Search through Chief commands and help
function __chief_search_help() {
  local search_term="$1"
  local cmd_prefix=$(__chief_get_command_prefix)
  local search_prefix="chief"
  
  # If alias is configured, also search for alias functions
  if [[ -n ${CHIEF_CFG_ALIAS} ]]; then
    local alias=$(__chief_lower ${CHIEF_CFG_ALIAS})
    search_prefix="(chief|$alias)"
  fi
  
  if [[ -z "$search_term" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Please provide a search term"
    echo -e "${CHIEF_COLOR_BLUE}Usage:${CHIEF_NO_COLOR} ${cmd_prefix}help --search <term>"
    return 1
  fi
  
  echo -e "${CHIEF_COLOR_CYAN}Searching for: ${CHIEF_COLOR_YELLOW}$search_term${CHIEF_NO_COLOR}"
  echo
  
  # Search function names (look for both chief.* and alias.* if applicable)
  local matching_functions=($(compgen -A function | grep -iE "^${search_prefix}.*$search_term" | sort))
  if [[ ${#matching_functions[@]} -gt 0 ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Matching Functions:${CHIEF_NO_COLOR}"
    for func in "${matching_functions[@]}"; do
      echo -e "  ${CHIEF_COLOR_CYAN}$func${CHIEF_NO_COLOR}"
    done
    echo
  fi
  
  # Search aliases (look for both chief.* and alias.* if applicable)
  local matching_aliases=($(compgen -A alias | grep -iE "^${search_prefix}.*$search_term" | sort))
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
    echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}help commands${CHIEF_NO_COLOR} - see all core commands"
    echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}help plugins${CHIEF_NO_COLOR} - see plugin commands"
    echo -e "• ${CHIEF_COLOR_GREEN}${cmd_prefix}[tab][tab]${CHIEF_NO_COLOR} - bash completion"
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
      done < <(find -L "$dir" \( -name "*.sh" -o -name "*.bash" \) -type f -print0 2>/dev/null)
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
    done < <(find -L "${CHIEF_PATH}/libs/core/plugins" -name "*.sh" -type f -print0 2>/dev/null)
  fi
  
  # User plugins
  # Determine the correct plugin directory for search
  local configured_plugin_dir
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" && -n ${CHIEF_CFG_PLUGINS_GIT_PATH} ]]; then
    configured_plugin_dir="${CHIEF_CFG_PLUGINS_PATH}/${CHIEF_CFG_PLUGINS_GIT_PATH}"
  else
    configured_plugin_dir=${CHIEF_CFG_PLUGINS_PATH}
  fi
  
  # find -L: follow symlinks, so plugins linked in with `chief.plugin <name> <file>` (and
  # plugin dirs that are themselves symlinks) are searched; -type f then tests the link target.
  for plugin_dir in "${configured_plugin_dir}" ~/.chief_plugins ~/.local/share/chief/plugins; do
    if [[ -n "$plugin_dir" && -d "$plugin_dir" ]]; then
      while IFS= read -r -d '' file; do
        search_files+=("$file")
      done < <(find -L "$plugin_dir" -name "*.sh" -type f -print0 2>/dev/null)
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
      matches=$(grep -n -E "(^|[[:space:]])(export[[:space:]]+${name}[=[:space:]]|${name}[[:space:]]*=|function[[:space:]]+${name}[[:space:]]*\\(|${name}[[:space:]]*\\(|alias[[:space:]]+${name}[=[:space:]])" "$file" 2>/dev/null | grep -v -E '^[0-9]+:[[:space:]]*#')

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
