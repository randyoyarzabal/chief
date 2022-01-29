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

CHIEF_LIBRARY="${CHIEF_PATH}/libs/core/chief_library.sh"
CHIEF_GIT_TOOLS="${CHIEF_PATH}/libs/extras/git"
CHIEF_PLUGINS="${CHIEF_PATH}/libs/plugins"
CHIEF_PLUGINS_CORE="${CHIEF_PLUGINS}"

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
  if ${CHIEF_CFG_VERBOSE}; then
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
      source ${file}
    else
      if [[ $3 == 'reload' ]]; then
        __load_library
      fi
    fi

    if [[ -z ${2} ]]; then
      echo "${file##*/} file was modified, therefore, reloaded."
    else
      echo "${2} was modified, therefore, reloaded."
    fi
  fi
}

# Apply the alias defined in CHIEF_ALIAS to the file passed.
#  Note: this only applied to any function/alias starting with "chief."
function __apply_chief-alias() {
  # Usage: __apply_chief-alias <library file>
  # Set default values
  local tmp_lib=$(__get_tmpfile) # Temporary library file.

  if [[ ${CHIEF_ALIAS} != "CHIEF" ]]; then
    # Substitute chief.* with alias if requested
    local alias=$(__lower ${CHIEF_ALIAS})

    # Apply alias to functions
    sed "s/function chief./function $alias./g" ${1} >${tmp_lib} # Replace into a temp file.

    # Apply alias to aliases
    if [[ ${PLATFORM} == "MacOS" ]]; then
      sed -i "" "s/alias chief./alias $alias./g" ${tmp_lib} # Replace inline.
    else
      sed -i "s/alias chief./alias $alias./g" ${tmp_lib} # Replace inline.
    fi

    source ${tmp_lib} # Source the library as its alias

    # Destroy / delete the temp library
    rm -rf ${tmp_lib}
  else
    # Source the library requested even if no alias defined.
    source "${1}"
  fi

  # Load chief.* functions as well if requested
  if ! ${CHIEF_CFG_ALIAS_ONLY}; then
    source ${1} # Source the library as itself
  fi
}

# Source the library/plugin module passed.
function __load_plugins_dir() {
  # Usage: __load_plugins <plug-in directory>
  __print "Loading ${CHIEF_ALIAS} ${1}-plugins..."

  local full_path
  local plugin_file
  local plugin_name
  local plugin_switch
  local dir_path
  local load_flag

  plugin_switch="CHIEF_$(__upper ${1})_PLUGINS"

  if [[ $1 == 'core' ]]; then
    dir_path=${CHIEF_PLUGINS_CORE}

    # If plugin var exists, AND is enabled, load plugin file into memory
    # Evaluate string as a variable, '!' is a dereference for the dynamic variable name
    if [[ ! -z ${!plugin_switch} ]] && ${!plugin_switch}; then
      load_flag=true
    fi
  else
    dir_path=${CHIEF_CONTRIB_PLUGINS}

    # If plugin var exists, load plugin file into memory
    # Evaluate string as a variable, '!' is a dereference for the dynamic variable name
    if [[ ! -z ${!plugin_switch} ]]; then
      load_flag=false
    fi
  fi

  if [[ ! ${load_flag} ]]; then
    __print "   plugins: ${1} not enabled."
    return
  fi

  # Check for existence of plugin folder requested
  if [[ -d ${dir_path} ]]; then
    for plugin in "${dir_path}"/*_chief-plugin.sh; do
      full_path=${plugin}
      plugin_file=${plugin##*/}
      plugin_name=${plugin_file%%_*}

      if [[ -f ${full_path} ]]; then
        # TODO: Check plugin prerequisites before loading.
        __apply_chief-alias "${full_path}" # Apply alias and source the plugin
        __print "   plugin: ${plugin_name} loaded."
      fi
    done
  else
    __print "   $1 plugins directory does not exist."
  fi
}

# Source the library/plugin module passed.
function __load_plugins() {
  # Usage: __load_plugins <plug-in module> (user/contrib/core)
  __print "Loading ${CHIEF_ALIAS} ${1}-plugins..."

  local plugin_variable
  local plugin_file
  local plugin_name
  local plugin_prefix

  plugin_prefix="CHIEF_$(__upper ${1})_PLUGIN_"

  # Find all plugin declarations in config file
  for bash_var in $(cat ${CHIEF_CONFIG} | grep -E "^$plugin_prefix"); do
    plugin_variable=$(echo $bash_var | cut -d'=' -f 1)
    plugin_value=$(echo $bash_var | cut -d'=' -f 2 | tr -d '"')
    plugin_name=$(__lower $(echo $plugin_variable | cut -d'_' -f 4))

    # Since the values could contain variables themselves, expand it.
    # TODO: Find alternative to "eval"
    plugin_file=$(eval echo ${plugin_value})

    if [[ -f ${plugin_file} ]]; then
      # TODO: Check plugin prerequisites before loading.
      __apply_chief-alias ${plugin_file} # Apply alias and source the plugin
      __print "   plugin: ${plugin_name} loaded."
    else
      __print "   plugin: ${plugin_name} plugin file does not exist."
    fi
  done
}

# Edit a plugin file and reload into memory if changed.
#   Note, will only succeed if plug-in is enabled in settings.
function __edit_user_plugin() {
  # Usage: __edit_plugin <user plug-in name>

  local plugin_variable
  local plugin_file
  local plugin_name
  local bash_var
  local plugin_found

  plugin_variable="CHIEF_USER_PLUGIN_$(__upper ${1})"

  # Find all plugin declarations in config file
  bash_var=$(cat ${CHIEF_CONFIG} | grep -E "^$plugin_variable=")

  if [[ -z ${bash_var} ]]; then
    echo "${CHIEF_ALIAS} $1-plugin is not valid."
    return
  fi

  plugin_value=$(echo $bash_var | cut -d'=' -f 2 | tr -d '"')
  plugin_name=$(__lower $(echo $plugin_variable | cut -d'_' -f 4))
  plugin_file=$(eval echo ${plugin_value})

  if [[ -f ${plugin_file} ]]; then
    __edit_file ${plugin_file}
  else
    __print "   plugin: ${plugin_name} plugin file does not exist."
  fi
}

# Load/source Chief library
function __load_library() {
  # Usage: __load_library
  source ${CHIEF_CONFIG}

  # Set a default alias if none defined.
  if [[ -z ${CHIEF_ALIAS} ]]; then
    CHIEF_ALIAS='CHIEF' # Use this by default
  else
    CHIEF_ALIAS=$(__upper ${CHIEF_ALIAS}) # Capitalize if not already.
    if [[ ${CHIEF_ALIAS} != "CHIEF" ]]; then
      __print "Chief is aliased as ${CHIEF_ALIAS}."
    fi
  fi

  # These implicitly reloads the library files.
  __print "Loading core ${CHIEF_ALIAS} library..."
  __apply_chief-alias ${CHIEF_LIBRARY}  # Load chief_library.sh
  CHIEF_ALIAS=$(__upper ${CHIEF_ALIAS}) # Capitalize again, because re-source may have overwrote it.

  __load_plugins_dir 'core'
  __load_plugins_dir 'contrib'
  __load_plugins 'user'

  __print "${CHIEF_ALIAS} BASH library/environment (re)loaded."
}

# Display "try" text and dynamically display alias if necessary.
function __try_text() {
  # Usage: __try_text
  local cmd_alias=$(__lower ${CHIEF_ALIAS})
  if [[ ! -z ${CHIEF_ALIAS} ]] && ! ${CHIEF_CFG_ALIAS_ONLY}; then
    echo -e "Try ${CHIEF_COLOR_GREEN}chief.[tab]${CHIEF_NO_COLOR} or ${CHIEF_COLOR_GREEN}${cmd_alias}.[tab]${CHIEF_NO_COLOR} to see available commands."
  elif [[ ! -z ${CHIEF_ALIAS} ]] && ${CHIEF_CFG_ALIAS_ONLY}; then
    echo -e "Try ${CHIEF_COLOR_GREEN}${cmd_alias}.[tab]${CHIEF_NO_COLOR} to see available commands."
  else
    echo -e "Try ${CHIEF_COLOR_GREEN}chief.[tab]${CHIEF_NO_COLOR} to see available commands."
  fi
}

# Display Chief version info.
function __chief.info() {
  # Usage: __chief.info
  echo -e "${CHIEF_TOOL_NAME} ${CHIEF_COLOR_YELLOW}${CHIEF_TOOL_VERSION}${CHIEF_NO_COLOR} (${PLATFORM})"
  echo -e "by ${CHIEF_TOOL_AUTHOR}"
  echo -e "${CHIEF_TOOL_REPO}"
  echo ''
  __try_text
  echo ''
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
  if ${CHIEF_CHECK_UPDATES}; then
    # Check for updates and print notification here.
    chief.root
    HEADHASH=$(git rev-parse HEAD)
    UPSTREAMHASH=$(git rev-parse master@{upstream})

    # Only compare local/remote changes if no local changes exist.
    if [[ -n $(git status -s) ]] && [[ "$HEADHASH" != "$UPSTREAMHASH" ]]; then
      echo -e "\n${CHIEF_COLOR_GREEN}**Chief code update available**${CHIEF_NO_COLOR} run chief.root; chief.git_update."
    fi
    cd - > /dev/null
  fi
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
