#!/usr/bin/env bash

# Prerequisite environment variables and functions for Chief.

###################################################################################################################
# WARNING: This file is not meant to be edited/configured/used directly unless you know what you are doing.
#   All settings and commands are available via the chief.* commands when "chief.sh" is sourced.
###################################################################################################################

###################################################################################################################
# NO USER SERVICEABLE PARTS BEYOND THIS POINT!

# Block interactive execution
if [[ $0 = $BASH_SOURCE ]]; then
  echo "Error: $0 (Chief Library Pre) must be sourced; not executed interactively."
  exit 1
fi

# CHIEF DEFAULTS
###################################################################################################################

CHIEF_VERSION="v1.3.7 (2025-Jun-5)"
CHIEF_REPO="https://github.com/randyoyarzabal/chief"
CHIEF_WEBSITE="https://chief.reonetlabs.us"
CHIEF_AUTHOR="Randy E. Oyarzabal"
CHIEF_LIBRARY="${CHIEF_PATH}/libs/core/chief_library.sh"
CHIEF_GIT_TOOLS="${CHIEF_PATH}/libs/extras/git"

CHIEF_PLUGINS_CORE="${CHIEF_PATH}/libs/core/plugins"
CHIEF_PLUGIN_SUFFIX="_chief-plugin.sh"
CHIEF_DEFAULT_USER_PLUGIN_TEMPLATE="${CHIEF_PATH}/templates/chief_user_plugin_template.sh"
CHIEF_CFG_LOAD_NON_ALIAS=true # Load non-alias functions from plugins by default.

# CORE HELPER FUNCTIONS
###################################################################################################################

# Detect platform
uname_out="$(uname -s)"
case "${uname_out}" in
  Linux*) PLATFORM='Linux' ;;
  Darwin*) PLATFORM='MacOS' ;;
  CYGWIN*) PLATFORM='Cygwin' ;;
  MINGW*) PLATFORM='MinGw' ;;
  *) PLATFORM="UNKNOWN:${uname_out}" ;;
esac

# Echo string to screen if CHIEF_CFG_VERBOSE is true.
function __print() {
  # Usage: __print <string>
  if ${CHIEF_CFG_VERBOSE} || [[ "${2}" == '--force' ]]; then
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
        __load_library --force  
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

# This is a helper function to load a file as itself. But created to allow for future pre-processing
#  e.g. to apply alias to the file before loading it.
# Usage: __load_file <file> [<message>] 
function __load_file() {
  __apply_chief-alias ${1} # Apply alias if defined, then source the file.
}

# Apply the alias defined in CHIEF_ALIAS to the file passed.
#  Note: this only applied to any function/alias starting with "chief."
# Usage: __apply_chief-alias <library file>
function __apply_chief-alias() {
  #Set default values
  local tmp_lib=$(__get_tmpfile) # Temporary library file.
  local source_file=${1} # File to source

  if [[ -n ${CHIEF_ALIAS} ]]; then
    # Substitute chief.* with alias if requested
    local alias=$(__lower ${CHIEF_ALIAS})
    
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

# Source the library/plugin module passed.
function __load_plugins_dir() {
  # Usage: __load_plugins_dir <plug-in module> (user/core)
  __print "Loading Chief ${1}-plugins..." "$2"

  local plugin_file
  local plugin_name
  local plugin_switch
  local dir_path
  local load_flag

  plugin_switch="CHIEF_$(__upper ${1})_PLUGINS"
  load_flag=false # Default to false, unless plugin switch is defined.
  if [[ $1 == 'core' ]]; then
    dir_path=${CHIEF_PLUGINS_CORE}
    # If plugin var exists, AND is enabled, load core plugin files into memory
    # Evaluate string as a variable, '!' is a dereference for the dynamic variable name
    if [[ -n ${!plugin_switch} ]] && ${!plugin_switch}; then
      load_flag=true
    fi
  elif [[ $1 == 'user' ]]; then
    dir_path=${CHIEF_USER_PLUGINS}
    if [[ -n ${!plugin_switch} ]]; then
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
      mapfile -t sorted_plugins < <(printf "%s\n" "${plugins[@]}" | sort)

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

# Generate a list of user plugins as a string separated by '|'.
#   This is used to display the list of plugins in the banner, hints, and chief.plugin help text.
#   This process is meant to run in addition to the __load_plugins_dir function because it accounts for 
#   new user plugins that are created once the terminal is already started.
# Usage: __get_plugins
__get_plugins() {
  local plugin_file
  local plugin_name
  local dir_path
  local plugin_list_str

  dir_path=${CHIEF_USER_PLUGINS}

  local plugins=() # Array to hold plugin names
  local sorted_plugins=() # Array to hold sorted plugin names

  if [[ -d ${dir_path} ]]; then
    for plugin in "${dir_path}/"*"${CHIEF_PLUGIN_SUFFIX}"; do
      plugins+=("${plugin}") # Collect plugin names
    done

    # Sort the plugins alphabetically
    mapfile -t sorted_plugins < <(printf "%s\n" "${plugins[@]}" | sort)

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
# Usage: __edit_plugin <user plug-in name>
function __edit_user_plugin() {
  local plugin_name
  local plugin_file

  # Check if user plugins are enabled.
  if [[ -z ${CHIEF_USER_PLUGINS} ]]; then
    echo "Chief user plugins are not enabled."
    return
  fi

  plugin_name=$(__lower ${1})
  plugin_file="${CHIEF_USER_PLUGINS}/${plugin_name}${CHIEF_PLUGIN_SUFFIX}"

  # Check if the plugin file exists, if not, prompt to create it.
  if [[ -f ${plugin_file} ]]; then
    __edit_file ${plugin_file}
  else
    echo "Chief plugin: ${plugin_name} plugin file does not exist."
    response=$(chief.etc_ask_yes_or_no "Create it?")
    if [[ $response == 'no' ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Plugin file not created.${CHIEF_NO_COLOR}"
      return 1
    fi

    # Get the user plugin template file
    if [[ -z ${CHIEF_CFG_USER_PLUGIN_TEMPLATE} ]] || [[ ! -f ${CHIEF_CFG_USER_PLUGIN_TEMPLATE} ]]; then
      echo -e "${CHIEF_COLOR_RED}Chief user plugin template not defined or does not exist. Using default template.${CHIEF_NO_COLOR}"
      CHIEF_CFG_USER_PLUGIN_TEMPLATE=${CHIEF_DEFAULT_USER_PLUGIN_TEMPLATE}
    fi

    # Create the user plugins directory if it does not exist.
    if [[ ! -d ${CHIEF_USER_PLUGINS} ]]; then
      mkdir -p ${CHIEF_USER_PLUGINS} || {
        echo -e "${CHIEF_COLOR_RED}Error: Unable to create directory '${CHIEF_USER_PLUGINS}'.${CHIEF_NO_COLOR}"
        return 1
      }
    fi

    # Copy the template to the plugin file
    cp ${CHIEF_CFG_USER_PLUGIN_TEMPLATE} ${plugin_file} || {
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

# Load/source Chief library
function __load_library() {
  source ${CHIEF_PATH}/libs/core/chief_library_core.sh
  __load_file ${CHIEF_LIBRARY} 

  # Usage: __load_library
  __load_file ${CHIEF_CONFIG}

  # Set a default alias if none defined.
  if [[ -n ${CHIEF_ALIAS} ]]; then
    __print "Chief is aliased as ${CHIEF_ALIAS}."
  fi

  __load_plugins_dir 'core' "$1"
  __load_plugins_dir 'user' "$1"

  __print "Chief BASH library/environment (re)loaded." "$1"
}

# Display Chief banner
function __chief.banner {
  echo -e "${CHIEF_COLOR_YELLOW}        __    _      ____${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}  _____/ /_  (_)__  / __/${CHIEF_NO_COLOR}"
  if [[ -n $CHIEF_ALIAS ]]; then
  echo -e "${CHIEF_COLOR_YELLOW} / ___/ __ \/ / _ \/ /_  alias: ${CHIEF_COLOR_CYAN}${CHIEF_ALIAS}${CHIEF_NO_COLOR}"
  else
  echo -e "${CHIEF_COLOR_YELLOW} / ___/ __ \/ / _ \/ /_  ${CHIEF_NO_COLOR}"
  fi
  echo -e "${CHIEF_COLOR_YELLOW}/ /__/ / / / /  __/ __/ ${CHIEF_COLOR_CYAN}${CHIEF_WEBSITE}${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}\___/_/ /_/_/\___/_/ ${CHIEF_NO_COLOR}${CHIEF_VERSION} [${PLATFORM}]"
}

# Display "hints" text and dynamically display alias if necessary.
function __chief.hints_text() {
  # Usage: __chief.hints_text
  if ${CHIEF_CFG_HINTS}; then
    echo -e "${CHIEF_COLOR_GREEN}chief.[tab]${CHIEF_NO_COLOR} for available commands | ${CHIEF_COLOR_GREEN}chief.update${CHIEF_NO_COLOR} to update Chief."
    local plugin_list=$(__get_plugins)
    if [[ -z ${plugin_list} ]]; then
      echo -e "${CHIEF_COLOR_GREEN}User plugins loaded: ${CHIEF_COLOR_CYAN}${plugin_list}${CHIEF_NO_COLOR}"
    fi
    echo -e "${CHIEF_COLOR_YELLOW}Chief tool hints:${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_GREEN}chief.<command> -?${CHIEF_NO_COLOR} to display help text."
    echo -e "${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR} to enable/disable hints, banner, enable prompt customizations etc."
    echo -e "${CHIEF_COLOR_GREEN}chief.reload${CHIEF_NO_COLOR} to reload Chief core libs and plugins."
    echo -e "${CHIEF_COLOR_GREEN}chief.plugin${CHIEF_NO_COLOR} to edit the default plugin."
    echo -e "${CHIEF_COLOR_GREEN}chief.plugin [plugin_name]${CHIEF_NO_COLOR} to create/edit a specific user plugin."
    echo -e "${CHIEF_COLOR_GREEN}chief.bash_profile${CHIEF_NO_COLOR} and ${CHIEF_COLOR_GREEN}chief.bashrc${CHIEF_NO_COLOR} to edit and autoload accordingly."
    echo -e "${CHIEF_COLOR_CYAN}**Disable this hint by setting ${CHIEF_COLOR_GREEN}CHIEF_CFG_HINTS=false${CHIEF_NO_COLOR} in ${CHIEF_COLOR_GREEN}chief.config${CHIEF_NO_COLOR}"
  fi
}

# Display Chief version info.
function __chief.info() {
  # Usage: __chief.info
  __chief.banner
  echo -e "by: ${CHIEF_AUTHOR}"
  echo ''
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
    __print "Loading SSH keys from: ${CHIEF_RSA_KEYS_PATH}..." "$1"

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

  # Load all keys.  Skip authorized_keys, environment, and known_hosts.
  for rsa_key in ${CHIEF_RSA_KEYS_PATH}/*.rsa; do
    if ${CHIEF_CFG_VERBOSE} || [[ "${1}" == '--force' ]]; then
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

  if ${CHIEF_CFG_COLORED_PROMPT}; then
    __git_ps1 "${ve_name}${CHIEF_COLOR_MAGENTA}\u${CHIEF_NO_COLOR}@${CHIEF_COLOR_GREEN}\h${CHIEF_NO_COLOR}:${CHIEF_COLOR_YELLOW}${prompt_tag}${CHIEF_NO_COLOR}" "\\\$ "
  else
    __git_ps1 "${ve_name}\u@\h:${prompt_tag}" "\\\$ "
  fi
}

function __check_for_updates (){
  chief.root
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
###################################################################################################################

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