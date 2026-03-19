---
layout: default
title: Configuration
description: "Advanced configuration, multi-system setup, and team collaboration"
---

[← Back to Home](https://chief.reonetlabs.us/)

# Configuration

Advanced configuration options, multi-system setup, and team collaboration workflows.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Configuration Management

Chief is highly customizable. Use `chief.config` to edit the config file or `chief.config_set <option> <value>` for direct command-line configuration.

**Interactive Behavior:** By default, `chief.config_set` prompts for confirmation before modifying your configuration file. Use `--yes` (or `-y`) to skip prompts for scripting.

### Basic Configuration Commands

```bash
# Edit configuration file
chief.config

# Set configuration variables directly (use option name without CHIEF_CFG_ prefix)
chief.config_set banner false         # Sets CHIEF_CFG_BANNER=false (prompts for confirmation)
chief.config_set banner=false         # Same as above using key=value syntax
chief.config_set --yes prompt true    # Sets CHIEF_CFG_PROMPT=true (no prompt)  
chief.config_set colored_ls=true      # Sets CHIEF_CFG_COLORED_LS=true (prompts for confirmation)

# List all configuration variables and current values  
chief.config_set --list

# Update configuration with new template options (perfect for upgrades)
chief.config_update                   # Add missing options, handle renames, preserve customizations
chief.config_update --dry-run         # Preview changes without applying them

# Disable interactive prompts globally
chief.config_set config_set_interactive false
```

---

## Configuration Options

### Core Settings

| Configuration | Default | Description |
|---------------|---------|-------------|
| `CHIEF_CFG_BANNER` | `true` | Show startup banner |
| `CHIEF_CFG_HINTS` | `true` | Display helpful tips on startup |
| `CHIEF_CFG_PROMPT` | `false` | Use Chief's custom prompt (keep disabled if using Oh My Bash/Starship) |
| `CHIEF_CFG_COLORED_PROMPT` | `true` | Colorize the prompt |
| `CHIEF_CFG_GIT_PROMPT` | `true` | Git-aware prompt features |
| `CHIEF_CFG_MULTILINE_PROMPT` | `false` | Enable multiline prompt display |
| `CHIEF_CFG_SHORT_PATH` | `false` | Show only current directory name in prompt |
| `CHIEF_CFG_COLORED_LS` | `false` | Colorize ls command output |
| `CHIEF_CFG_CONFIG_SET_INTERACTIVE` | `true` | Prompt for confirmation in `chief.config_set` |
| `CHIEF_CFG_CONFIG_UPDATE_BACKUP` | `true` | Create backups during config updates (only when changes made) |
| `CHIEF_CFG_PLUGINS_TYPE` | `"local"` | Use `"local"` or `"remote"` plugins |
| `CHIEF_CFG_SSH_KEYS_PATH` | _unset_ | Auto-load SSH keys from path |
| `CHIEF_CFG_ALIAS` | _unset_ | Create short alias (e.g., `"cf"`) |
| `CHIEF_CFG_AUTOCHECK_UPDATES` | `false` | Check for updates on startup |
| `CHIEF_CFG_UPDATE_BRANCH` | `"main"` | Branch to track for updates: any valid Git branch (⚠ non-main may be unstable) |

### Environment Variables

These are environment variables (not configuration settings) that affect Chief's behavior:

| Variable | Default | Description |
|----------|---------|-------------|
| `CHIEF_HOST` | _unset_ | Override hostname display in prompt. Useful for marking systems without changing hostname. |

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
| `CHIEF_CFG_PLUGINS_DISABLED_CORE` | Comma- or space-separated list of **core** plugin names to skip loading (e.g. `aws,git,ssl` or `aws git ssl`). Empty = all core plugins enabled. |
| `CHIEF_CFG_PLUGINS_DISABLED_USER` | Comma- or space-separated list of **user** plugin names to skip loading (e.g. `bc,lab` or `bc lab`). Empty = all user plugins enabled. |

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
# In chief.config or via chief.config_set:
CHIEF_CFG_PLUGINS_DISABLED_CORE="aws,ssl"    # Skip core aws and ssl
CHIEF_CFG_PLUGINS_DISABLED_USER="lab"       # Skip user plugin "lab"
```

---

## Advanced Features

### SSH Key Auto-loading

```bash
# In chief.config, set:
CHIEF_CFG_SSH_KEYS_PATH="$HOME/.ssh"

# Chief automatically loads all *.key files
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
# 1. Install Chief (one command)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"

# 2. Configure your plugin repository (replace with your repo)
chief.config_set -y PLUGINS_GIT_REPO="git@github.com:yourusername/my-plugins.git"
chief.config_set -y PLUGINS_PATH="${HOME}/chief_plugins"
chief.config_set -y PLUGINS_GIT_BRANCH="main"
chief.config_set -y PLUGINS_GIT_PATH="bash/plugins"   # or "" for repo root, this is plugins path relative to PLUGINS_PATH
chief.config_set -y PLUGINS_GIT_AUTOUPDATE="false"    # manual updates
chief.config_set -y PLUGINS_TYPE="remote"             # Enable remote sync

# 3. (Optional) Enable multi-line prompt, useful when current working dir is deep.
chief.config_set -y MULTILINE_PROMPT=true 

# 4. (Optional) Load your encrypted secrets (if exists)
chief.secrets_file-load  # Team secrets (.chief_shared-secrets - if exists)
chief.secrets_file-load ~/.my-personal-secrets     # Personal secrets
```

For detailed secrets and vault setup, see: [Secrets and Vault Configuration](configuration.html#secrets-and-vault-configuration)

#### Result

- ✓ **Same plugins everywhere**: Functions, aliases, and tools sync across laptop, server, CI/CD
- ✓ **Encrypted secrets**: Secrets files travel with your setup (team + personal)
- ✓ **Zero reconfiguration**: New systems work identically after this setup
- ✓ **Version controlled**: Track changes to your shell environment

#### Daily Workflow

```bash
chief.plugins_update           # Get latest team plugins
chief.secrets_file-load          # Load secrets when needed
chief.plugin mytools           # Edit/create plugins
chief.whereis my_function      # Find any function instantly
```

---

## 👥 Team Collaboration

The remote plugins feature enables powerful **team collaboration**:

Chief is designed with teams in mind. Share your bash functions, aliases, and tools across your entire team for consistent development environments.

> **Key Concept**: Chief automatically loads any file ending with `_chief-plugin.sh` from your configured plugin directory. The prefix before `_chief-plugin.sh` becomes the **plugin name** (e.g., `devops_chief-plugin.sh` → plugin name "devops"). This makes it perfect for both existing repositories and new team setups, with easy plugin management via `chief.plugin <name>`.

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
chief.config_set plugins_git_repo "git@github.com:yourteam/existing-repo.git"
chief.config_set plugins_git_branch "main"
chief.config_set plugins_path "$HOME/team-repo"
chief.config_set plugins_git_path "tools/bash-plugins"  # Relative path to plugin files
chief.config_set plugins_git_autoupdate true

# Set to remote LAST - Chief will offer to update plugins when git config is ready
chief.config_set plugins_type remote

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
chief.config_set plugins_git_repo "git@github.com:yourteam/team-bash-plugins.git"
chief.config_set plugins_path "$HOME/team_plugins"
chief.config_set plugins_git_autoupdate true
chief.config_set plugins_type remote

# Team functions and vault are now available
devops.deploy production
```

---

## Secrets and Vault Configuration

### Creating and Managing Secrets Files

```bash
# Create team secrets file (encrypted; backend: gpg or ansible)
chief.secrets_file-edit .chief_shared-secrets

# Create personal secrets file
chief.secrets_file-edit ~/.my-personal-secrets

# Load secrets into shell (decrypt and source)
chief.secrets_file-load .chief_shared-secrets
chief.secrets_file-load ~/.my-personal-secrets
```

- **Backends**: Ansible Vault (`ansible-vault`) or GPG (symmetric AES256). Use `--backend=gpg` or `--backend=ansible` when creating; set `CHIEF_SECRETS_PASSWORD_FILE` for GPG auto-decrypt.
- **Team secrets**: `CHIEF_CFG_PLUGINS_PATH/.chief_shared-secrets` (shared). Legacy name `.chief_shared-vault` is still supported but deprecated.
- **Personal secrets**: `~/.chief_user-secrets` (or legacy `~/.chief_user-vault`).
- **HashiCorp Vault**: Use `chief.vault_read-secret` and `chief.vault_write-secret` with `VAULT_ADDR` and `VAULT_TOKEN`.

---

## Configuration Examples

### Developer Workstation

```bash
# Enable all productivity features
chief.config_set prompt true
chief.config_set git_prompt true
chief.config_set multiline_prompt true
chief.config_set colored_ls true
chief.config_set ssh_keys_path "$HOME/.ssh"
chief.config_set alias "cf"
```

### Server/CI Environment

```bash
# Minimal configuration for automation
chief.config_set banner false
chief.config_set hints false
chief.config_set prompt false
chief.config_set config_set_interactive false
chief.config_set plugins_git_autoupdate true
```

### Team Lead Setup

```bash
# Full team collaboration features
chief.config_set plugins_type "remote"
chief.config_set plugins_git_repo "git@github.com:yourteam/plugins.git"
chief.config_set plugins_git_autoupdate true
chief.config_set autocheck_updates true
```

---

## Troubleshooting Configuration

### Common Configuration Issues

```bash
# Check current configuration
chief.config_show

# Reset configuration to defaults
cp ~/.chief/templates/chief_config_template.sh ~/.chief_config.sh

# Validate configuration syntax
bash -n ~/.chief_config.sh

# Update configuration after upgrade
chief.config_update
```

### Plugin Sync Issues

```bash
# Check plugin repository status
cd "$CHIEF_CFG_PLUGINS_PATH"
git status

# Force update plugins
chief.plugins_update --force

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

[← Back to Home](https://chief.reonetlabs.us/)
