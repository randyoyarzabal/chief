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

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief) must be sourced; not executed interactively."
  echo 'To use Chief, source it in your shell or add it to your shell configuration file (e.g. ~/.bashrc).'
  echo 'Be sure that the environment variables $CHIEF_PATH and $CHIEF_CONFIG are set before sourcing.'
  echo "To use the libraries only, use: source ${BASH_SOURCE[0]} --lib-only"
  exit 1
fi

# Check for prerequisite environment variable
if [[ -z ${CHIEF_PATH} ]] || [[ -z ${CHIEF_CONFIG} ]]; then
  echo 'Error: $CHIEF_PATH and/or $CHIEF_CONFIG environment var must be set before using Chief.'
  
  exit 1
fi

# Load the Chief configuration file and core library.
CHIEF_GIT_TOOLS="${CHIEF_PATH}/libs/extras/git"
CHIEF_LIBRARY="${CHIEF_PATH}/libs/core/chief_library.sh"
source ${CHIEF_CONFIG}
source ${CHIEF_LIBRARY}

########################################################################
# Main script starts here
########################################################################

# Allow the script to be called with --lib-only to load only the libraries
if [[ $1 == "--lib-only" ]]; then
  # For lib-only mode, only the core library functions are loaded (lines 53-54)
  # Skip plugin loading to avoid hangs in CI/testing environments
  return 0
fi

# Load core libraries (including plugins) for full interactive mode
__chief_load_library

# Load RSA/SSH keys if directory is defined
if [[ ! -z ${CHIEF_CFG_SSH_KEYS_PATH} ]] && ([[ ${PLATFORM} == "MacOS" ]] || [[ $(uname) == "Linux" ]]); then
  chief.etc_spinner "Loading SSH keys..." "__chief_load_ssh_keys" tmp_out
  echo -e "${tmp_out}"
fi

# Load banner and hints
if ${CHIEF_CFG_BANNER}; then
  __chief.banner
  __chief.hints_text --no-tracking
fi

# Check for updates
if ${CHIEF_CFG_AUTOCHECK_UPDATES}; then
  chief.update
fi

# Apply colored LS
if ${CHIEF_CFG_COLORED_LS}; then
  __chief_print "Applying ls colors..."
  if [[ ${PLATFORM} == "MacOS" ]]; then
    export CLICOLOR=1
    export LSCOLORS=ExFxBxDxCxegedabagacad
    alias ls='ls -GFh'
  else
    alias ls='ls --color=auto'
  fi
else
  if [[ ! ${PLATFORM} == "MacOS" ]]; then
    alias ls='ls --color=never'
  fi
fi

# Apply prompt configuration
if ${CHIEF_CFG_PROMPT}; then
  # Apply either a short (current dir) prompt or full (full path) one
  if ${CHIEF_CFG_SHORT_PATH}; then
    prompt_tag='\W'
  else
    prompt_tag='\w'
  fi

  __chief_print "Applying default prompt..."
  
  # If CHIEF_HOST is set, use it in the prompt
  if [[ -n ${CHIEF_HOST} ]]; then
    host="${CHIEF_HOST}"
  else
    host=$(hostname -s)  # Short hostname
  fi

  export PS1="\u@${host}:${prompt_tag}$ "

  if ${CHIEF_CFG_COLORED_PROMPT}; then
    export PS1="${CHIEF_COLOR_CYAN}\u${CHIEF_NO_COLOR}@${CHIEF_COLOR_GREEN}${host}${NC}:${CHIEF_COLOR_YELLOW}${prompt_tag}${CHIEF_NO_COLOR}\$ "
  fi

  # Apply Git Tools (completion/prompt)
  if ${CHIEF_CFG_GIT_PROMPT}; then
    __chief_print "Applying git prompt/completion..."

    # Variables and their respective output: https://blog.backslasher.net/git-prompt-variables.html
    export GIT_PS1_SHOWDIRTYSTATE=true     # '*'=unstaged, '+'=staged
    export GIT_PS1_SHOWSTASHSTATE=true     # '$'=stashed
    export GIT_PS1_SHOWUNTRACKEDFILES=true # '%'=untracked
    export GIT_PS1_SHOWUPSTREAM="auto"
    export GIT_PS1_STATESEPARATOR='|'

    source ${CHIEF_GIT_TOOLS}/git-prompt.sh
    source ${CHIEF_GIT_TOOLS}/git-completion.bash

    if ${CHIEF_CFG_COLORED_PROMPT}; then
      export GIT_PS1_SHOWCOLORHINTS=true
      __chief_print "Applying colored git prompt..."
    else
      __chief_print "Applying default non-colored git prompt..."
    fi
    PROMPT_COMMAND='__chief_build_git_prompt'
  fi
fi
