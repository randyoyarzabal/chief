#!/usr/bin/env bash
###################################################################################################################
# WARNING: This file is not meant to be edited/configured directly unless you know what you are doing.
#   All settings and commands are done via the chief.* commands
###################################################################################################################

CHIEF_VERSION="v1.2 (2025-Jun-3)"
CHIEF_REPO="https://github.com/randyoyarzabal/chief"
CHIEF_WEBSITE="https://chief.reonetlabs.us"
CHIEF_AUTHOR="Randy E. Oyarzabal"

# MAIN BEGINS HERE

# shopt -s expand_aliases

# Block interactive execution
if [[ $0 = $BASH_SOURCE ]]; then
  echo "Error: $0 (Chief) must be sourced; not executed interactively."
  exit 1
fi

# Check for prerequisite environment variable
if [[ -z ${CHIEF_PATH} ]] || [[ -z ${CHIEF_CONFIG} ]]; then
  echo 'Error: $CHIEF_PATH and/or $CHIEF_CONFIG environment var must be set before using Chief.'
  return 1
fi

# Load prerequisite library
source ${CHIEF_PATH}/libs/core/chief_library_pre.sh

# Core library loading definition
__load_library 

if ${CHIEF_CFG_BANNER}; then
  __chief.banner
  __chief.try_text
fi

if ${CHIEF_CHECK_UPDATES}; then
  chief.update
fi

# Load RSA/SSH keys if directory is defined
if [[ ! -z ${CHIEF_RSA_KEYS_PATH} && ${PLATFORM} == "MacOS" ]] || [[ ! -z ${CHIEF_RSA_KEYS_PATH} && ${PLATFORM} == "Linux" ]]; then
  chief.etc_spinner "Loading SSH keys..." "__load_ssh_keys" tmp_out
  echo -e "${tmp_out}"
fi

# Apply colored LS
if ${CHIEF_CFG_COLORED_LS}; then
  __print "Applying ls colors..."
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

# Apply either a short (current dir) prompt or full (full path) one
if ${CHIEF_CFG_CWD_ONLY_PROMPT}; then
  prompt_tag='\W'
else
  prompt_tag='\w'
fi

# Apply default prompt
if ${CHIEF_CFG_COLORED_PROMPT}; then
  export PS1="${CHIEF_COLOR_CYAN}\u${CHIEF_NO_COLOR}@${CHIEF_COLOR_GREEN}\h${NC}:${CHIEF_COLOR_YELLOW}${prompt_tag}${CHIEF_NO_COLOR}\$ "
# else
#   export PS1="\u@\h:${prompt_tag}$ "
fi

# Apply Git Tools (completion/prompt)
if ${CHIEF_CFG_TOOL_GIT}; then
  __print "Applying git prompt/completion..."

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
    __print "Applying colored git prompt..."
  else
    __print "Applying default non-colored git prompt..."
  fi
  PROMPT_COMMAND='__build_git_prompt'
fi
