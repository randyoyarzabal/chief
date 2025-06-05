#!/usr/bin/env bash
# CHIEF BASH LIBRARY CONFIGURATION
####################################

# Configure items to suit. For all variables:
#   Set values to: true, to enable Or false, to disable
#   or
#   Comment (prefix with #) to disable.
#   Un-comment (remove #) to enable.

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
# You can also check for updates manually with the command: 
# $> chief.update
CHIEF_CHECK_UPDATES=false

# PLUG-INS CONFIGURATION
####################################

CHIEF_CORE_PLUGINS=true
# Core plugins are located in: "${CHIEF_PATH}/libs/plugins"

# USER LIBRARY PLUGINS
CHIEF_USER_PLUGINS="${HOME}/chief_plugins"
# Plugins are loaded in alphabetical order, so you can control the order of loading by naming them accordingly.
# If the directory does not exist, it will be created automatically.
# 
# All plug-in files in this directory must end in "*_chief-plugin.sh" any others will be ignored.
# Any file in this directory will be loaded as a plug-in e.g. "<plugin name>_chief-plugin.sh"
# 
# Plug-ins can be edited (created automatically) and dynamically (re)loaded with the command:
# $> chief.plugin <plugin name>
# e.g. if you have a file named "sample_chief-plugin.sh" in the directory,
# you can access it with the command:
# $> chief.plugin sample

# If you have existing bash functions or scripts that you want to use as plugins,
# you can rename the file file in this directory as "<plugin name>_chief-plugin.sh"
# or make a symlink to it in this directory with the name "<plugin name>_chief-plugin.sh"
#
# For example, if you have a script named "lab.sh" in the directory,
# you can create a symlink to it in the directory as "lab_chief-plugin.sh"
# Or rename it to "lab_chief-plugin.sh" and it will be loaded as a plug-in.

# ** CHIEF_USER_PLUGIN_DEFAULT is required and must be defined to hold the default user library.' **
CHIEF_USER_PLUGIN_DEFAULT="$CHIEF_USER_PLUGINS/default_chief-plugin.sh"

# You can define your own starting template for user plugins, otherwise 
# the default template will be used: "${CHIEF_PATH}/templates/chief_user_plugin_template.sh"
CHIEF_CFG_USER_PLUGIN_TEMPLATE="${CHIEF_PATH}/templates/chief_user_plugin_template.sh"

# PROMPT CONFIGURATION
####################################

# If set to true, will display a custom prompt. If set to false, all following options below will be ignored.
CHIEF_CFG_PROMPT=false

# Apply colored prompt if CHIEF_CFG_PROMPT is set to true.
CHIEF_CFG_COLORED_PROMPT=true

# Load Git Tools (git-aware prompt and git command completion) if CHIEF_CFG_PROMPT is set to true.
CHIEF_CFG_GIT_PROMPT=true

# Change this to false, if you prefer the full path in your prompt.
#   Setting this to true will only show the current directory name in the prompt.
CHIEF_CFG_CWD_ONLY_PROMPT=true
####################################

# TOOLS CONFIGURATION
####################################

# If set to true, will use colored ls command.
CHIEF_CFG_COLORED_LS=false

# Load private SSH keys into memory. 
# Private keys are required to end in ".rsa" (symlinks are allowed)
# Chief will automatically enable (ssh-add) auto-load and auto-cleanup of ssh-agent.
#
# If you have a directory with your private keys, you can set the path here.
# If you do not set this variable, it will not load any keys.
#CHIEF_RSA_KEYS_PATH="$HOME/.ssh"

# If you want to create a custom alias for the chief command, you can do so here.
# By default it is set to "chief.*", but you can change it to something else.
# Keep in mind that this will only add an alias, so chief.* commands will still work.
#CHIEF_ALIAS="cf"
