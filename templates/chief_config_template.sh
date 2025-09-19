#!/usr/bin/env bash
# CHIEF CONFIGURATION file, referred to from the $CHIEF_CONFIG variable set.
####################################

# Configure items to suit. For all variables:
#   Set values to un-quoted 'true', to enable Or 'false', to disable OR Comment (prefix with #) to disable.

# If set to true, will display a banner at start-up.
CHIEF_CFG_BANNER=true

# If set to true, will display output when plugins and SSH keys are loaded at start-up.
CHIEF_CFG_VERBOSE=false

# If set to true, will display hints at start-up.
CHIEF_CFG_HINTS=true

# If set to true, will check and inform of updates available in GitHub at start-up.
# Note: if there are any local changes, Chief will not detect any remote updates as
# it assumes you are using a forked version. Also note, depending on GitHub's current stability,
# this could take annoyingly long, so feel free to disable if it bothers you.
# You can also check for updates manually with the command: 
# $> chief.update
CHIEF_CFG_AUTOCHECK_UPDATES=false

# UPDATE CONFIGURATION
####################################

# Branch to track for Chief updates. Can be any valid Git branch name.
# Common options: "main" (stable release), "dev" (bleeding-edge), or custom branches.
# When set to "main", Chief will track the stable release branch.
# When set to "dev", Chief will track the development branch with bleeding-edge features.
# Custom branches can be used for specific versions or team-specific branches.
# WARNING: Non-main branches may contain unstable features and should be used with caution.
# This setting affects both automatic update checks and manual updates via chief.update.
CHIEF_CFG_UPDATE_BRANCH="main"

# PLUG-INS CONFIGURATION
####################################

# This is the type of plugins to use. Valid options are "local" or "remote".
# If set to "remote", it will clone the remote git repository and load plugins from the local clone.
# If set to "local", it will load plugins from the local directory.
CHIEF_CFG_PLUGINS_TYPE="local"

# Local plugin directory path - also used as clone location for remote plugin repositories.
# For local plugins: This is where your *_chief-plugin.sh files are located.
# For remote plugins: This is where the remote repository will be cloned to.
CHIEF_CFG_PLUGINS_PATH="${HOME}/chief_plugins"

# GIT REPOSITORY CONFIGURATION if CHIEF_CFG_PLUGINS_TYPE="remote"
# Only used if CHIEF_CFG_PLUGINS_TYPE="remote", this is the URL of the remote repository to clone.
# If using ssh, make sure you have the correct SSH keys set up.
# If using https, make sure you have the correct credentials set up or use a public repository.
CHIEF_CFG_PLUGINS_GIT_REPO="ssh://git@github.com/plugins.git"

# This is the branch of the remote repository to clone. Default is "main".
CHIEF_CFG_PLUGINS_GIT_BRANCH="main"

# [REMOTE PLUGINS ONLY] Relative path within the cloned repository containing *_chief-plugin.sh files.
# This is a RELATIVE PATH from the root of CHIEF_CFG_PLUGINS_PATH (the cloned repo).
# - Set to "" (empty) if *_chief-plugin.sh files are in the repo root
# - Set to subdirectory path if plugins are in a subdirectory (e.g., "tools/bash", "scripts", "plugins")
# Examples:
#   CHIEF_CFG_PLUGINS_GIT_PATH=""           # Plugins in repo root: CHIEF_CFG_PLUGINS_PATH/*.sh
#   CHIEF_CFG_PLUGINS_GIT_PATH="tools/bash" # Plugins in subdir: CHIEF_CFG_PLUGINS_PATH/tools/bash/*.sh
#   CHIEF_CFG_PLUGINS_GIT_PATH="scripts"    # Plugins in subdir: CHIEF_CFG_PLUGINS_PATH/scripts/*.sh
CHIEF_CFG_PLUGINS_GIT_PATH=""

# Load/update remote plugins when Chief starts.
# If this is set to true, it will clone/update the remote repository when Chief starts.
# If set to false, you will need to manually update the plugins with the command:
# $> chief.plugins_update
CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE="false"

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

# You can define your own starting template for plugins, otherwise 
# the default template will be used: "${CHIEF_PATH}/templates/chief_plugin_template.sh"
CHIEF_CFG_PLUGIN_TEMPLATE="${CHIEF_PATH}/templates/chief_plugin_template.sh"
####################################

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
CHIEF_CFG_SHORT_PATH=true

# Multi-line prompt: If set to true, splits the prompt across two lines for better readability
# in deep directory structures. The first line shows path, git info, etc., and the second
# line shows the actual prompt symbol.
CHIEF_CFG_MULTILINE_PROMPT=false
####################################

# TOOLS CONFIGURATION
####################################

# If set to true, will use colored ls command.
CHIEF_CFG_COLORED_LS=false

# If set to true, chief.config_set will prompt for confirmation before modifying config file.
# Set to false for non-interactive operation by default (useful for automation/scripts).
# Individual commands can still use --yes to skip prompts regardless of this setting.
CHIEF_CFG_CONFIG_SET_INTERACTIVE=true

# If set to true, chief.config_update will create timestamped backups when making changes.
# Set to false to skip backup creation (useful for automation where you handle backups externally).
# Only creates backups when actual changes are made to configuration file.
CHIEF_CFG_CONFIG_UPDATE_BACKUP=true

# Load private SSH keys into memory. 
# Private keys are required to end in ".key" (symlinks are allowed)
# Supports RSA, ed25519, and other key types. Use symlinks for selective loading.
# Chief will automatically enable (ssh-add) auto-load and auto-cleanup of ssh-agent.
#
# If you have a directory with your private keys, you can set the path here.
# Setting this variable will automatically load your SSH keys, you can also run $>chief.ssh_load_keys
# to manually load them. 
# If you do not set or comment this variable, it will not load any keys.
#CHIEF_CFG_SSH_KEYS_PATH="$HOME/.ssh"

# If you want to create a custom alias for the chief command, you can do so here.
# By default it is set to "chief.*", but you can change it to something else.
# Keep in mind that this will only add an alias, so chief.* commands will still work.
#CHIEF_CFG_ALIAS="cf"
