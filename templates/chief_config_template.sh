#!/usr/bin/env bash
# CHIEF CONFIGURATION file, referred to from the $CHIEF_CONFIG variable set.
####################################

# Configure items to suit. For all variables:
#   Set values to un-quoted 'true', to enable Or 'false', to disable OR Comment (prefix with #) to disable.

# BANNER
####################################

# If set to true, will display a banner at start-up.
CHIEF_CFG_BANNER=true

# Banner indicators: short status items shown to the right of the logo, one per line,
# in this order (space- or comma-separated). Remove a name to hide it; set it to ""
# for just the logo and version. The banner keeps its size: up to 4 lines (3 in the
# compact style), and any extra indicators share the last line, joined by " · ".
# Indicators with nothing to show take no line (e.g. alias when no alias is set).
#
#   alias     alias: cf                                  (only when CHIEF_CFG_ALIAS is set)
#   plugins   plugins: 22 on, 4 off · git, manual update (loaded/off; where user plugins come from)
#   tracking  tracking: dev (bleeding-edge, auto)        (the branch Chief updates from)
#   secrets   secrets: loaded | loaded, silent | not loaded | found (at start-up)
#             (silent = loaded with --quiet; chief.status shows the details)
CHIEF_CFG_BANNER_INDICATORS="alias plugins tracking secrets"

# Banner logo: "full" (the classic Chief logo) or "compact" (a 3-line, 13-column logo
# that leaves more room for the indicators on narrow screens).
CHIEF_CFG_BANNER_STYLE="full"

# Older configs: CHIEF_CFG_BANNER_SHOW_PLUGINS=false / CHIEF_CFG_BANNER_SHOW_TRACKING=false
# still hide those indicators; prefer CHIEF_CFG_BANNER_INDICATORS.

# If set to true, will warn at start-up when Chief is loaded by Bash older than 4.0
# (e.g. the macOS system bash, 3.2) and show how to install/use a newer one.
# Set to false to silence the warning.
CHIEF_CFG_BASH_WARN=true

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

# Branch Chief updates from (manual chief.update and the automatic update check).
# "auto" (default): follow whatever branch Chief's own checkout ($CHIEF_PATH) is on. To move
#   between stable and bleeding-edge, just switch the checkout; the banner shows which:
#     git -C "$CHIEF_PATH" switch dev     (or: main)
#   On a tag or detached HEAD there's no branch to follow, so "main" is used.
# A branch name pins it instead: "main" (stable), "dev" (bleeding-edge, may be unstable),
#   or any other branch. chief.update then offers to switch the checkout to that branch.
CHIEF_CFG_UPDATE_BRANCH="auto"

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

# Your Chief identity in a team repo: a shared plugins repo whose plugins folder has a users/
# folder (per-user files). REQUIRED in a team repo; not needed otherwise, including a repo
# only you use to sync your own hosts.
# It names your folder in the repo's plugins folder, users/<name>/, which can hold your own
# settings (config.sh), start-up code (profile.sh) and encrypted secrets (secrets), loaded after
# the shared ones (.chief_shared-config.sh, .chief_shared-profile.sh, .chief_shared-secrets).
# Use the same name on every host, even where your login name differs. Letters, digits, . _ -
# Set it with: chief.config-set user <name>   (or: chief.plugins-repo <url> --user <name>)
# The repo becomes a team repo when someone first creates users/<name>/ (for example with
# chief.shared-profile --personal); from then on Chief warns on hosts where it isn't set.
CHIEF_CFG_USER=""

# Load/update remote plugins when Chief starts.
# If this is set to true, it will clone/update the remote repository when Chief starts.
# If set to false, you will need to manually update the plugins with the command:
# $> chief.plugins-update
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
#
# Command: chief.plugin <plugin name> <path-to-existing-script>
# creates that symlink for you. When the script is under the same directory tree as this
# plugins directory, Chief uses a relative symlink target so git clones work on other machines
# (team / remote plugin repos). Otherwise the target is absolute; see chief.plugin -?

# You can define your own starting template for plugins, otherwise 
# the default template will be used: "${CHIEF_PATH}/templates/chief_plugin_template.sh"
CHIEF_CFG_PLUGIN_TEMPLATE="${CHIEF_PATH}/templates/chief_plugin_template.sh"

# Comma- or space-separated list of plugins to skip loading. Managed via: chief.plugin enable|disable [core.]<name>
# Core: built-in plugin names. aws, openshift and vault are off by default because they need
# tools or accounts most users don't have; turn one on with: chief.plugin enable core.aws
# User: your own plugin names (e.g. bc,lab or bc lab).
CHIEF_CFG_PLUGINS_DISABLED_CORE="aws openshift vault"
CHIEF_CFG_PLUGINS_DISABLED_USER=""

# Contrib plugins are shipped with Chief (libs/contrib/plugins) for specific teams or workflows.
# Chief scans them on every load, but each is OFF until enabled (currently: cg).
# Turn one on with: chief.plugin enable contrib.<name>   (off again: chief.plugin disable contrib.<name>)
CHIEF_CFG_PLUGINS_ENABLED_CONTRIB=""

# [cg contrib plugin] Path to your local copy of the Chainguard customer-success helper
# functions. The cg plugin sources it and exposes its functions as cg.* (see: cg.help).
# No default: set it to wherever your clone lives, e.g.
#   chief.config-set cg_helper_functions "/path/to/customer-success/scripts/.helper_functions.sh"
CHIEF_CFG_CG_HELPER_FUNCTIONS=""

# DEV TOOLS (Chief maintainers only)
# Loads maintainer tooling from libs/dev/plugins, such as chief.release_status,
# chief.release_prepare and chief.release_publish. It only takes effect when Chief's own
# checkout ($CHIEF_PATH) is on the "dev" branch; on main or a release it never loads.
CHIEF_CFG_DEV_TOOLS=false
####################################

# PROMPT CONFIGURATION
####################################

# If set to true, will display a custom prompt. If set to false, all following options below will be ignored.
CHIEF_CFG_PROMPT=true

# Apply colored prompt if CHIEF_CFG_PROMPT is set to true.
CHIEF_CFG_COLORED_PROMPT=true

# Load Git Tools (git-aware prompt and git command completion) if CHIEF_CFG_PROMPT is set to true.
CHIEF_CFG_GIT_PROMPT=true

# Change this to false, if you prefer the full path in your prompt.
#   Setting this to true will only show the current directory name in the prompt.
CHIEF_CFG_SHORT_PATH=false

# Multi-line prompt: If set to true, splits the prompt across two lines for better readability
# in deep directory structures. The first line shows path, git info, etc., and the second
# line shows the actual prompt symbol.
CHIEF_CFG_MULTILINE_PROMPT=false

# Override hostname display in prompt: Set this environment variable to customize the 
# hostname shown in Chief's prompt. Useful for systems where you want to mark/identify
# the system but don't want to or can't change the actual system hostname.
# This is an environment variable, not a configuration setting, so export it:
# export CHIEF_HOST="my-server"
# Note: This affects all Chief prompts (single-line, multi-line, git-aware)
#export CHIEF_HOST="production-server"
####################################

# TOOLS CONFIGURATION
####################################

# Default editor for Chief operations (editing configs, plugins, bash files, etc.)
# Falls back to $EDITOR environment variable if not set, then vim if available, then vi
# Examples: "vim", "nano", "emacs", "code --wait"
# Leave commented to use system defaults ($EDITOR → vim → vi)
#CHIEF_CFG_DEFAULT_EDITOR_PATH=""

# Editor used when you pass --code or --vscode (e.g. chief.plugin mytools --code).
# If unset, Chief tries: cursor --wait, then code --wait. Set this to force one:
#   Cursor:  CHIEF_CFG_EDITOR_GUI_CMD="cursor --wait"
#   VSCode:  CHIEF_CFG_EDITOR_GUI_CMD="code --wait"
#CHIEF_CFG_EDITOR_GUI_CMD=""

# If set to true, will use colored ls command.
CHIEF_CFG_COLORED_LS=false

# If set to true, chief.config-set will prompt for confirmation before modifying config file.
# Set to false for non-interactive operation by default (useful for automation/scripts).
# Individual commands can still use --yes to skip prompts regardless of this setting.
CHIEF_CFG_CONFIG_SET_INTERACTIVE=true

# If set to true, chief.config-update will create timestamped backups when making changes.
# Set to false to skip backup creation (useful for automation where you handle backups externally).
# Only creates backups when actual changes are made to configuration file.
CHIEF_CFG_CONFIG_UPDATE_BACKUP=true

# Load private SSH keys into memory. 
# Supported key file patterns:
#   - *.key (Chief preferred naming: mykey.key)
#   - *.private (legacy support: mykey.private)  
# Supports RSA, ed25519, and other key types. Use symlinks for selective loading.
# Chief will automatically enable (ssh-add) auto-load and auto-cleanup of ssh-agent.
# Note: Standard SSH keys (id_rsa, id_ed25519, etc.) are automatically used by SSH clients.
#
# Load your SSH keys into ssh-agent at start-up (and on chief.reload). Off by default.
# Turn on with: chief.config-set ssh_load_keys true   (any time: chief.ssh_load-keys)
CHIEF_CFG_SSH_LOAD_KEYS=false

# Where the keys are. Optional: Chief uses ~/.ssh unless you set a different directory here.
#CHIEF_CFG_SSH_KEYS_PATH="$HOME/.ssh"

# Load your encrypted secrets at start-up, instead of a chief.secrets_file-load line in
# ~/.bash_profile. Loads every secrets file that exists (shared, personal, this host), quietly.
#   false  don't (default)
#   true   in interactive shells: use the saved password, else prompt for it
#   saved  in interactive shells: only files with a saved password; never prompts
# Save a file's password once with: chief.secrets_password-save
# Quiet unless CHIEF_CFG_VERBOSE=true, which names the files it loaded; the banner shows it either way.
# Turn on with: chief.config-set secrets_load true   (or per host in shared settings)
CHIEF_CFG_SECRETS_LOAD=false

# Also load them in non-interactive shells (scripts, editors, AI tools): saved passwords only,
# never prompts, no output. Off by default: with it on, every script and tool that starts Chief
# gets your secrets in its environment. Turn on only where scripts need them, e.g. per host:
#   if chief.host_is 'build-*'; then CHIEF_CFG_SECRETS_LOAD_NONINTERACTIVE=true; fi
CHIEF_CFG_SECRETS_LOAD_NONINTERACTIVE=false

# If you want to create a custom alias for the chief command, you can do so here.
# By default it is set to "chief.*", but you can change it to something else.
# Keep in mind that this will only add an alias, so chief.* commands will still work.
#CHIEF_CFG_ALIAS="cf"
