#!/usr/bin/env bash
# Core Chief user functionality such as settings and various helper functions.

###################################################################################################################
# WARNING: This file is not meant to be edited/configured/used directly unless you know what you are doing.
#   All settings and commands are available via the chief.* commands when "chief.sh" is sourced.
###################################################################################################################

# Block interactive execution
if [[ $0 = $BASH_SOURCE ]]; then
  echo "Error: $0 (Chief Library) must be sourced; not executed interactively."
  exit 1
fi

# Load config file.
source ${CHIEF_CONFIG}

# MAIN FUNCTIONS
###################################################################################################################

alias chief.ver='__chief.info'

function chief.root() {
  local USAGE="Usage: $FUNCNAME

Change directory (cd) into the $CHIEF_ALIAS utility root installation directory."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  cd ${CHIEF_PATH}
}

function chief.config() {
  local USAGE="Usage: $FUNCNAME

Edit the $CHIEF_ALIAS utility configuration."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  # Third parameter is to reload entire library if config is modified.
  __edit_file ${CHIEF_CONFIG} "Chief Configuration" "reload"
}

function chief.plugins.root() {
  local USAGE="Usage: $FUNCNAME

Change directory (cd) into the $CHIEF_ALIAS utility plugins directory root."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  cd ${CHIEF_USER_PLUGINS}
}

function chief.plugin() {
  # Dynamically read plug-ins
  local plugin_variable
  local plugin_name
  local var_arg

  # Find all plugin declarations in config file
  for bash_var in $(cat ${CHIEF_CONFIG} | grep -E "^CHIEF_USER_PLUGIN_"); do
    plugin_variable=$(echo $bash_var | cut -d'=' -f 1)
    plugin_name=$(__lower $(echo $plugin_variable | cut -d'_' -f 4))
    var_arg="$plugin_name|$var_arg"
  done

  var_arg=$(echo ${var_arg%?}) # Trim last character

  local USAGE="Usage: $FUNCNAME [$var_arg]

Edit a user $CHIEF_ALIAS plugin library.  If no parameter is passed, default plug-in will be edited."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  if [[ -z $1 ]]; then
    __edit_user_plugin default
  else
    __edit_user_plugin $1
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

function chief.reload_library() {
  local USAGE="Usage: $FUNCNAME

Reload the $CHIEF_ALIAS utility library/environment."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  __load_library
}
