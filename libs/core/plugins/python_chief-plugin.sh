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

# Chief Plugin File: python_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0
# Functions and aliases related to Python.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

function chief.python_ve_dep() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Install all packages from requirements.txt in the current directory.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --ignore_version, -i    Install latest versions (ignore pinned versions)
  -?                      Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Upgrades pip, setuptools, and wheel first
- Handles both pinned and unpinned requirements
- Works in virtual environments and system Python

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- requirements.txt file in current directory
- Python and pip installed

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME           # Install exact versions from requirements.txt
  $FUNCNAME -i        # Install latest versions of all packages
"

  if [[ $1 == '-?' ]]; then
    echo -e "${USAGE}"
    return
  fi
  
  if [[ ! -f "requirements.txt" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} requirements.txt not found in current directory"
    return 1
  fi

  python -m pip install --upgrade pip setuptools wheel

  if [[ $1 == '--ignore_version' ]] || [[ $1 == '-i' ]]; then
    cat requirements.txt | cut -d'=' -f 1 | xargs pip install --upgrade
  else
    pip install -r requirements.txt
  fi
}

# Deprecated, use venv module.
########################################################

#function chief.python_create_ve {
#  local USAGE="Usage: $FUNCNAME <name> <python path>
#
#Create a Python virtual environment.
#    Example: $FUNCNAME django_dev /usr/bin/python3
#"
#
#  if [[ -z $2 ]] || [[ $1 == '-?' ]]; then
#    echo "${USAGE}"
#    return
#  fi
#
#  local VE_CHECK=$(type mkvirtualenv 2>&1)
#
#  if [[ ! ${VE_CHECK} == *"not found"* ]]; then
#    local python_bin="$2"
#    mkvirtualenv $1 --python=${python_bin}
#  else
#    echo "virtualenv and virtualenvwrapper must be installed to use this function."
#  fi
#}
#
#function chief.python_start_ve {
#  local USAGE="Usage: $FUNCNAME <ve name>
#
#Start a virtual environment if not already started.
#This is handy for use in functions when you'd like to dynamically start a VE."
#
#  if [[ -z $1 ]] || [[ $1 == '-?' ]]; then
#    echo "${USAGE}"
#    return
#  fi
#
#  if [[ -z ${VIRTUAL_ENV} ]]; then
#    workon $1
#  fi
#}
#
#function chief.python_stop_ve {
#  local USAGE="Usage: $FUNCNAME <ve name>
#
#Stop a virtual environment if not already stopped.
#This is handy for use in functions when you'd like to dynamically start a VE."
#
#  if [[ -z $1 ]] || [[ $1 == '-?' ]]; then
#    echo "${USAGE}"
#    return
#  fi
#
#  # Don't assume there was even a VE to begin with.
#  if [[ ! -z ${VIRTUAL_ENV} ]]; then
#    deactivate
#  fi
#}
#
## For backwards compatibility
#alias chief.start_ve='chief.python_start_ve'
#alias chief.stop_ve='chief.python_stop_ve'
