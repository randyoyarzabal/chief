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

# If set to true, will display a banner at start-up.
# The banner will display the current version and the platform.
CHIEF_CFG_BANNER=true

# If set to true, will display output when plugins and SSH keys loaded at start-up.
CHIEF_CFG_VERBOSE=false

# If set to true, will display hints at start-up.
CHIEF_CFG_HINTS=true

# If set to true, will check and inform of updates available in GitHub at start-up.
# Note: if there are any local changes, Chief will not detect any remote updates as
# it assumes you are using a forked version. Also note, depending on GitHub's current stability,
# this could take annoyingly long, so feel free to disable if it bothers you.
CHIEF_CHECK_UPDATES=false

#  ** All plug-ins must be defined with their respective absolute paths. **
#  BASH environment variables are allowed in paths e.g. ${HOME}

# CORE PLUGINS LIBRARY SWITCHES
# Located in: "${CHIEF_PATH}/libs/plugins"
CHIEF_CORE_PLUGINS=true

# CONTRIBUTED LIBRARY PLUGINS
# This is a user-defined directory where ALL files will be loaded.
# ** All plug-in files in directory must end in "*_chief-plugin.sh" **
# CHIEF_CONTRIB_PLUGINS=""

# USER LIBRARY PLUGINS

# This is a user-defined directory where ALL files will be loaded.
# ** All plug-in files in directory must end in "*_chief-plugin.sh" **
# ** All user plug-ins variables names must be prefixed with 'CHIEF_USER_PLUGIN_' **
CHIEF_USER_PLUGINS="${HOME}"

# ** CHIEF_USER_PLUGIN_DEFAULT is required and must be defined to hold the default user library.' **
CHIEF_USER_PLUGIN_DEFAULT="$CHIEF_USER_PLUGINS/default_chief-plugin.sh"

# (Plug-ins you can edit with chief.plugin <plug-in> command.)
# Note the suffix of the variable matching the prefix of the file name
#CHIEF_USER_PLUGIN_SAMPLE1="CHIEF_USER_PLUGINS/sample1_chief-plugin.sh"
#CHIEF_USER_PLUGIN_SAMPLE1="CHIEF_USER_PLUGINS/sample2_chief-plugin.sh"

# You can then access/edit the plugin with:
# chief.plugin sample1
# chief.plugin sample2

# TOOLS CONFIGURATION
####################################

# If set to true, will use colored ls command.
CHIEF_CFG_COLORED_LS=false

# Prompt Customizations
CHIEF_CFG_COLORED_PROMPT=false

# Load Git Tools (prompt and command completion)
CHIEF_CFG_TOOL_GIT=false

# Change this to false, if you prefer the full path in your prompt.
#   Setting this to true will only show the current directory name in the prompt.
CHIEF_CFG_CWD_ONLY_PROMPT=false

# Load private SSH keys into memory. Note: Private keys need to end in ".rsa" with the exception
#   of the standard id_rsa private key.  Create a symlink if you have to.
# For example, you may have multiple keys in your ~/.ssh dir.
# Chief will automatically enable auto-load and auto-cleanup of ssh-agent.
CHIEF_RSA_KEYS_PATH="$HOME/.ssh"
