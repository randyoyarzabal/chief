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
  Linux*) PLATFORM='Linux' ;;
  Darwin*) PLATFORM='MacOS' ;;
  CYGWIN*) PLATFORM='Cygwin' ;;
  MINGW*) PLATFORM='MinGw' ;;
  *) PLATFORM="UNKNOWN:${uname_out}" ;;
esac

#  Note: this only applied to any function/alias starting with "chief."
function __load_file() {
  # Usage: __load_file <source_file>
  # 
  # Developer usage: Sources a file with optional alias substitution
  # - If CHIEF_CFG_ALIAS is set, creates a temporary file with chief.* functions renamed to the alias
  # - Sources both the aliased version and original version to ensure compatibility
  # - Used internally by __load_library() to load configuration and library files
  #
  # Arguments:
  #   source_file - Path to the file to be sourced
  
  #Set default values
  local tmp_lib=$(__get_tmpfile) # Temporary library file.
  local source_file=${1} # File to source

  if [[ -n ${CHIEF_CFG_ALIAS} ]]; then
    # Substitute chief.* with alias if requested
    local alias=$(__lower ${CHIEF_CFG_ALIAS})
    
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

function __load_library() {
  # Usage: __load_library [--verbose]
  # 
  # Developer usage: Loads Chief configuration and library files
  # - Sources configuration file first, then the library file
  # - Loads all available plugins from configured plugin directories
  # - Prints verbose output if --verbose flag is provided
  # - Used internally during Chief initialization
  #
  # Options:
  #   --verbose - Display detailed loading information
  
  __load_file ${CHIEF_CONFIG}

  __load_file ${CHIEF_LIBRARY} 

  # Set a default alias if none defined.
  if [[ -n ${CHIEF_CFG_ALIAS} ]]; then
    __print "Chief is aliased as ${CHIEF_CFG_ALIAS}."
  fi

  __load_plugins 'core' "$1"

  if [[ -z ${CHIEF_CFG_PLUGINS_TYPE} ]]; then
    # If not set, default to local plugins.
    CHIEF_CFG_PLUGINS_TYPE=${CHIEF_DEFAULT_PLUGINS_TYPE}
  fi

  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]]; then
    __load_remote_plugins "$1"
  elif [[ ${CHIEF_CFG_PLUGINS_TYPE} == "local" ]]; then
    __load_plugins 'user' "$1"
  fi

  __print "Chief BASH library/environment (re)loaded." "$1"
}

function __print() {
  # Usage: __print <string> [--verbose]
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

function __lower() {
  # Usage: __lower <string>
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

function __upper() {
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

function __get_tmpfile() {
  # Usage: __get_tmpfile
  # 
  # Developer usage: Generates a unique temporary file path
  # - Creates platform-specific random filename in /tmp directory
  # - Uses /dev/random on macOS and /dev/urandom on Linux for entropy
  # - Returns absolute path to temporary file (file is not created, just named)
  # - Used internally by __load_file for alias processing
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

function __this_file() {
  # This is used inside a script like a Chief plugin file.
  # Usage: __edit_file ${BASH_SOURCE[0]}
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
function __edit_file() {
  # Usage: __edit_file <file>
  local file=${1}
  local date1
  local date2
  if [[ ${PLATFORM} == "MacOS" ]]; then
    date1=$(stat -L -f "%Sm" -t "%Y%m%dT%H%M%S" "$file")
    vi ${file}
    date2=$(stat -L -f "%Sm" -t "%Y%m%dT%H%M%S" "$file")
  else
    date1=$(stat -L -c %y "$file")
    vi ${file}
    date2=$(stat -L -c %y "$file")
  fi

  # Check if the file was actually modified before reloading
  if [[ ${date2} != ${date1} ]]; then
    if [[ -z $3 ]]; then
      __load_file ${file}
    else
      if [[ $3 == 'reload' ]]; then
        __load_library --verbose  
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

__load_remote_plugins() {
  # Usage: __load_remote_plugins [--verbose] [--force]
  # 
  # Developer usage: Loads remote plugins from a git repository
  # - Checks if autoupdate is enabled or --force flag is provided
  # - Prompts user to update if plugins directory is empty/doesn't exist
  # - Clones/updates git repository if necessary
  # - Loads plugins from the git repository
  #
  # Options:
  #   --verbose - Display detailed loading information
  #   --force - Force update of plugins
  
  local good_to_load=false
  # If autoupdate is disabled or --force was used.
  if ${CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE} || [[ "$2" == "--force" ]]; then
    good_to_load=true
  # If the git path isn't set Or path doesn't exist Or it is empty.
  elif [[ -z ${CHIEF_CFG_PLUGINS_GIT_PATH} ]] || [[ ! -d ${CHIEF_CFG_PLUGINS_GIT_PATH} ]] || [[ -z "$(ls -A ${CHIEF_CFG_PLUGINS_GIT_PATH})" ]]; then
    if chief.etc_ask_yes_or_no "Your Chief plugins directory is empty/doesn't exist, do you want to run the update now?
You can run 'chief.plugins_update' anytime or set CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=true"; then
      good_to_load=true
    fi  
  fi

  if ${good_to_load}; then
    echo "Configured values:
CHIEF_CFG_PLUGINS_GIT_REPO=${CHIEF_CFG_PLUGINS_GIT_REPO}
CHIEF_CFG_PLUGINS_GIT_BRANCH=${CHIEF_CFG_PLUGINS_GIT_BRANCH}
CHIEF_CFG_PLUGINS_GIT_PATH=${CHIEF_CFG_PLUGINS_GIT_PATH}
CHIEF_CFG_PLUGINS=${CHIEF_CFG_PLUGINS}"

    # Check if git is installed.
    if ! command -v git &> /dev/null; then
      echo -e "${CHIEF_COLOR_RED}Error: git is not installed. Please install git to use remote plugins.${CHIEF_NO_COLOR}"
      return 1
    fi

    if [[ -z ${CHIEF_CFG_PLUGINS_GIT_PATH} ]] || [[ ! -d ${CHIEF_CFG_PLUGINS_GIT_PATH} ]]; then
      mkdir -p ${CHIEF_CFG_PLUGINS_GIT_PATH} || {
        echo -e "${CHIEF_COLOR_RED}Error: Unable to create directory '${CHIEF_CFG_PLUGINS_GIT_PATH}'.${CHIEF_NO_COLOR}"
        return 1
      }
    fi

    # Check if a git branch is defined, if not, set to default.
    if [[ -z ${CHIEF_CFG_PLUGINS_GIT_BRANCH} ]]; then
      CHIEF_CFG_PLUGINS_GIT_BRANCH=${CHIEF_DEFAULT_PLUGINS_GIT_BRANCH}
    fi

    # Check if the git repository exists, if not, clone it.
    if [[ ! -d ${CHIEF_CFG_PLUGINS_GIT_PATH}/.git ]]; then
      echo "Cloning remote plugins repository..."
      git clone --branch ${CHIEF_CFG_PLUGINS_GIT_BRANCH} ${CHIEF_CFG_PLUGINS_GIT_REPO} ${CHIEF_CFG_PLUGINS_GIT_PATH}
    else
      echo "Updating remote plugins repository..."
      cd "${CHIEF_CFG_PLUGINS_GIT_PATH}"
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
    if [[ $(__get_plugins) == "" ]] && ! ${CHIEF_CFG_HINTS}; then
      echo -e "${CHIEF_COLOR_YELLOW}Remote plugins are not set to auto-update (CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=false). ${CHIEF_COLOR_CYAN}chief.plugins_update${CHIEF_COLOR_YELLOW}' to update.${CHIEF_NO_COLOR}"
    fi
  fi
  # Load plugins from the remote repository.
  __load_plugins 'user' "$1"
}

# Source the library/plugin module passed.
function __load_plugins() {
  # Usage: __load_plugins <plug-in module> (user/core) 
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
  __print "Loading Chief ${1}-plugins..." "$2"

  local plugin_file
  local plugin_name
  local dir_path
  local load_flag

  load_flag=false # Default to false, unless plugin switch is defined.
  if [[ $1 == 'core' ]]; then
    dir_path=${CHIEF_PLUGINS_CORE}
    load_flag=true
  elif [[ $1 == 'user' ]]; then
    dir_path=${CHIEF_CFG_PLUGINS}
    if [[ -n ${CHIEF_CFG_PLUGINS} ]]; then
      load_flag=true
    fi
  else
    __print "   plugins: ${1} is not a valid plug-in module." "$2"
    return 1
  fi

  local plugins=() # Array to hold plugin names
  local sorted_plugins=() # Array to hold sorted plugin names
  if ! ${load_flag}; then
    __print "   plugins: ${1} not enabled." "$2"
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
          __load_file "${plugin}" # Apply alias and source the plugin
          __print "   plugin: ${plugin_name} loaded." "$2"
        fi
      done
    else
      __print "   $1 plugins directory does not exist." "$2"
    fi
  fi
}

__get_plugins() {
  # Usage: __get_plugins
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

  dir_path=${CHIEF_CFG_PLUGINS}

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
# Usage: __edit_plugin <plug-in name>
function __edit_plugin() {
  local plugin_name
  local plugin_file

  # Check if plugins are enabled.
  if [[ -z ${CHIEF_CFG_PLUGINS} ]]; then
    echo "Chief plugins are not enabled."
    return
  fi

  plugin_name=$(__lower ${1})
  plugin_file="${CHIEF_CFG_PLUGINS}/${plugin_name}${CHIEF_PLUGIN_SUFFIX}"

  # Check if the plugin file exists, if not, prompt to create it.
  if [[ -f ${plugin_file} ]]; then
    __edit_file ${plugin_file}
  else
    echo "Chief plugin: ${plugin_name} plugin file does not exist."
    if ! chief.etc_ask_yes_or_no "Create it?"; then
      echo -e "${CHIEF_COLOR_YELLOW}Plugin file not created.${CHIEF_NO_COLOR}"
      return 1
    fi

    # Get the plugin template file
    if [[ -z ${CHIEF_CFG_PLUGIN_TEMPLATE} ]] || [[ ! -f ${CHIEF_CFG_PLUGIN_TEMPLATE} ]]; then
      echo -e "${CHIEF_COLOR_RED}Chief plugin template not defined or does not exist. Using default template.${CHIEF_NO_COLOR}"
      CHIEF_CFG_PLUGIN_TEMPLATE=${CHIEF_DEFAULT_PLUGIN_TEMPLATE}
    fi

    # Check if a plugin directory is defined, if not, set to default.
    if [[ -z ${CHIEF_CFG_PLUGINS} ]]; then
      CHIEF_CFG_PLUGINS=${CHIEF_DEFAULT_PLUGINS}
    fi

    # Create the plugins directory if it does not exist.
    if [[ ! -d ${CHIEF_CFG_PLUGINS} ]]; then
      mkdir -p ${CHIEF_CFG_PLUGINS} || {
        echo -e "${CHIEF_COLOR_RED}Error: Unable to create directory '${CHIEF_CFG_PLUGINS}'.${CHIEF_NO_COLOR}"
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
    __edit_file ${plugin_file}
  fi
}

# Display Chief banner
function __chief.banner {
  local git_status
  local alias_status

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
  echo -e "${CHIEF_COLOR_YELLOW}        __    _      ____${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}  _____/ /_  (_)__  / __/ ${alias_status}${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW} / ___/ __ \/ / _ \/ /_  ${git_status}${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}/ /__/ / / / /  __/ __/ ${CHIEF_COLOR_CYAN}${CHIEF_WEBSITE}${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}\___/_/ /_/_/\___/_/ ${CHIEF_NO_COLOR}${CHIEF_VERSION} [${PLATFORM}]"
}

# Display "hints" text and dynamically display alias if necessary.
function __chief.hints_text() {
  # Usage: __chief.hints_text
  if ${CHIEF_CFG_HINTS} || [[ ${1} == '--verbose' ]]; then
    # If plugins are not set to auto-update, display a message.
    if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]] && ! ${CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE}; then   
      echo -e "${CHIEF_COLOR_GREEN}chief.[tab]${CHIEF_NO_COLOR} for available commands. | ${CHIEF_COLOR_GREEN}chief.plugins_update${CHIEF_NO_COLOR} to update/load plugins."
    else
      echo -e "${CHIEF_COLOR_GREEN}chief.[tab]${CHIEF_NO_COLOR} for available commands.${CHIEF_NO_COLOR}"
    fi
    local plugin_list=$(__get_plugins)
    if [[ ${plugin_list} != "" ]]; then
      echo -e "${CHIEF_COLOR_GREEN}Plugins loaded: ${CHIEF_COLOR_CYAN}${plugin_list}${CHIEF_NO_COLOR}"
    fi
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Essential Commands:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR} to edit configuration and explore features"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.help${CHIEF_NO_COLOR} for comprehensive help | ${CHIEF_COLOR_GREEN}chief.help --compact${CHIEF_NO_COLOR} for quick reference"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.whereis <name>${CHIEF_NO_COLOR} to find any function/alias location"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.vault_*${CHIEF_NO_COLOR} to encrypt/decrypt secrets (requires ansible-vault)"
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Quick Customization:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}CHIEF_CFG_PROMPT=true${CHIEF_NO_COLOR} for git-aware prompt | ${CHIEF_COLOR_GREEN}chief.git_legend${CHIEF_NO_COLOR} for colors"
    echo -e "- ${CHIEF_COLOR_GREEN}CHIEF_CFG_MULTILINE_PROMPT=true${CHIEF_NO_COLOR} for multi-line prompt"
    echo -e "- ${CHIEF_COLOR_GREEN}CHIEF_CFG_SHORT_PATH=true${CHIEF_NO_COLOR} for compact directory paths"
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Plugin Management:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugin [name]${CHIEF_NO_COLOR} to create/edit plugins | ${CHIEF_COLOR_GREEN}chief.plugin -?${CHIEF_NO_COLOR} to list"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugins${CHIEF_NO_COLOR} to navigate to plugins directory"
    echo ""
    if [[ ${1} != '--verbose' ]]; then
      echo -e "${CHIEF_COLOR_CYAN}** Set ${CHIEF_COLOR_GREEN}CHIEF_CFG_HINTS=false${CHIEF_COLOR_CYAN} to disable these hints. **${CHIEF_NO_COLOR}"
      echo ""
    fi
  else
    echo ""
  fi
}

# Display compact Chief hints and tips
function chief.hints() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--banner]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Display compact Chief tips, hints, and quick command reference.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --banner    Show Chief banner with hints

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Quick command overview
- Plugin status and suggestions
- Configuration tips
- Essential workflow commands

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Show compact hints
  $FUNCNAME --banner          # Show banner with hints
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if [[ $1 == "--banner" ]]; then
    __chief.banner
  fi
  
  __chief.hints_text --verbose
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

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  case "${1:-full}" in
    commands|cmd)
      __show_core_commands
      ;;
    plugins|plug)
      __show_plugin_help
      ;;
    config|cfg)
      __show_configuration_help
      ;;
    search)
      __search_help "$2"
      ;;
    --compact|-c)
      __show_compact_reference
      ;;
    --search)
      __search_help "$2"
      ;;
    full|*)
      __chief.banner
      echo
      __show_chief_stats
      echo
      echo -e "${CHIEF_COLOR_YELLOW}Available help categories:${CHIEF_NO_COLOR}"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.help commands${CHIEF_NO_COLOR}  - Core commands and usage"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.help plugins${CHIEF_NO_COLOR}   - Plugin management"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.help config${CHIEF_NO_COLOR}    - Configuration options"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.help --compact${CHIEF_NO_COLOR} - Quick reference"
      echo -e "• ${CHIEF_COLOR_GREEN}chief.hints${CHIEF_NO_COLOR}          - Quick tips and workflow"
      echo
      echo -e "${CHIEF_COLOR_CYAN}Quick start: ${CHIEF_COLOR_GREEN}chief.[tab][tab]${CHIEF_NO_COLOR} to see all commands"
      ;;
  esac
}

# Display Chief version info.
function __chief.info() {
  # Usage: __chief.info
  __chief.banner
  echo -e "${CHIEF_COLOR_YELLOW}GitHub Repo: ${CHIEF_COLOR_CYAN}${CHIEF_REPO}${CHIEF_NO_COLOR}"
}

# Start SSH agent
function __start_agent {
  # Usage: __start_agent
  __print "Initializing new SSH agent..."
  (
    umask 066
    /usr/bin/ssh-agent >"${SSH_ENV}"
  )
  . "${SSH_ENV}" >/dev/null
}

function __load_ssh_keys() {
    __print "Loading SSH keys from: ${CHIEF_CFG_RSA_KEYS_PATH}..." "$1"

  if [[ ${PLATFORM} == "MacOS" ]]; then
    load="/usr/bin/ssh-add --apple-use-keychain"
  elif [[ ${PLATFORM} == "Linux" ]]; then
    # This will load ssh-agent (only if needed) just once and will only be reloaded on reboot.
    load="/usr/bin/ssh-add"
    SSH_ENV="$HOME/.ssh/environment"

    if [[ -f "${SSH_ENV}" ]]; then
      . "${SSH_ENV}" >/dev/null
      ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ >/dev/null || {
        __start_agent
      }
    else
      __start_agent
    fi
  fi

  # Load all keys. Skip authorized_keys, environment, and known_hosts.
  for rsa_key in ${CHIEF_CFG_RSA_KEYS_PATH}/*.rsa; do
    if ${CHIEF_CFG_VERBOSE} || [[ "${1}" == '--verbose' ]]; then
      ${load} ${rsa_key}
    else
      ${load} ${rsa_key} &> /dev/null
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
function __build_git_prompt() {
  # Usage: PROMPT_COMMAND='__build_git_prompt'
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

function __check_for_updates (){
  cd ${CHIEF_PATH}
  local CHANGE_MSG="${CHIEF_COLOR_GREEN}**Chief updates available**${CHIEF_NO_COLOR}"

  # Get local branch name
  local LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

  # Get change hash local and remote for later comparison
  local LOCAL_HASH=$(git rev-parse HEAD)
  local REMOTE_HASH=$(git ls-remote --tags --heads 2> /dev/null | grep heads/${LOCAL_BRANCH} | awk '{ print $1 }')

  # Only compare local/remote changes if no local changes exist.
  if [[ -n $(git status -s) ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} local Chief changes detected. Update checking skipped."
  elif [[ ${LOCAL_HASH} != ${REMOTE_HASH} ]]; then
    echo -e "${CHANGE_MSG}"
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

function __print_error(){
  echo -e "${CHIEF_COLOR_RED}Error: $1${CHIEF_NO_COLOR}"
}

function __print_warn(){
  echo -e "${CHIEF_COLOR_YELLOW}Warning: $1${CHIEF_NO_COLOR}"
}

function __print_success(){
  echo -e "${CHIEF_COLOR_GREEN}$1${CHIEF_NO_COLOR}"
}

function __print_info(){
  echo -e "${CHIEF_COLOR_CYAN}$1${CHIEF_NO_COLOR}"
}

# MAIN FUNCTIONS
########################################################################

alias chief.ver='__chief.info'

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

Load SSH keys from CHIEF_CFG_RSA_KEYS_PATH defined in the Chief configuration.
Note: All private keys must end with the suffix '.rsa'. Symlinks are allowed.
"

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  if [[ -z ${CHIEF_CFG_RSA_KEYS_PATH}  ]]; then
    echo -e "${CHIEF_COLOR_RED}Error: CHIEF_CFG_RSA_KEYS_PATH is not set in ${CHIEF_CONFIG}. Please set it to the path where your SSH keys are stored.${CHIEF_NO_COLOR}"
    echo "${USAGE}"
    return 1
  fi
  chief.etc_spinner "Loading SSH keys..." "__load_ssh_keys --verbose" tmp_out
  echo -e "${tmp_out}"
}

function chief.plugins_update() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Update and reload remote Chief plugins when using remote plugin configuration.

${CHIEF_COLOR_GREEN}Requirements:${CHIEF_NO_COLOR}
- CHIEF_CFG_PLUGINS_TYPE must be set to 'remote'
- CHIEF_CFG_PLUGINS_GIT_REPO must be configured
- Git must be available and repository accessible

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Fetches latest plugin versions from Git repository
- Automatically reloads updated plugins
- Provides verbose feedback during update process
- Maintains local plugin configuration

${CHIEF_COLOR_MAGENTA}Plugin Types:${CHIEF_NO_COLOR}
- ${CHIEF_COLOR_GREEN}Remote:${CHIEF_NO_COLOR} Plugins managed via Git repository (team sharing)
- ${CHIEF_COLOR_BLUE}Local:${CHIEF_NO_COLOR} Plugins in ~/chief_plugins (personal use)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Update all remote plugins
  chief.config                 # Configure plugin settings first

${CHIEF_COLOR_BLUE}Configuration:${CHIEF_NO_COLOR}
Set CHIEF_CFG_PLUGINS_TYPE='remote' and CHIEF_CFG_PLUGINS_GIT_REPO in chief.config
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi
  if [[ ${CHIEF_CFG_PLUGINS_TYPE} == "remote" ]]; then
    __load_remote_plugins "--verbose" "--force" && {
      echo -e "${CHIEF_COLOR_GREEN}Updated all plugins to the latest version.${CHIEF_NO_COLOR}"
    } || {
      echo -e "${CHIEF_COLOR_RED}Error: Failed to update plugins.${CHIEF_NO_COLOR}"
    }
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

${CHIEF_COLOR_BLUE}Update Process:${CHIEF_NO_COLOR}
1. Check for available updates
2. Prompt for user confirmation
3. Pull latest Chief version
4. Reload Chief environment
5. Return to original directory

${CHIEF_COLOR_MAGENTA}Safety Features:${CHIEF_NO_COLOR}
- Only updates Chief core files
- Preserves user configurations and plugins
- Shows progress with visual feedback
- Requires explicit user confirmation

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
  chief.etc_spinner "Checking for updates..." "__check_for_updates" tmp_out
  echo -e "${tmp_out}"
  if [[ ${tmp_out} == *"available"* ]]; then
    if chief.etc_ask_yes_or_no "Updates are available, update now?"; then
      ${CHIEF_PATH}
      chief.git_update -p
      chief.reload
      cd - > /dev/null 2>&1
      echo -e "${CHIEF_COLOR_GREEN}Updated Chief to [${CHIEF_VERSION}].${CHIEF_NO_COLOR}"
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
- CHIEF_CFG_RSA_KEYS_PATH: Auto-load SSH keys path
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
  __edit_file ${CHIEF_CONFIG} "Chief Configuration" "reload" && {
    echo -e "${CHIEF_COLOR_YELLOW}Terminal/session restart is required for some changes to take effect.${CHIEF_NO_COLOR}"
  }
}

function chief.plugins() {
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

  if [[ ! -d "$CHIEF_CFG_PLUGINS" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Plugin directory does not exist: $CHIEF_CFG_PLUGINS"
    echo -e "${CHIEF_COLOR_BLUE}Creating directory...${CHIEF_NO_COLOR}"
    mkdir -p "$CHIEF_CFG_PLUGINS"
  fi

  cd ${CHIEF_CFG_PLUGINS}
  echo -e "${CHIEF_COLOR_GREEN}Changed directory to CHIEF_CFG_PLUGINS=${CHIEF_CFG_PLUGINS}.${CHIEF_NO_COLOR}"
}

function chief.plugin() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [plugin_name]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Edit a Chief plugin file with automatic reload on changes.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  plugin_name  Name of plugin to edit (without _chief-plugin.sh suffix)

${CHIEF_COLOR_GREEN}Available Plugins:${CHIEF_NO_COLOR}
$(__get_plugins)

${CHIEF_COLOR_MAGENTA}Plugin Naming Convention:${CHIEF_NO_COLOR}
- File format: <name>_chief-plugin.sh
- Function format: <name>.<function_name>()
- Must be executable and sourced

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME            # Edit default plugin
  $FUNCNAME mytools    # Edit mytools_chief-plugin.sh
  $FUNCNAME aws        # Edit aws_chief-plugin.sh

${CHIEF_COLOR_BLUE}Features:${CHIEF_NO_COLOR}
- Opens in your preferred \$EDITOR
- Automatically reloads plugin on save
- Creates new plugin if it doesn't exist
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if [[ -z $1 ]]; then
    __edit_plugin default
  else
    __edit_plugin $1
  fi
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

  __edit_file "$HOME/.bash_profile"
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

  __edit_file "$HOME/.bashrc"
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

  __edit_file "$HOME/.profile"
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
  __load_library --verbose
  echo -e "${CHIEF_COLOR_GREEN}Chief environment reloaded successfully${CHIEF_NO_COLOR}"
}

# Show Chief statistics and status
function __show_chief_stats() {
  local total_functions=$(compgen -A function | grep "^chief\." | wc -l | tr -d ' ')
  local loaded_plugins=$(__get_plugins)
  local plugin_count=0
  
  if [[ -n "$loaded_plugins" ]]; then
    plugin_count=$(echo "$loaded_plugins" | tr ',' '\n' | wc -l | tr -d ' ')
  fi
  
  echo -e "${CHIEF_COLOR_BLUE}Chief Status:${CHIEF_NO_COLOR}"
  echo -e "• Functions available: ${CHIEF_COLOR_CYAN}$total_functions${CHIEF_NO_COLOR}"
  echo -e "• Plugins loaded: ${CHIEF_COLOR_CYAN}$plugin_count${CHIEF_NO_COLOR} ($loaded_plugins)"
  echo -e "• Configuration: ${CHIEF_COLOR_CYAN}$CHIEF_CONFIG${CHIEF_NO_COLOR}"
  echo -e "• Version: ${CHIEF_COLOR_CYAN}$CHIEF_VERSION${CHIEF_NO_COLOR} on $PLATFORM"
}

# Show core Chief commands
function __show_core_commands() {
  echo -e "${CHIEF_COLOR_YELLOW}Core Chief Commands:${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Configuration & Setup:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR}        Edit Chief configuration"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.reload${CHIEF_NO_COLOR}        Reload Chief environment"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.update${CHIEF_NO_COLOR}        Update Chief to latest version"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.uninstall${CHIEF_NO_COLOR}     Remove Chief from system"
  echo
  echo -e "${CHIEF_COLOR_CYAN}File Management:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.bash_profile${CHIEF_NO_COLOR}  Edit ~/.bash_profile"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.bashrc${CHIEF_NO_COLOR}        Edit ~/.bashrc"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.profile${CHIEF_NO_COLOR}       Edit ~/.profile"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Plugin Management:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugins${CHIEF_NO_COLOR}       Navigate to plugins directory"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugin${CHIEF_NO_COLOR}        Create/edit plugins"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugin -?${CHIEF_NO_COLOR}     List available plugins"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Utilities:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.whereis${CHIEF_NO_COLOR}       Find function/variable definitions"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.hints${CHIEF_NO_COLOR}         Show quick tips and workflow"
  echo
  echo -e "${CHIEF_COLOR_BLUE}Usage tip:${CHIEF_NO_COLOR} Add ${CHIEF_COLOR_GREEN}-?${CHIEF_NO_COLOR} to any command for detailed help"
}

# Show plugin-related help
function __show_plugin_help() {
  echo -e "${CHIEF_COLOR_YELLOW}Plugin Management:${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Plugin Commands:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugins${CHIEF_NO_COLOR}              Navigate to plugins directory"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugin${CHIEF_NO_COLOR}               Edit default plugin"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugin <name>${CHIEF_NO_COLOR}        Create/edit named plugin"
  echo -e "  ${CHIEF_COLOR_GREEN}chief.plugin -?${CHIEF_NO_COLOR}            List all plugins"
  echo
  
  local loaded_plugins=$(__get_plugins)
  if [[ -n "$loaded_plugins" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Currently Loaded Plugins:${CHIEF_NO_COLOR}"
    echo -e "  ${CHIEF_COLOR_CYAN}$loaded_plugins${CHIEF_NO_COLOR}"
    echo
  fi
  
  echo -e "${CHIEF_COLOR_CYAN}Available Plugin Commands:${CHIEF_NO_COLOR}"
  local commands=($(compgen -A function | grep "^chief\." | grep -v "^chief\.\(config\|reload\|update\|help\|hints\|whereis\|plugins\?\|bash\|profile\|uninstall\)" | sort))
  local current_plugin=""
  local plugin_commands=()
  
  for cmd in "${commands[@]}"; do
    if [[ $cmd =~ ^chief\.([^.]+)\. ]]; then
      local plugin="${BASH_REMATCH[1]}"
      if [[ $plugin != $current_plugin ]]; then
        if [[ -n $current_plugin ]]; then
          echo -e "    ${plugin_commands[@]}"
        fi
        echo -e "  ${CHIEF_COLOR_GREEN}${plugin}:${CHIEF_NO_COLOR}"
        current_plugin="$plugin"
        plugin_commands=()
      fi
      plugin_commands+=("$(basename "$cmd")")
    else
      # Core plugin commands without prefix
      if [[ $cmd =~ ^chief\.([^.]+)$ ]]; then
        echo -e "  ${CHIEF_COLOR_GREEN}core:${CHIEF_NO_COLOR} $(basename "$cmd")"
      fi
    fi
  done
  
  if [[ -n $current_plugin ]]; then
    echo -e "    ${plugin_commands[@]}"
  fi
  
  echo
  echo -e "${CHIEF_COLOR_BLUE}Plugin Development:${CHIEF_NO_COLOR}"
  echo -e "• Plugin location: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PLUGINS:-~/.chief_plugins}${CHIEF_NO_COLOR}"
  echo -e "• Template: ${CHIEF_COLOR_CYAN}${CHIEF_DEFAULT_PLUGIN_TEMPLATE}${CHIEF_NO_COLOR}"
}

# Show configuration help
function __show_configuration_help() {
  echo -e "${CHIEF_COLOR_YELLOW}Chief Configuration:${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Configuration File:${CHIEF_NO_COLOR}"
  echo -e "  Location: ${CHIEF_COLOR_CYAN}$CHIEF_CONFIG${CHIEF_NO_COLOR}"
  echo -e "  Edit: ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Key Configuration Options:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_GREEN}CHIEF_CFG_PROMPT${CHIEF_NO_COLOR}            Enable/disable custom prompt"
  echo -e "  ${CHIEF_COLOR_GREEN}CHIEF_CFG_SHORT_PATH${CHIEF_NO_COLOR}        Show short paths in prompt"
  echo -e "  ${CHIEF_COLOR_GREEN}CHIEF_CFG_HINTS${CHIEF_NO_COLOR}             Show/hide startup hints"
  echo -e "  ${CHIEF_COLOR_GREEN}CHIEF_CFG_VERBOSE${CHIEF_NO_COLOR}           Enable verbose output"
  echo -e "  ${CHIEF_COLOR_GREEN}CHIEF_CFG_PLUGINS${CHIEF_NO_COLOR}           Plugin directory path"
  echo -e "  ${CHIEF_COLOR_GREEN}CHIEF_CFG_PLUGINS_TYPE${CHIEF_NO_COLOR}      Plugin type (local/remote)"
  echo -e "  ${CHIEF_COLOR_GREEN}CHIEF_CFG_ALIAS${CHIEF_NO_COLOR}             Custom alias for chief commands"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Current Settings:${CHIEF_NO_COLOR}"
  echo -e "  Prompt: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PROMPT:-false}${CHIEF_NO_COLOR}"
  echo -e "  Short path: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_SHORT_PATH:-false}${CHIEF_NO_COLOR}"
  echo -e "  Hints: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_HINTS:-true}${CHIEF_NO_COLOR}"
  echo -e "  Plugins: ${CHIEF_COLOR_CYAN}${CHIEF_CFG_PLUGINS_TYPE:-local}${CHIEF_NO_COLOR}"
  if [[ -n "$CHIEF_CFG_ALIAS" ]]; then
    echo -e "  Alias: ${CHIEF_COLOR_CYAN}$CHIEF_CFG_ALIAS${CHIEF_NO_COLOR}"
  fi
  echo
  echo -e "${CHIEF_COLOR_BLUE}Quick actions:${CHIEF_NO_COLOR}"
  echo -e "• Edit config: ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR}"
  echo -e "• Reload after changes: ${CHIEF_COLOR_GREEN}chief.reload${CHIEF_NO_COLOR}"
}

# Show compact command reference
function __show_compact_reference() {
  echo -e "${CHIEF_COLOR_YELLOW}Chief Quick Reference:${CHIEF_NO_COLOR}"
  echo
  echo -e "${CHIEF_COLOR_CYAN}Core:${CHIEF_NO_COLOR} config reload update uninstall whereis hints"
  echo -e "${CHIEF_COLOR_CYAN}Files:${CHIEF_NO_COLOR} bash_profile bashrc profile"
  echo -e "${CHIEF_COLOR_CYAN}Plugins:${CHIEF_NO_COLOR} plugins plugin"
  
  # Show available plugin namespaces
  local plugin_namespaces=($(compgen -A function | grep "^chief\." | sed 's/^chief\.\([^.]*\)\..*/\1/' | sort -u))
  if [[ ${#plugin_namespaces[@]} -gt 0 ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Available:${CHIEF_NO_COLOR} ${plugin_namespaces[@]}"
  fi
  
  echo
  echo -e "${CHIEF_COLOR_BLUE}Tip:${CHIEF_NO_COLOR} ${CHIEF_COLOR_GREEN}chief.[tab][tab]${CHIEF_NO_COLOR} for all commands, ${CHIEF_COLOR_GREEN}chief.help${CHIEF_NO_COLOR} for detailed help"
}

# Search through Chief commands and help
function __search_help() {
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
    • \$CHIEF_CFG_PLUGINS/*.sh (configured: ${CHIEF_CFG_PLUGINS:-"not set"})
    • ~/.chief_plugins/*.sh (default location)
    • ~/.local/share/chief/plugins/*.sh (XDG standard)

${CHIEF_COLOR_BLUE}Search Patterns:${CHIEF_NO_COLOR}
  Variables:  export VAR=, VAR=
  Functions:  function name(), name()
  Aliases:    alias name=

${CHIEF_COLOR_GREEN}Status Indicators:${CHIEF_NO_COLOR}
  ${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR} Currently loaded and active
  ${CHIEF_COLOR_RED}✗${CHIEF_NO_COLOR} Found in files but not loaded

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
  for plugin_dir in "${CHIEF_CFG_PLUGINS}" ~/.chief_plugins ~/.local/share/chief/plugins; do
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
      echo -e "  ${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR} Variable: ${name}=${!name}"
    fi
    
    if $is_func; then
      echo -e "  ${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR} Function: ${name}()"
    fi
    
    if $is_alias; then
      local alias_def
      alias_def=$(alias "$name" 2>/dev/null)
      echo -e "  ${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR} Alias: ${alias_def}"
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
