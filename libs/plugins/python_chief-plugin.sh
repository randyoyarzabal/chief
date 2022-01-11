#!/usr/bin/env bash
# Chief Plugin File: python_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0
# Functions and aliases related to Python.

function chief.python_ve_dep() {
  local USAGE="Usage: $FUNCNAME [--ignore_version | -i]

Install all packages within a given a requirements.txt in the current directory.

Optionally pass --ignore_version or -i to install the latest version of packages."

  if [[ $1 == '-?' ]]; then
    echo "${USAGE}"
    return
  fi

  python -m pip install --upgrade pip setuptools wheel

  if [[ $1 == '--ignore_version' ]] || [[ $1 == '-i' ]]; then
    cat requirements.txt | cut -d'=' -f 1 | xargs pip install --upgrade
  else
    pip install -r requirements.txt
  fi
}

function chief.python_create_ve {
  local USAGE="Usage: $FUNCNAME <name> <python path>

Create a Python virtual environment.
    Example: $FUNCNAME django_dev /usr/bin/python3
"

  if [[ -z $2 ]] || [[ $1 == '-?' ]]; then
    echo "${USAGE}"
    return
  fi

  local VE_CHECK=$(type mkvirtualenv 2>&1)

  if [[ ! ${VE_CHECK} == *"not found"* ]]; then
    local python_bin="$2"
    mkvirtualenv $1 --python=${python_bin}
  else
    echo "virtualenv and virtualenvwrapper must be installed to use this function."
  fi
}

function chief.python_start_ve {
  local USAGE="Usage: $FUNCNAME <ve name>

Start a virtual environment if not already started.
This is handy for use in functions when you'd like to dynamically start a VE."

  if [[ -z $1 ]] || [[ $1 == '-?' ]]; then
    echo "${USAGE}"
    return
  fi

  if [[ -z ${VIRTUAL_ENV} ]]; then
    workon $1
  fi
}

function chief.python_stop_ve {
  local USAGE="Usage: $FUNCNAME <ve name>

Stop a virtual environment if not already stopped.
This is handy for use in functions when you'd like to dynamically start a VE."

  if [[ -z $1 ]] || [[ $1 == '-?' ]]; then
    echo "${USAGE}"
    return
  fi

  # Don't assume there was even a VE to begin with.
  if [[ ! -z ${VIRTUAL_ENV} ]]; then
    deactivate
  fi
}

# For backwards compatibility
alias chief.start_ve='chief.python_start_ve'
alias chief.stop_ve='chief.python_stop_ve'
