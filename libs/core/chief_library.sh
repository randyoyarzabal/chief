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
###################################################################################################################
# WARNING: This file is not meant to be edited/configured/used directly unless you know what you are doing.
#   All settings and commands are available via the chief.* commands when "chief.sh" is sourced.
###################################################################################################################

# Block interactive execution
if [[ $0 = $BASH_SOURCE ]]; then
  echo "Error: $0 (Chief Library) must be sourced; not executed interactively."
  exit 1
fi

# MAIN FUNCTIONS
###################################################################################################################

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

Update and reload the remote Chief plugins.
This command will update all plugins to the latest version available in the remote repository."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi
  __load_remote_plugins "--verbose" "--force" && {
    echo -e "${CHIEF_COLOR_GREEN}Updated all plugins to the latest version.${CHIEF_NO_COLOR}"
  } || {
    echo -e "${CHIEF_COLOR_RED}Error: Failed to update plugins.${CHIEF_NO_COLOR}"
  }
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
    response=$(chief.etc_ask_yes_or_no "Updates are available, update now?")
    if [[ $response == 'yes' ]]; then
      ${CHIEF_PATH}
      chief.git_update -p
      chief.reload
      cd - > /dev/null 2>&1
      echo -e "${CHIEF_COLOR_GREEN}Updated Chief to [${CHIEF_VERSION}].${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_YELLOW}Update skipped.${CHIEF_NO_COLOR}"
    fi
  else
    echo -e "${CHIEF_COLOR_YELLOW}No Chief updates found.${CHIEF_NO_COLOR}"
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
