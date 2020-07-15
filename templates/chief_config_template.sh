#!/usr/bin/env bash
# CHIEF BASH LIBRARY CONFIGURATION
####################################

# Configure items to suit. For all variables:
#   Set values to: true, to enable Or false, to disable
#   or
#   Comment (prefix with #) to disable.
#   Un-comment (remove #) to enable.

# PLUG-INS LIBRARY PATH CONFIGURATION
####################################

#  ** All plug-ins must be defined with their respective absolute paths. **
#  BASH environment variables are allowed in paths e.g. ${HOME}

# CORE PLUGINS LIBRARY SWITCHES
# Located in: "${CHIEF_PATH}/libs/plugins/core"
CHIEF_CORE_PLUGINS=true

# CONTRIBUTED LIBRARY PLUGINS
# This is a user-defined directory where ALL files will be loaded.
# ** All plug-in files in directory must end in "*_chief-plugin.sh" **
# CHIEF_CONTRIB_PLUGINS=""

# USER LIBRARY PLUGINS
# (Plug-ins you can edit with chief.plugin <plug-in> command.)
# ** All user plug-ins variables names must be prefixed with 'CHIEF_USER_PLUGIN_' **
# ** CHIEF_USER_PLUGIN_DEFAULT is required and must be defined to hold the default user library.' **
CHIEF_USER_PLUGIN_DEFAULT="$HOME/dev/chief_plugins/default_chief-plugin.sh"
#CHIEF_USER_PLUGIN_SAMPLE1=""
#CHIEF_USER_PLUGIN_SAMPLE2=""

# TOOLS CONFIGURATION
####################################

# CORE TOOLS
CHIEF_CFG_COLORED_LS=true

# Change this to false, if you prefer the full path in your prompt.
CHIEF_CFG_CWD_ONLY_PROMPT=false

CHIEF_CFG_COLORED_PROMPT=true
CHIEF_CFG_BANNER=true
CHIEF_CFG_VERBOSE=true

# Load Git Tools (prompt and command completion)
CHIEF_CFG_TOOL_GIT=true

# Command alias for Chief
# For example, "reo".  Then all chief.* commands will be available as reo.*
#CHIEF_ALIAS="reo"

# Set this to false for duplicate "chief.*" functions as well.
#CHIEF_CFG_ALIAS_ONLY=false

# Load private SSH keys into memory. Note: Private keys need to end in ".rsa" with the exception
#   of the standard id_rsa private key.  Create a symlink if you have to.
# For example, you may have multiple keys in your ~/.ssh dir.
# Chief will automatically enable auto-load and auto-cleanup of ssh-agent.
CHIEF_RSA_KEYS_PATH="$HOME/.ssh"
