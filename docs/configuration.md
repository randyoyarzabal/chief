---
layout: default
title: Configuration
description: "Advanced configuration, multi-system setup, and team collaboration"
---

[← Back to Home](https://chief.randyo.dev/)

# Configuration

Advanced configuration options, multi-system setup, and team collaboration workflows.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Configuration Management

Chief is highly customizable. Use `chief.config` to edit the config file or `chief.config-set <option> <value>` for direct command-line configuration.

**Interactive Behavior:** By default, `chief.config-set` prompts for confirmation before modifying your configuration file. Use `--yes` (or `-y`) to skip prompts for scripting.

### Basic Configuration Commands

```bash
# Edit configuration file
chief.config

# Set configuration variables directly (use option name without CHIEF_CFG_ prefix)
chief.config-set banner false         # Sets CHIEF_CFG_BANNER=false (prompts for confirmation)
chief.config-set banner=false         # Same as above using key=value syntax
chief.config-set --yes prompt true    # Sets CHIEF_CFG_PROMPT=true (no prompt)  
chief.config-set colored_ls=true      # Sets CHIEF_CFG_COLORED_LS=true (prompts for confirmation)

# List all configuration variables and current values  
chief.config-set --list

# Update configuration with new template options (perfect for upgrades)
chief.config-update                   # Add missing options, handle renames, preserve customizations
chief.config-update --dry-run         # Preview changes without applying them

# Disable interactive prompts globally
chief.config-set config_set_interactive false
```

**When a change takes effect.** `chief.config-set` (and `chief.reload`) reload Chief's library and plugins, so most changes apply right away. A few settings are applied only when a terminal starts. For those, `chief.config-set` saves the change but skips the reload (it couldn't apply them, so it would only print noise) and prints a yellow **Note** with what to do:

| Setting | When it takes effect |
|---------|----------------------|
| `PROMPT`, `COLORED_PROMPT`, `GIT_PROMPT`, `SHORT_PATH`, `COLORED_LS` | A new terminal (`chief.reload` doesn't re-apply them) |
| `ALIAS` | Now, but a previous alias's commands stay until a new terminal |
| `BANNER`, `HINTS`, `AUTOCHECK_UPDATES`, `BASH_WARN` | The next terminal you open (they only run at start-up) |
| `SSH_LOAD_KEYS`, `SSH_KEYS_PATH` | Start-up or `chief.reload`; run `chief.ssh_load-keys` to load keys now |

---

## Configuration Options

### Core Settings

| Configuration | Default | Description |
|---------------|---------|-------------|
| `CHIEF_CFG_BANNER` | `true` | Show startup banner |
| `CHIEF_CFG_BANNER_INDICATORS` | `"alias plugins tracking secrets"` | Status items to the right of the banner logo, in order (space- or comma-separated; `""` for none). See [Banner indicators](#banner-indicators) |
| `CHIEF_CFG_BANNER_STYLE` | `"full"` | Banner logo: `full` (classic) or `compact` (a 3-line, 13-column logo that leaves more room on narrow screens) |
| `CHIEF_CFG_HINTS` | `true` | Display helpful tips on startup |
| `CHIEF_CFG_VERBOSE` | `false` | Show output while plugins and SSH keys load at start-up |
| `CHIEF_CFG_BASH_WARN` | `true` | Warn at start-up when Chief runs under Bash older than 4.0 (e.g. macOS's system Bash 3.2) and show how to fix it. Silence with `chief.config-set -y BASH_WARN=false`. Non-interactive shells on old Bash load only the core library, with no warning |
| `CHIEF_CFG_DEFAULT_EDITOR_PATH` | _unset_ | Editor for Chief's edit commands (configs, plugins, bash files). Unset: `$EDITOR`, then `vim`, then `vi`. Example: `chief.config-set default_editor_path "vim"` |
| `CHIEF_CFG_EDITOR_GUI_CMD` | _unset_ | Editor used with `--code` / `--vscode` (e.g. `chief.plugin mytools --code`). Unset: `cursor --wait` if Cursor is installed, else `code --wait` |
| `CHIEF_CFG_PROMPT` | `false` | Use Chief's custom prompt (keep disabled if using Oh My Bash/Starship) |
| `CHIEF_CFG_COLORED_PROMPT` | `true` | Colorize the prompt |
| `CHIEF_CFG_GIT_PROMPT` | `true` | Git-aware prompt features |
| `CHIEF_CFG_MULTILINE_PROMPT` | `false` | Enable multiline prompt display |
| `CHIEF_CFG_SHORT_PATH` | `false` | Show only current directory name in prompt |
| `CHIEF_CFG_COLORED_LS` | `false` | Colorize ls command output |
| `CHIEF_CFG_CONFIG_SET_INTERACTIVE` | `true` | Prompt for confirmation in `chief.config-set` |
| `CHIEF_CFG_CONFIG_UPDATE_BACKUP` | `true` | Create backups during config updates (only when changes made) |
| `CHIEF_CFG_PLUGINS_TYPE` | `"local"` | Use `"local"` or `"remote"` plugins |
| `CHIEF_CFG_SSH_LOAD_KEYS` | `false` | Load SSH keys into ssh-agent at start-up and on `chief.reload` |
| `CHIEF_CFG_SSH_KEYS_PATH` | _unset_ (`~/.ssh`) | Optional: a different directory to load keys from |
| `CHIEF_CFG_ALIAS` | _unset_ | Create short alias (e.g., `"cf"`) |
| `CHIEF_CFG_AUTOCHECK_UPDATES` | `false` | Check for updates on startup |
| `CHIEF_CFG_GIT_COMMIT_WARN_MB` | `50` | `chief.git_commit` warns before committing staged files larger than this many MB (skip the check with `-f`) |
| `CHIEF_CFG_DEV_TOOLS` | `false` | Maintainers only: load the release commands (`chief.release_status`, `chief.release_prepare`, `chief.release_publish`). Takes effect only when Chief's own checkout is on the `dev` branch |
| `CHIEF_CFG_UPDATE_BRANCH` | `"auto"` | Branch to update from. `auto`: whatever branch `$CHIEF_PATH` is checked out on (switch with `git -C ~/.chief switch dev` / `main`; tag or detached HEAD → `main`). A branch name pins it (⚠ non-main may be unstable) |

### Environment Variables

These are environment variables (not configuration settings) that affect Chief's behavior:

| Variable | Default | Description |
|----------|---------|-------------|
| `CHIEF_HOST` | _unset_ | Override hostname display in prompt. Useful for marking systems without changing hostname. |
| `NO_COLOR` | _unset_ | When set, disables all ANSI colors in Chief output (core, plugins, install/uninstall scripts). |
| `CHIEF_FORCE_COLOR` | _unset_ | When set, forces ANSI colors even when stdout is not a TTY (e.g. piped output or CI logs). By default colors are emitted only on a capable TTY. |

**Example:**

```bash
# Add to your ~/.bashrc or ~/.bash_profile
export CHIEF_HOST="production-server"

# Or set temporarily for current session
CHIEF_HOST="dev-box" bash
```

### Plugin Configuration

| Configuration | Description |
|---------------|-------------|
| `CHIEF_CFG_PLUGINS_GIT_REPO` | Remote Git repository URL for plugins |
| `CHIEF_CFG_PLUGINS_GIT_BRANCH` | Git branch to use (default: "main") |
| `CHIEF_CFG_PLUGINS_PATH` | Local plugin directory (also remote repo clone location) |
| `CHIEF_CFG_PLUGINS_GIT_PATH` | [Remote only] Relative path within repo containing plugins (empty = repo root) |
| `CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE` | Auto-update plugins on startup (with local changes protection) |
| `CHIEF_CFG_PLUGIN_TEMPLATE` | Starting template for new plugins created with `chief.plugin <name>` (default: `${CHIEF_PATH}/templates/chief_plugin_template.sh`) |
| `CHIEF_CFG_PLUGINS_DISABLED_CORE` | Comma- or space-separated list of **core** plugin names to skip loading. New installs: `"aws openshift vault"` (they need extra tools or accounts). Empty = all core plugins enabled. |
| `CHIEF_CFG_PLUGINS_DISABLED_USER` | Comma- or space-separated list of **user** plugin names to skip loading (e.g. `bc,lab` or `bc lab`). Empty = all user plugins enabled. |
| `CHIEF_CFG_PLUGINS_ENABLED_CONTRIB` | Comma- or space-separated list of **contrib** plugins to load (e.g. `cg`). Contrib plugins are off unless listed here. Managed by `chief.plugin enable\|disable contrib.<name>`. |
| `CHIEF_CFG_CG_HELPER_FUNCTIONS` | [`cg` contrib plugin] Path to `.helper_functions.sh` in your local clone of the customer-success repo. No default; set it with `chief.config-set cg_helper_functions "<path>"`. |

### Enabling and disabling plugins

You can disable specific **core** (built-in) or **user** plugins so they are not loaded at startup. Disabled plugins are skipped on load; you can re-enable them anytime.

**From the command line (updates config and reloads Chief):**

```bash
chief.plugin disable ssl          # Disable user plugin "ssl" (if you have one)
chief.plugin disable core.ssl     # Disable core plugin "ssl"
chief.plugin enable core.ssl      # Re-enable core plugin "ssl"
chief.plugin status               # Show which plugins are enabled/disabled
```

**In configuration:** set `CHIEF_CFG_PLUGINS_DISABLED_CORE` and/or `CHIEF_CFG_PLUGINS_DISABLED_USER` in your config file. Both accept comma- or space-separated names. Core plugin names are the built-in ones (e.g. `aws`, `git`, `ssl`); user plugin names are the prefixes of your `*_chief-plugin.sh` files (e.g. `bc`, `lab`).

```bash
# In chief.config or via chief.config-set:
CHIEF_CFG_PLUGINS_DISABLED_CORE="aws,ssl"    # Skip core aws and ssl
CHIEF_CFG_PLUGINS_DISABLED_USER="lab"       # Skip user plugin "lab"
```

### Core plugins that are off by default

`aws`, `openshift` and `vault` need tools or accounts most users don't have, so new installs list them in `CHIEF_CFG_PLUGINS_DISABLED_CORE`. They follow the same rule as every other core plugin: loaded unless they're in the disabled list.

```bash
chief.plugin enable core.openshift   # Removes it from CHIEF_CFG_PLUGINS_DISABLED_CORE
chief.plugin disable core.openshift  # Adds it back
chief.plugin status                  # Shows what's on and off
```

| Plugin | Needs |
|--------|-------|
| `aws` | AWS credentials, `python3` |
| `openshift` | `oc` and a cluster login, `jq` |
| `vault` | HashiCorp `vault` CLI and a Vault server |

**Upgrading:** existing configs already have their own `CHIEF_CFG_PLUGINS_DISABLED_CORE` line, so whatever was loading keeps loading. Only new installs start with these three off.

### Contrib plugins

Chief also ships optional plugins for specific teams or workflows in `libs/contrib/plugins/`. Chief scans that directory on every load, but **every contrib plugin is off by default**, so it has no effect until you turn it on:

```bash
chief.plugin enable contrib.cg    # Turn on (adds it to CHIEF_CFG_PLUGINS_ENABLED_CONTRIB)
chief.plugin disable contrib.cg   # Turn off again
chief.plugin status               # Contrib plugins are listed in their own section
```

| Plugin | What it does |
|--------|--------------|
| `cg` | Exposes the Chainguard customer-success helper functions as `cg.*` commands (each with `-?`/`--help`; list them with `cg.help`). Chief ships only the wrapper: it sources your local copy of the helper functions from `CHIEF_CFG_CG_HELPER_FUNCTIONS`. No location is assumed; set it once with `chief.config-set cg_helper_functions "/path/to/customer-success/scripts/.helper_functions.sh"`. |

---

## Advanced Features

### Banner indicators

The banner shows short status items to the right of the logo. Choose which ones and their order with `CHIEF_CFG_BANNER_INDICATORS`, and pick a smaller logo for narrow screens with `CHIEF_CFG_BANNER_STYLE`:

```bash
chief.config-set banner_indicators "tracking secrets"   # just these two, in this order
chief.config-set banner_indicators ""                   # logo and version only
chief.config-set banner_style compact                   # smaller logo
```

| Indicator | Example | Shows |
|-----------|---------|-------|
| `alias` | `alias: cf` | Your `CHIEF_CFG_ALIAS` (only when set) |
| `plugins` | `plugins: 22 on, 4 off · git, manual update` | Plugins loaded and turned off (core, contrib, user), and where user plugins come from |
| `tracking` | `tracking: dev (bleeding-edge, auto)` | The branch Chief updates from |
| `secrets` | `secrets: loaded, silent` | Secrets in this shell: `loaded`, `loaded (2)`, `loaded, silent` (loaded with `--quiet`), `not loaded`. At start-up it says `found`, because `~/.bash_profile` loads secrets after the banner prints. `chief.status` shows the details |

The banner keeps its size. Indicators fill the logo's lines (4 in the full style, 3 in the compact one), with any extras sharing the last line after a ` · `. An indicator with nothing to show takes no line.

```
  _____/ /_  (_)__  / __/ plugins: 22 on, 4 off · git, manual update
 / ___/ __ \/ / _ \/ /_   tracking: dev (bleeding-edge, auto)
/ /__/ / / / /  __/ __/   secrets: loaded, silent
\___/_/ /_/_/\___/_/ v3.2.1-dev [MacOS]

┌─┐┬ ┬┬┌─┐┌─┐  plugins: 22 on, 4 off · git, manual update
│  ├─┤│├┤ ├┤   tracking: dev (bleeding-edge, auto)
└─┘┴ ┴┴└─┘└    secrets: loaded, silent
v3.2.1-dev [MacOS]
```

Older configs that set `CHIEF_CFG_BANNER_SHOW_PLUGINS=false` or `CHIEF_CFG_BANNER_SHOW_TRACKING=false` still hide those indicators.

### SSH Key Auto-loading

```bash
# Turn on auto-loading (keys come from ~/.ssh):
chief.config-set ssh_load_keys true

# Optional: load from a different directory instead of ~/.ssh
chief.config-set ssh_keys_path "$HOME/keys"

# Chief loads all *.key files (and legacy *.private)
# Supports RSA, ed25519, and other key types
# Use symlinks for selective loading (e.g., ln -s id_rsa mykey.key)
```

### Custom Prompt Features

> **⚠ Important:** Only enable Chief's prompt if you're **not** using Oh My Bash, Starship, or other prompt customization tools. Chief's prompt is **disabled by default** to prevent conflicts.

```bash
# Enable git-aware prompt (only if not using other prompt tools)
CHIEF_CFG_PROMPT=true
CHIEF_CFG_GIT_PROMPT=true

# Shows: user@host:~/project (main|+2-1) $ 
#        ↑              ↑     ↑    ↑  ↑
#        user           path  branch +staged -unstaged
```

### Personal Plugin Sync

```bash
# Sync your personal plugins across machines
CHIEF_CFG_PLUGINS_TYPE="remote"
CHIEF_CFG_PLUGINS_GIT_REPO="git@github.com:yourusername/my-bash-plugins.git"

# Auto-update on startup
CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE="true"
```

---

## Multi-System Setup

### Primary Use Case: Single User, Multiple Systems

Chief is primarily designed as a **single-user system** that follows you across multiple environments:

- **Personal workflows**: Your plugins and vault sync from laptop → server → development environments
- **Consistent setup**: Same functions, aliases, and secrets everywhere you use Chief
- **Zero reconfiguration**: Once set up, Chief works identically on all your systems

```bash
# Your personal setup works the same everywhere:
# Laptop:     chief.secrets_file-load → access your secrets
# Server:     chief.secrets_file-load → same secrets, same functions  
# CI/CD:      chief.secrets_file-load → consistent automation
```

### Portable Setup Configuration

**Real-world example**: Set up Chief with remote plugins and vault that follows you across all systems.

#### One-Time Setup (any new system)

```bash
# New host: install Chief and adopt your repo in one step (see Getting Started)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/dev/tools/install.sh)" -- \
  --repo git@github.com:yourusername/my-plugins.git --repo-path bash/plugins --user you

# Chief already installed: the same, from inside Chief
chief.plugins-repo git@github.com:yourusername/my-plugins.git --path bash/plugins --user you
```

Either one clones the repo, points this host's config at it (`CHIEF_CFG_PLUGINS_TYPE=remote` and the `CHIEF_CFG_PLUGINS_*` settings), and sets `CHIEF_CFG_USER`. Your shared settings, profile and secrets then apply from the next terminal. See [Shared repo: the same Chief everywhere](#shared-repo-the-same-chief-everywhere).

For detailed secrets and vault setup, see: [Secrets and Vault Configuration](configuration.html#secrets-and-vault-configuration)

#### Result

- ✓ **Same plugins everywhere**: Functions, aliases, and tools sync across laptop, server, CI/CD
- ✓ **Encrypted secrets**: Secrets files travel with your setup (team + personal)
- ✓ **Zero reconfiguration**: New systems work identically after this setup
- ✓ **Version controlled**: Track changes to your shell environment

#### Daily Workflow

```bash
chief.plugins-update           # Get latest team plugins
chief.secrets_file-load          # Load secrets when needed
chief.plugin mytools           # Edit/create plugins
chief.whereis my_function      # Find any function instantly
```

---

## Shared repo: the same Chief everywhere

Point every host (and every account) at one shared plugins repo, and you get the same environment everywhere: plugins, settings, start-up code and secrets, for you and for your team.

### What the repo can hold

Everything lives in the repo's plugins folder (`CHIEF_CFG_PLUGINS_GIT_PATH`, which can be deep, e.g. `path/to/plugins`):

| File | Whose | What |
|------|-------|------|
| `*_chief-plugin.sh` | Everyone | Plugins (functions, aliases) |
| `.chief_shared-config.sh` | Team | Chief settings for everyone |
| `.chief_shared-profile.sh` | Team | Start-up code for everyone (a shared `~/.bash_profile`) |
| `.chief_shared-secrets` | Team | Encrypted team secrets (team password) |
| `users/<you>/config.sh` | You | Your settings |
| `users/<you>/profile.sh` | You | Your start-up code |
| `users/<you>/secrets` | You | Your encrypted secrets (your own password) |

`<you>` is **`CHIEF_CFG_USER`**, your Chief identity, the same on every host even where your login name differs (for example `alice.smith` on a laptop and `deploy` on a server, both `alice`). It's **required in a team repo**: one whose plugins folder has a `users/` folder. A repo only you use, with no `users/` folder, doesn't need it; the team files are yours there. The repo becomes a team repo when someone first creates `users/<name>/`: only the `--personal` commands do that (`chief.shared-profile --personal`, `chief.shared-config --personal`, `chief.secrets_file-edit --personal`), and they say so. Close the editor without changes and nothing is kept. From then on, Chief loads only the team layers on hosts where the user isn't set, and warns at start-up how to set it. Onboarding asks for it when there's a terminal; otherwise use `chief.config-set user <name>`. `chief.status` shows your user and the layers in use.

### Onboarding a host

```bash
# New host (installs Chief too)
install.sh --repo <git-url> --repo-path <folder> [--user <name>]
# Host that already has Chief
chief.plugins-repo <git-url> --path <folder> [--user <name>]
```

`--user` is for a team repo (one with `users/` folders); leave it out for a repo only you use.

Then open a new terminal. On each host, save your secrets passwords once with `chief.secrets_password-save` so they don't prompt.

### Settings: team, then yours

Settings apply in this order, later ones winning: this host's `~/.chief_config.sh` (defaults, plus where the repo is), then the team's `.chief_shared-config.sh`, then your `users/<you>/config.sh`. Edit them with `chief.shared-config` and `chief.shared-config --personal`; both offer to commit and push when you changed something.

- **Host exceptions** go inside the shared files: `if chief.host_is my-laptop; then CHIEF_CFG_PROMPT=false; fi`.
- **Where the repo is** (`CHIEF_CFG_PLUGINS_*`) and **`CHIEF_CFG_USER`** always come from each host's own config. The repo can't redirect itself.
- `chief.config-set` warns when the setting you change is also set in the shared layers, since those take precedence.

### Profile: a shared `~/.bash_profile`

`.chief_shared-profile.sh` (team) and `users/<you>/profile.sh` (yours) hold start-up code: exports, `PATH`, aliases, functions. Edit them with `chief.shared-profile` / `chief.shared-profile --personal`.

- They run **once per shell, before plugins load**, so plugins see their exports (for example variables a plugin reads while loading). `chief.reload` doesn't re-run them.
- Order: team, then yours, then each host's `~/.bash_profile`. Lines after `source …/chief.sh` there can override both.
- **Commands from plugins** aren't loaded yet at that point, so queue them with `chief.on_startup`. It runs at the end of start-up:
  ```bash
  chief.on_startup chief.secrets_file-load --quiet
  ```
- **Host- or login-specific lines** go in a `chief.host_is` block. See [Host and login checks](#host-and-login-checks) below.

**What stays in `~/.bash_profile`:** Chief's own lines (`CHIEF_PATH`, `CHIEF_CONFIG`, `source …/chief.sh`), anything Chief needs before it starts (such as `CHIEF_HOST`), and anything you don't want in git. Host-specific lines can live either there or in the shared profile under `chief.host_is`. In the repo they're versioned and come back automatically on a replacement machine.

**Trust:** shared profiles are code that runs as you on every host. Anyone who can push to the repo can change them, the same as plugins.

### Host and login checks

`chief.host_is <pattern> [pattern...]` is true when this shell matches any of the patterns. A pattern **without `@` is a host name**; a pattern **with `@` is `login@host`**, so you can target a machine, an account, or both:

| Pattern | Matches |
|---|---|
| `my-laptop` | the host my-laptop, any login |
| `'build-*'` | any host whose name starts with `build-` |
| `build-01 build-02` | either host (several patterns: any one matching is enough) |
| `'deploy@*'` | the login `deploy`, on any host |
| `'deploy@build-01'` | the login `deploy`, only on build-01 |
| `'root@*'` | root shells, on any host |
| `'*@build-01'` | any login on build-01 (same as `build-01`) |
| `! chief.host_is build-01` | everywhere **except** build-01 (`!` negates) |
| `! chief.host_is 'build-*' 'root@*'` | on **none** of these: not a build host, and not as root |

- **Host name:** `$CHIEF_HOST` if it's set, otherwise the short `hostname`. Set `CHIEF_HOST` in a host's `~/.bash_profile`, before Chief loads, when the real hostname isn't the name you want to write (a laptop called `MacBook-Pro-3`, for example).
- **Login:** `$USER`, the account the shell runs as. It's the login on that host, not `CHIEF_CFG_USER`.
- **Wildcards** `*` and `?` work on both sides of the `@`. Quote patterns that use them, so the shell doesn't expand them as file names.
- **Which to use:** check the host for anything tied to a machine (paths, mounts, hardware). Check the login for anything tied to the account, on whichever host it is (for example tools only a service account uses, or keeping something out of root's shell).
- **Not on a host:** put `!` before the call: `if ! chief.host_is build-01; then ...; fi`. With several patterns it's true only when none of them match.
- **The OS** isn't a host check: test `$PLATFORM` (`MacOS` or `Linux`) instead.
- Run `chief.host_is -?` on a host to see what it calls itself, shown as `login@host`.

```bash
if chief.host_is my-laptop; then export BACKUP_DIR=~/backups; fi          # one machine
if chief.host_is 'build-*' build-db; then alias ll='ls -alF'; fi           # a group of machines
if chief.host_is 'deploy@*'; then export PATH="/opt/deploy/bin:$PATH"; fi  # one account, any host
if ! chief.host_is build-01; then export PROXY=off; fi                     # everywhere except build-01
if ! chief.host_is 'root@*'; then chief.on_startup chief.secrets_file-load --quiet; fi  # not as root
```

### Secrets: team AND personal AND this host

`chief.secrets_file-load` with no file loads **every** secrets file that exists, in this order (later files override earlier ones that set the same variable):

| Layer | File | Follows you? |
|-------|------|--------------|
| `--team` | `.chief_shared-secrets` | Yes, for everyone |
| `--personal` | `users/<you>/secrets` | Yes; only your password opens it |
| `--local` | `~/.chief_user-secrets` | No; never leaves the host |

- A failing file (wrong password, say) doesn't stop the others; Chief says which one it skipped.
- **You choose the layer** when you create or edit: `chief.secrets_file-edit --personal` (or `--team` / `--local`). With no flag, Chief opens the only file that exists or asks which. Editing a team or personal file offers to commit and push it.
- **Personal secrets in a team repo:** teammates hold a copy of your encrypted file and could try to guess the password offline, so make it long and unique. Anything too sensitive for that belongs in `--local`.
- Saved passwords (`chief.secrets_password-save --personal`, etc.) are per file and per host.

---

## 👥 Team Collaboration

The remote plugins feature enables powerful **team collaboration**:

Chief is designed with teams in mind. Share your bash functions, aliases, and tools across your entire team for consistent development environments.

> **Key Concept**: Chief automatically loads any file ending with `_chief-plugin.sh` from your configured plugin directory. The prefix before `_chief-plugin.sh` becomes the **plugin name** (e.g., `devops_chief-plugin.sh` → plugin name "devops"). This makes it perfect for both existing repositories and new team setups, with easy plugin management via `chief.plugin <name>`.

#### Symlink mode: `chief.plugin <name> <existing-file>`

You can point a plugin at an existing script instead of duplicating it:

```bash
chief.plugin mytools /path/to/your/shared_script.sh
```

Chief creates `mytools_chief-plugin.sh` in the plugins directory as a symlink to that file.

For **remote or shared repositories**, symlink targets must not be machine-specific. When the existing file lives under the **same directory tree** as the plugin symlink (both paths inside the same clone), Chief creates a **relative** symlink so `git clone` on another laptop or server still resolves the link. If the file is outside that tree (for example only under your home directory), Chief falls back to an **absolute** path and warns you—those links break for teammates unless they share the same layout. Prefer keeping linked scripts inside the repo, or add a real `*_chief-plugin.sh` file in the repo.

**Links whose target is missing on a machine:** a plugin symlink can point into a checkout that only some machines have (for example a link into a sibling repo that exists on your laptop but not on servers). Chief skips such a plugin without failing the load. Interactive shells show a yellow warning naming the plugin and its link target, and `chief.reload` lists it as `missing:`. If the plugin is meant to be absent on that machine, disable it there (`chief.plugin disable <name>`, or `CHIEF_CFG_PLUGINS_DISABLED_USER` in that machine's config) and the warning goes away.

Use `chief.plugin -?` for full help, including enable/disable and editor options.

### Two Setup Scenarios

Choose the approach that fits your team's situation:

- **🔄 Scenario A**: Use Existing Repository - Add Chief plugins to your current team repo
- **🆕 Scenario B**: Create New Repository - Start fresh with a dedicated plugins repo

---

## 🔄 Scenario A: Existing Repository

Perfect when you already have a team repository and want to add Chief plugins alongside your existing code.

### 1. Add Plugins to Existing Repo

```bash
# Navigate to your existing team repository
cd ~/your-existing-team-repo

# Create plugins in any subdirectory (or repo root)
mkdir -p tools/bash-plugins  # or scripts/, devops/, etc.

# Create your first team plugin - MUST end with _chief-plugin.sh
# Plugin name will be "devops" (prefix before _chief-plugin.sh)
cat > tools/bash-plugins/devops_chief-plugin.sh << 'EOF'
#!/usr/bin/env bash
# Team DevOps Tools - loaded automatically by Chief

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: $(basename "${BASH_SOURCE[0]}") must be sourced, not executed."
  exit 1
fi

echo "Team DevOps plugin loaded"

function devops.deploy() {
    echo "Deploying with team standards..."
    # Your existing deployment scripts/logic
    ./scripts/deploy.sh "$@"
}

function devops.logs() {
    echo "Fetching application logs..."
    kubectl logs -f deployment/app --tail=100
}

function devops.status() {
    echo "📊 System status check..."
    # Check your services, databases, etc.
}
EOF

# Add more plugins as needed - each must end with _chief-plugin.sh
# Plugin name will be "testing" (prefix before _chief-plugin.sh)
cat > tools/bash-plugins/testing_chief-plugin.sh << 'EOF'
#!/usr/bin/env bash
# Team Testing Tools

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: $(basename "${BASH_SOURCE[0]}") must be sourced, not executed."
  exit 1
fi

echo "Team Testing plugin loaded"

function testing.unit() {
    echo "🧪 Running unit tests..."
    npm test
}

function testing.integration() {
    echo "Running integration tests..."
    ./scripts/integration-tests.sh
}

alias testing.watch='npm run test:watch'
EOF

# Commit to your existing repo
git add tools/bash-plugins/
git commit -m "Add Chief plugins for team automation"
git push origin main
```

### 2. Team Member Configuration

Each team member points Chief to your existing repository:

```bash
# Configure Chief to use your existing team repo
chief.config-set plugins_git_repo "git@github.com:yourteam/existing-repo.git"
chief.config-set plugins_git_branch "main"
chief.config-set plugins_path "$HOME/team-repo"
chief.config-set plugins_git_path "tools/bash-plugins"  # Relative path to plugin files
chief.config-set plugins_git_autoupdate true

# Set to remote LAST - Chief will offer to update plugins when git config is ready
chief.config-set plugins_type remote

# Restart terminal or reload Chief
chief.reload

# Your team functions are now available!
devops.deploy
testing.unit
```

### 3. Plugin File Discovery Rules

Chief automatically discovers and loads files with specific naming:

```bash
# ✓ These files WILL be loaded:
devops_chief-plugin.sh       # Plugin name: "devops"
testing_chief-plugin.sh      # Plugin name: "testing"
monitoring_chief-plugin.sh   # Plugin name: "monitoring"  
k8s_chief-plugin.sh         # Plugin name: "k8s"

# ✗ These files will NOT be loaded:
devops.sh                   # Missing _chief-plugin.sh suffix
testing_plugin.sh           # Missing chief- prefix  
readme.md                   # Not a shell script
utilities.bash              # Wrong file extension
```

**Important**: The prefix before `_chief-plugin.sh` becomes the **plugin name**.

---

## 🆕 Scenario B: New Repository

Perfect when starting fresh with a dedicated plugins repository.

### 1. Create New Team Plugins Repository

```bash
# Create and set up new repository
mkdir my-team-bash-plugins
cd my-team-bash-plugins

# Initialize git
git init
git remote add origin git@github.com:yourteam/team-bash-plugins.git

# Create team plugins
cat > devops_chief-plugin.sh << 'EOF'
#!/usr/bin/env bash
# Team DevOps Tools

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: $(basename "${BASH_SOURCE[0]}") must be sourced, not executed."
  exit 1
fi

echo "Team DevOps plugin loaded"

function devops.deploy() {
    local environment="${1:-staging}"
    echo "Deploying to ${environment}..."
    # Team deployment logic
}

function devops.logs() {
    local service="${1:-app}"
    echo "Fetching logs for ${service}..."
    kubectl logs -f "deployment/${service}" --tail=100
}
EOF

# Add team secrets (encrypted)
chief.secrets_file-edit .chief_shared-secrets
# Add shared environment variables, API keys, etc.

# Commit and push
git add .
git commit -m "Initial team plugins and secrets"
git push -u origin main
```

### 2. Team Member Setup

```bash
# Configure Chief for team repository
chief.config-set plugins_git_repo "git@github.com:yourteam/team-bash-plugins.git"
chief.config-set plugins_path "$HOME/team_plugins"
chief.config-set plugins_git_autoupdate true
chief.config-set plugins_type remote

# Team functions and vault are now available
devops.deploy production
```

---

## Secrets and Vault Configuration

Chief provides two separate mechanisms:

- **Secrets plugin** – Encrypted Bash secrets file (env vars, functions) that you edit and load into your shell. Backends: Ansible Vault or GPG.
- **Vault plugin** – HashiCorp Vault KV: read, write, and list secrets via the Vault CLI. Requires `vault`, `VAULT_ADDR`, and `VAULT_TOKEN` (or `VAULT_TOKEN_FILE`).

### Secrets plugin: creating and loading encrypted files

```bash
# Create team secrets file (encrypted; backend: gpg or ansible)
chief.secrets_file-edit .chief_shared-secrets

# Create personal secrets file
chief.secrets_file-edit ~/.my-personal-secrets

# Load secrets into shell (decrypt and source)
chief.secrets_file-load .chief_shared-secrets
# ...without the "Success" line, e.g. in ~/.bash_profile (errors still show)
chief.secrets_file-load --quiet

# See what this shell loaded, how (manually / by a start-up file) and whether silently
chief.status
chief.secrets_password-status
chief.secrets_file-load ~/.my-personal-secrets
```

- **Backends**: Ansible Vault (`ansible-vault`) or GPG (symmetric AES256). Use `--backend=gpg` or `--backend=ansible` when creating; backend is auto-detected when editing or loading.
- **Password**: Chief takes the first of these that's available. Password file env vars (Ansible: `ANSIBLE_VAULT_PASSWORD_FILE`; GPG: `CHIEF_SECRETS_PASSWORD_FILE`), then a saved password, then a prompt.
- **Saved password (no prompts, no clear-text file)**: `chief.secrets_password-save [file]` asks for the file's password at a prompt (never as an argument, environment variable or piped input), checks that it opens the file, and saves it:
  - **macOS**: in your login Keychain.
  - **Linux desktop**: in the keyring through `secret-tool` (libsecret), when a keyring service is running.
  - **Elsewhere** (for example headless servers): in `~/.chief_secrets-store/` (folder 700), encrypted with a random key kept beside it (600). This is **obfuscation, not protection**: it keeps the password out of casual reads, backups and git, but anyone who can read your account can recover it. Force a store with `--store=keychain` or `--store=file`.
  - `chief.secrets_password-status [file]` shows where the password will come from; `chief.secrets_password-remove [file]` forgets it. Saved passwords are tied to the file's path, so save again after moving the file. `--rekey` updates a saved GPG password automatically; for Ansible Vault (which asks for the new password itself) it removes the outdated one and tells you to save the new one.
- **Changing the password (re-key)**: `chief.secrets_file-edit <file> --rekey` changes the password of an existing file without opening the editor, for both backends. It asks for the current password (or reads the password file above), then the new one twice; `--new-password-file=PATH` reads the new one from a file instead. If anything fails, the file is left as it was. Afterwards, update any password file that still holds the old password. For a shared team file, tell your team the new password.
- **Layers**: with a shared repo there are team, personal and host secrets, and `chief.secrets_file-load` loads all that exist. See [Shared repo: Secrets](#secrets-team-and-personal-and-this-host).
- **Team secrets**: `CHIEF_CFG_PLUGINS_PATH/.chief_shared-secrets` (shared). Legacy name `.chief_shared-vault` is deprecated.
- **Personal secrets**: `~/.chief_user-secrets` (or legacy `~/.chief_user-vault`).

### Vault plugin: HashiCorp Vault KV

```bash
# Read a secret (or one key)
chief.vault_read-secret secret/data/myapp
chief.vault_read-secret secret/data/myapp password

# Write a secret
chief.vault_write-secret secret/data/myapp api_key=xxx user=admin

# List keys in a secret or paths in a folder
chief.vault_list-secrets secret/myapp
chief.vault_list-secrets secret/
```

- **Requirements**: `vault` CLI, `VAULT_ADDR`, `VAULT_TOKEN` (or `VAULT_TOKEN_FILE`). Use `chief.vault_read-secret -?`, `chief.vault_write-secret -?`, `chief.vault_list-secrets -?` for full help.

---

## Configuration Examples

### Developer Workstation

```bash
# Enable all productivity features
chief.config-set prompt true
chief.config-set git_prompt true
chief.config-set multiline_prompt true
chief.config-set colored_ls true
chief.config-set ssh_keys_path "$HOME/.ssh"
chief.config-set alias "cf"
```

### Server/CI Environment

```bash
# Minimal configuration for automation
chief.config-set banner false
chief.config-set hints false
chief.config-set prompt false
chief.config-set config_set_interactive false
chief.config-set plugins_git_autoupdate true
```

### Team Lead Setup

```bash
# Full team collaboration features
chief.config-set plugins_type "remote"
chief.config-set plugins_git_repo "git@github.com:yourteam/plugins.git"
chief.config-set plugins_git_autoupdate true
chief.config-set autocheck_updates true
```

---

## Troubleshooting Configuration

### Common Configuration Issues

```bash
# Show the settings in your config
grep "^CHIEF_CFG_" ~/.chief_config.sh

# Reset configuration to defaults
cp ~/.chief/templates/chief_config_template.sh ~/.chief_config.sh

# Validate configuration syntax
bash -n ~/.chief_config.sh

# Update configuration after upgrade
chief.config-update
```

### Plugin Sync Issues

```bash
# Check plugin repository status
cd "$CHIEF_CFG_PLUGINS_PATH"
git status

# Force update plugins
chief.plugins-update --force

# Reset plugin repository
rm -rf "$CHIEF_CFG_PLUGINS_PATH"
chief.reload  # Will re-clone repository
```

---

## Next Steps

- **[Plugin Development](plugin-development.html)** - Create custom team plugins
- **[User Guide](user-guide.html)** - Learn core Chief features
- **[Reference](reference.html)** - Complete command reference

---

[← Back to Home](https://chief.randyo.dev/)
