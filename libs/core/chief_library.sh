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

CHIEF_VERSION="v2.1.2"
CHIEF_REPO="https://github.com/randyoyarzabal/chief"
CHIEF_WEBSITE="https://chief.reonetlabs.us"
CHIEF_AUTHOR="Randy E. Oyarzabal"
CHIEF_GIT_TOOLS="${CHIEF_PATH}/libs/extras/git"

CHIEF_PLUGINS_CORE="${CHIEF_PATH}/libs/core/plugins"
CHIEF_PLUGIN_SUFFIX="_chief-plugin.sh"
CHIEF_DEFAULT_PLUGINS_TYPE="local" 
CHIEF_DEFAULT_PLUGINS_GIT_BRANCH="main"
CHIEF_DEFAULT_PLUGINS="${HOME}/chief_plugins"
CHIEF_DEFAULT_PLUGIN_TEMPLATE="${CHIEF_PATH}/templates/chief_plugin_template.sh"
CHIEF_CFG_LOAD_NON_ALIAS=true # Load non-alias functions from plugins by default.

# Block interactive execution
if [[ $0 = $BASH_SOURCE ]]; then
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

# Apply the alias defined in CHIEF_CFG_ALIAS to the file passed, then source it.
#  Note: this only applied to any function/alias starting with "chief."
# Usage: __load_file <library file>
function __load_file() {
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

# Load/source Chief library
function __load_library() {
  # Usage: __load_library
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

# Echo string to screen if CHIEF_CFG_VERBOSE is true.
function __print() {
  # Usage: __print <string>
  if ${CHIEF_CFG_VERBOSE} || [[ "${2}" == '--verbose' ]]; then
    echo "${1}"
  fi
}

# Echo string in lower-case.
function __lower() {
  # Usage: __lower <string>
  local valStr=$1
  valStr=$(echo $valStr | awk '{print tolower($0)}')
  echo $valStr
}

# Echo string in upper-case.
function __upper() {
  # Usage: __upper <string>
  local valStr=$1
  valStr=$(echo $valStr | awk '{print toupper($0)}')
  echo $valStr
}

# Create a temporary file in /tmp and echo the file name.
function __get_tmpfile() {
  # Usage: __get_tmpfile
  local tmp_file
  if [[ ${PLATFORM} == "MacOS" ]]; then
    tmp_file="/tmp/._$(cat /dev/random | LC_CTYPE=C tr -dc "[:alpha:]" | fold -w 8 | head -n 1)"
  else
    tmp_file="/tmp/._$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)"
  fi
  echo ${tmp_file}
}

# Get absolute path to file
function __this_file() {
  # This is used inside a script like a Chief plugin file.
  # Usage: __edit_file ${BASH_SOURCE[0]}
  # Reference: https://stackoverflow.com/a/9107028
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

# # This is a helper function to load a file as itself. But created to allow for future pre-processing
# #  e.g. to apply alias to the file before loading it.
# # Usage: __load_file <file> [<message>] 
# function __load_file() {
#   __load_file ${1} # Apply alias if defined, then source the file.
# }

# Load remote plugins from the git repository.
# This is only called if CHIEF_CFG_PLUGINS_TYPE is set to "remote".
# Usage: __load_remote_plugins
__load_remote_plugins() {
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
      cd ${CHIEF_CFG_PLUGINS_GIT_PATH}
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
      #mapfile -t sorted_plugins < <(printf "%s\n" "${plugins[@]}" | sort)
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

# Generate a list of plugins as a string separated by '|'.
#   This is used to display the list of plugins in the banner, hints, and chief.plugin help text.
#   This process is meant to run in addition to the __load_plugins function because it accounts for 
#   new plugins that are created once the terminal is already started.
# Usage: __get_plugins
__get_plugins() {
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
    echo -e "${CHIEF_COLOR_YELLOW}Explore the following Chief commands:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR} to edit the configuration and explore features.${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.update${CHIEF_NO_COLOR} to pull the latest version or set ${CHIEF_COLOR_GREEN}CHIEF_CFG_AUTOCHECK_UPDATES=true${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.bash_profile${CHIEF_NO_COLOR} to edit your .bash_profile file.${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.bashrc${CHIEF_NO_COLOR} to edit your .bashrc file.${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.* -? ${CHIEF_NO_COLOR} to display the help-text for any chief command. ${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}type chief.* ${CHIEF_NO_COLOR} on any command if you're curious or want to reuse the internal functions.${CHIEF_NO_COLOR}"
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Plugin-related:${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugin${CHIEF_NO_COLOR} to edit the default plugin.${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugin [plug-in name] ${CHIEF_NO_COLOR} to create/edit a plugin.${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugins${CHIEF_NO_COLOR} to cd into your plugins directory.${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.plugin -?${CHIEF_NO_COLOR} to list plugins.${CHIEF_NO_COLOR}"
    echo -e "- ${CHIEF_COLOR_GREEN}chief.whereis <function | alias>${CHIEF_NO_COLOR} to locate exact location of function or alias.${CHIEF_NO_COLOR}"
    echo ""
    if [[ ${1} != '--verbose' ]]; then
      echo -e "${CHIEF_COLOR_CYAN}** Set ${CHIEF_COLOR_GREEN}CHIEF_CFG_HINTS=false${CHIEF_COLOR_CYAN} to disable these hints. **${CHIEF_NO_COLOR}"
      echo ""
    fi
  else
    echo ""
  fi
}

# Force display of Chief banner and hints text.
function chief.help() {
  __chief.banner
  __chief.hints_text --verbose
}

# Display Chief version info.
function __chief.info() {
  # Usage: __chief.info
  __chief.banner
  echo -e "${CHIEF_COLOR_YELLOW}GitHub Repo: ${CHIEF_COLOR_CYAN}${CHIEF_REPO}${CHIEF_NO_COLOR}"
  __chief.hints_text
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
  local RED='\[\e[31m\]'
  local CHIEF_COLOR_BLUE='\[\e[34m\]'
  local CHIEF_COLOR_
  CYAN='\[\e[36m\]'
  local CHIEF_COLOR_GREEN='\[\e[32m\]'
  local CHIEF_COLOR_MAGENTA='\[\e[35m\]'
  local CHIEF_COLOR_ORANGE='\[\e[33m\]'
  local CHIEF_COLOR_YELLOW='\[\e[1;33m\]'
  local CHIEF_TEXT_BLINK='\[\e[5m\]'
  local CHIEF_NO_COLOR='\[\e[0m\]' # Reset color/style

  local ve_name=''
  if [[ ! -z ${VIRTUAL_ENV} ]]; then
    if ${CHIEF_CFG_COLORED_PROMPT}; then
      ve_name="(${CHIEF_COLOR_BLUE}${VIRTUAL_ENV##*/}${CHIEF_NO_COLOR}) "
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

  if ${CHIEF_CFG_COLORED_PROMPT}; then
    __git_ps1 "${ve_name}${CHIEF_COLOR_MAGENTA}\u${CHIEF_NO_COLOR}@${CHIEF_COLOR_GREEN}${host}${CHIEF_NO_COLOR}:${CHIEF_COLOR_YELLOW}${prompt_tag}${CHIEF_NO_COLOR}" "\\\$ "
  else
    __git_ps1 "${ve_name}\u@${host}:${prompt_tag}" "\\\$ "
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

CHIEF_COLOR_RED='\033[0;31m'
CHIEF_COLOR_BLUE='\033[0;34m'
CHIEF_COLOR_CYAN='\033[0;36m'
CHIEF_COLOR_GREEN='\033[0;32m'
CHIEF_COLOR_MAGENTA='\033[0;35m'
CHIEF_COLOR_ORANGE='\033[0;33m'
CHIEF_COLOR_YELLOW='\033[1;33m'
CHIEF_TEXT_BLINK='\033[5m'
CHIEF_NO_COLOR='\033[0m' # Reset color/style

# From: https://www.linuxquestions.org/questions/linux-newbie-8/bash-echo-the-arrow-keys-825773/
CHIEF_KEYS_ESC=$'\e'
CHIEF_KEYS_F1=$'\e'[[A
CHIEF_KEYS_F2=$'\e'[[B
CHIEF_KEYS_F3=$'\e'[[C
CHIEF_KEYS_F4=$'\e'[[D
CHIEF_KEYS_F5=$'\e'[[E
CHIEF_KEYS_F6=$'\e'[17~
CHIEF_KEYS_F7=$'\e'[18~
CHIEF_KEYS_F8=$'\e'[19~
CHIEF_KEYS_F9=$'\e'[20~
CHIEF_KEYS_F10=$'\e'[21~
CHIEF_KEYS_F11=$'\e'[22~
CHIEF_KEYS_F12=$'\e'[23~
CHIEF_KEYS_HOME=$'\e'[1~
CHIEF_KEYS_HOME2=$'\e'[H
CHIEF_KEYS_INSERT=$'\e'[2~
CHIEF_KEYS_DELETE=$'\e'[3~
CHIEF_KEYS_END=$'\e'[4~
CHIEF_KEYS_END2=$'\e'[F
CHIEF_KEYS_PAGEUP=$'\e'[5~
CHIEF_KEYS_PAGEDOWN=$'\e'[6~
CHIEF_KEYS_UP=$'\e'[A
CHIEF_KEYS_DOWN=$'\e'[B
CHIEF_KEYS_RIGHT=$'\e'[C
CHIEF_KEYS_LEFT=$'\e'[D
CHIEF_KEYS_NUMPADUNKNOWN=$'\e'[G


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
  local USAGE="Usage: $FUNCNAME

Update and reload the remote Chief plugins when CHIEF_CFG_PLUGINS_TYPE} == 'remote'.
This command will update all plugins to the latest version available from the git repository."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
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
  local USAGE="Usage: $FUNCNAME

Update the Chief utility library to the latest version."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
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
  local USAGE="Usage: $FUNCNAME

Uninstall the Chief utility.
The configuration file will be backed up as ${CHIEF_CONFIG}.backup.
All plugin files and plugin directories will NOT be removed.
This command will prompt for confirmation before proceeding with the uninstallation."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  ${CHIEF_PATH}/tools/uninstall.sh
}

function chief.config() {
  local USAGE="Usage: $FUNCNAME

Edit the Chief utility configuration."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  # Third parameter is to reload entire library if config is modified.
  __edit_file ${CHIEF_CONFIG} "Chief Configuration" "reload" && {
    echo -e "${CHIEF_COLOR_YELLOW}Terminal/session restart is required for some changes to take effect.${CHIEF_NO_COLOR}"
  }
}

function chief.plugins() {
  local USAGE="Usage: $FUNCNAME

Change directory (cd) into the Chief utility plugins directory root."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  cd ${CHIEF_CFG_PLUGINS}
  echo -e "${CHIEF_COLOR_GREEN}Changed directory to CHIEF_CFG_PLUGINS=${CHIEF_CFG_PLUGINS}.${CHIEF_NO_COLOR}"
}

function chief.plugin() {
  local USAGE="Usage: $FUNCNAME [$(__get_plugins)]

Edit a Chief plugin library. If no parameter is passed, the default plug-in will be edited."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  if [[ -z $1 ]]; then
    __edit_plugin default
  else
    __edit_plugin $1
  fi
}

function chief.bash_profile() {
  local USAGE="Usage: $FUNCNAME

Edit the user .bash_profile file and reload into memory if changed."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  __edit_file "$HOME/.bash_profile"
}

function chief.bashrc() {
  local USAGE="Usage: $FUNCNAME

Edit the user .bashrc file and reload into memory if changed."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  __edit_file "$HOME/.bashrc"
}

function chief.profile() {
  local USAGE="Usage: $FUNCNAME

Edit the user .profile file and reload into memory if changed."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  __edit_file "$HOME/.profile"
}

function chief.reload() {
  local USAGE="Usage: $FUNCNAME

Reload the Chief utility library/environment."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  __load_library --verbose
}

function chief.whereis() {
  local USAGE="Usage: $FUNCNAME <function or alias name>

Display the location of a function or alias."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  # Check if it's a function...
  local param="${1}"
  local found=$(shopt -s extdebug; declare -F "${param}")
  
  if [[ -n $found ]]; then
    local tmpsplit=(${found// / })
    echo "Function '${param}' found in file: ${tmpsplit[2]}"
    echo "  Line #: ${tmpsplit[1]}"
  else  
    # It's not a function, check if it's an alias...
    tmp="'\${BASH_ALIASES[\""${param}"\"]+\"FINDMYMARK\"} \${BASH_SOURCE}:\$LINENO '"
    found=$(PS4="$tmp" bash -lixc : |& grep 'FINDMYMARK' -m1 -B1 | grep "${param}" | awk '{print $2}')
    if [[ -n $found ]]; then
      tmpsplit=(${found//:/ })
      echo "Alias '${param}' found in file: ${tmpsplit[0]}"
      echo "  Line #: ${tmpsplit[1]}"
    else
      echo "Function/Alias not found."
    fi
  fi 
}