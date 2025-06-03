#!/usr/bin/env bash
###################################################################################################################
# WARNING: This file is not meant to be edited/configured directly unless you know what you are doing.
#   All settings and commands are done via the chief.* commands
###################################################################################################################

CHIEF_VERSION="v1.1 (2025-Jun-3)"
CHIEF_REPO="https://github.com/randyoyarzabal/chief"
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

# Load RSA/SSH keys if directory is defined
if [[ ! -z ${CHIEF_RSA_KEYS_PATH} && ${PLATFORM} == "MacOS" ]] || [[ ! -z ${CHIEF_RSA_KEYS_PATH} && ${PLATFORM} == "Linux" ]]; then
  __print "Loading SSH keys from: ${CHIEF_RSA_KEYS_PATH}..."

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
    if ${CHIEF_CFG_VERBOSE}; then
      ${load} ${rsa_key}
    else
      ${load} ${rsa_key} >/dev/null 2>&1
    fi
  done

  # Load key from standard location
  # if [[ -e ~/.ssh/id_rsa ]]; then
  #   if ${CHIEF_CFG_VERBOSE}; then
  #     ${load} ~/.ssh/id_rsa
  #   else
  #     ${load} ~/.ssh/id_rsa >/dev/null 2>&1
  #   fi
  # fi
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

CHIEF_TITLE="${CHIEF_COLOR_CYAN}Chief${CHIEF_NO_COLOR} BASH Tools"

if ${CHIEF_CFG_BANNER}; then
  echo -e "${CHIEF_TITLE} ${CHIEF_COLOR_YELLOW}${CHIEF_VERSION}${CHIEF_NO_COLOR} (${PLATFORM})"
  __try_text
fi

if ${CHIEF_CHECK_UPDATES}; then
  chief.etc_spinner "Checking for updates..." "__check_for_updates" tmp_out
  echo -e "${tmp_out}"
  if [[ ${tmp_out} == *"available"* ]]; then
    response=$(chief.etc_ask_yes_or_no "Or, update now?")
    if [[ $response == 'yes' ]]; then
      chief.root
      chief.git_update -p
      chief.reload_library
      cd - > /dev/null 2>&1
    fi
  fi
fi
