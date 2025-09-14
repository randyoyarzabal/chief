# 🚀 Chief - Bash Plugin Manager & Terminal Enhancement Tool

[![GitHub release](https://img.shields.io/badge/Download-Release%20v2.1.2-lightgrey.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![GitHub commits (since latest release)](https://img.shields.io/github/commits-since/randyoyarzabal/chief/latest.svg?style=social)](https://github.com/randyoyarzabal/chief/commits/master)

> **Transform your terminal experience with organized bash functions, aliases, and a powerful plugin system.**

Chief is a lightweight, powerful Bash library system that helps you organize your shell environment through a plugin-based architecture. Think of it as a package manager for your bash functions, aliases, and tools.

## 📦 Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/dev/tools/install.sh)"
```

**That's it!** Restart your terminal and start using Chief.

> **🛡️ Safe for Zsh Users:** Chief only affects your Bash shell environment. If you're currently using Zsh, Oh My Zsh, or any other shell, Chief won't interfere with your existing setup. It only activates when you explicitly run `bash` or switch to a Bash session.

> **💡 Using Oh My Bash or Custom Prompts?** Chief's prompt customizations are **disabled by default** (`CHIEF_CFG_PROMPT=false`). If you have Oh My Bash, Starship, or other prompt tools, keep this setting disabled to avoid conflicts.

## ✨ Key Features Highlight

- 🔐 **Vault System** - Encrypt sensitive environment variables with `chief.vault_*` (requires ansible-vault)  
  Store secrets safely, load into memory when needed

- 🌐 **Remote Plugin Sync** - Share plugins across teams via Git repositories (`CHIEF_CFG_PLUGINS_TYPE="remote"`)  
  Automatic updates and version control for your shell tools

- 🎨 **Git-Aware Prompts** - Beautiful, intelligent prompts with branch status (`CHIEF_CFG_PROMPT=true`)  
  See repository info at a glance without cluttering your terminal

- 🔍 **Instant Discovery** - Find any function, alias, or variable with `chief.whereis`  
  Never lose track of where your tools are defined

- 🚀 **Zero Disruption** - Only affects Bash, won't interfere with existing setups  
  Safe for Zsh, Oh My Zsh, and custom prompt users

- 📦 **Plugin Architecture** - Organize your tools into reusable, shareable plugins (`chief.plugin`)  
  Clean, modular approach to shell environment management  

👉 **[See complete feature list and benefits ↓](#-why-choose-chief)**

## 📑 Table of Contents

- [📦 Installation](#-installation)
- [🤝 Why Choose Chief?](#-why-choose-chief)
- [⚡ Quick Start](#-quick-start)
- [📖 Help System](#-help-system)
- [🎯 What is Chief?](#-what-is-chief)
- [📋 Requirements](#-requirements)
- [🎪 What You Get Out of the Box](#-what-you-get-out-of-the-box)
- [💡 Common Use Cases](#-common-use-cases)
- [👥 Team Collaboration](#-team-collaboration)
- [🛠️ Configuration Options](#️-configuration-options)
- [📚 Plugin Development](#-plugin-development)
- [🌟 Advanced Features](#-advanced-features)
- [🔧 Built-in Plugins](#-built-in-plugins)
- [📖 Examples & Tutorials](#-examples--tutorials)
- [🐚 Shell Compatibility](#-shell-compatibility)
- [🛟 Troubleshooting](#-troubleshooting)
- [🤖 Contributing](#-contributing)
- [📄 License](#-license)

---

## 🤝 Why Choose Chief?

### ✅ **Safe & Non-Disruptive**

- **Bash-only installation** - Won't interfere with Zsh, Fish, or other shells
- **Zero impact on existing setups** - Your Oh My Zsh, custom prompts remain untouched
- **Only activates in Bash** - Chief functions only available when you're in a Bash session
- Easy to uninstall completely

### ✅ **Plugin System & Organization**

- 📦 **Organize functions & aliases** - Group related tools into reusable plugins
- 🔄 **Remote sync** - Sync plugins across machines via Git repositories
- 🔍 **Find anything instantly** - `chief.whereis` locates any function or alias
- 📂 **Version control** - Track your shell environment changes

### ✅ **Enhanced Terminal Experience**

- 🎨 **Git-aware prompts** - Colorized prompts that actually look good
- 🔐 **SSH key management** - Auto-load your SSH keys with intelligent handling
- 🛠️ **Built-in tools** - Utilities for Git, SSL, OpenShift, Vault, and AWS
- ⚡ **Auto-reload** - No more `source ~/.bash_profile` after edits

### ✅ **Team & Productivity**

- 👥 **Team collaboration** - Share plugins via Git and standardize tooling across teams
- 📚 **Built-in help** - Every command has help (`chief.* -?`)
- 🔗 **Tab completion** - All Chief commands are tab-completable
- 🚀 **Instant onboarding** - New team members get standardized tools immediately
- 🔄 **Version control** - Track and manage team tool changes over time

## ⚡ Quick Start

```bash
# Get comprehensive help
chief.help

# Quick tips and workflow
chief.hints

# Explore all commands
chief.[tab][tab]

# Create your first plugin
chief.plugin mytools

# Configure Chief (editor or direct commands)
chief.config                    # Opens editor
chief.config_set prompt true    # Direct config (option without CHIEF_CFG_ prefix)

# Edit shell files with auto-reload
chief.bash_profile

# Find any function or alias
chief.whereis my_function

# Uninstall Chief completely (with confirmation prompts)
chief.uninstall
```

### 🔧 Need More Options?

<details>
<summary>Manual installation and environment checks</summary>

#### Manual Installation
```bash
# 1. Clone the repository
git clone --depth=1 https://github.com/randyoyarzabal/chief.git ~/.chief

# 2. Copy config template
cp ~/.chief/templates/chief_config_template.sh ~/.chief_config.sh

# 3. Add to your shell config
echo 'export CHIEF_CONFIG="$HOME/.chief_config.sh"' >> ~/.bash_profile
echo 'export CHIEF_PATH="$HOME/.chief"' >> ~/.bash_profile
echo 'source ${CHIEF_PATH}/chief.sh' >> ~/.bash_profile

# 4. Restart terminal or source config
source ~/.bash_profile
```

#### Environment Check
```bash
# Verify your environment meets requirements
bash --version    # Should be 4.0+
git --version     # Required for installation
ansible-vault --version 2>/dev/null || echo "Ansible not installed (optional)"
oc version --client 2>/dev/null || echo "OpenShift CLI not installed (optional)"
```

#### Uninstall
```bash
# Method 1: Using Chief command (easiest if Chief is working)
chief.uninstall

# Method 2: One-liner (works from anywhere)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/uninstall.sh)"
```

**What happens during uninstall:**
- ✅ **Installation directory** (`~/.chief`) is completely removed
- ✅ **Configuration file** is backed up as `~/.chief_config.sh.backup` then removed
- ✅ **Shell configuration** (`~/.bash_profile`) is cleaned up automatically
- ✅ **Environment variables** (CHIEF_PATH, CHIEF_CONFIG) are removed from shell
- ✅ **Custom plugins directory** remains untouched (if different from `~/.chief`)
- ✅ **Safe operation** - Changes directory before removal to avoid conflicts

> **🛡️ Safe Uninstall**: Your personal plugins, shell customizations outside Chief, and other configurations remain completely untouched.

</details>

## 📖 Help System

Chief provides a comprehensive, multi-layered help system to help you discover and use commands effectively.

### 🎯 `chief.help` - Comprehensive Help

The main help system with categorized, searchable documentation:

```bash
chief.help                    # Full help with banner and categories  
chief.help commands           # Core Chief commands reference
chief.help plugins            # Plugin management and available commands
chief.help config             # Configuration options and current settings
chief.help --compact          # Quick command reference
chief.help --search <term>    # Search for commands containing term
```

**Features:**

- **Dynamic content** - Shows your actual loaded plugins and current settings
- **Categorized help** - Organized by commands, plugins, configuration
- **Search functionality** - Find commands by keyword
- **Status information** - Current Chief status, plugin count, configuration
- **Quick reference mode** - Compact view for experienced users

### 💡 `chief.hints` - Quick Tips

Compact workflow tips and essential command reference:

```bash
chief.hints                   # Quick tips and workflow hints
chief.hints --banner          # Show tips with Chief banner
```

**Perfect for:**

- Daily workflow reminders
- Essential command quick reference  
- New user onboarding
- Plugin status at-a-glance

### 🔍 Command-Specific Help

Every Chief command has detailed help documentation:

```bash
chief.config -?               # Help for any command
chief.plugin -?               # Detailed usage and examples
chief.whereis -?              # Function-specific documentation
```

### 🚀 Discovery Methods

Multiple ways to explore available commands:

| Method | Purpose | Example |
|--------|---------|---------|
| `chief.[tab][tab]` | Bash completion | See all available commands |
| `chief.help --search git` | Search commands | Find git-related functions |
| `chief.help plugins` | Plugin commands | See what plugins provide |
| `chief.whereis <name>` | Find definitions | Locate where functions are defined |

## 🎯 What is Chief?

Chief transforms your terminal into a powerful, organized workspace. It's like having a package manager for your bash functions, aliases, and tools - but better.

**Core Philosophy:** Keep your shell environment clean, organized, and team-friendly without breaking existing setups.

## 📋 Requirements

### System Requirements

- **Bash 4.0+** - Chief requires modern bash features (associative arrays, etc.)
- **Git** - Required for installation and plugin management
- **Unix-like OS** - Linux, macOS, WSL, or Cygwin

### Optional Dependencies

- **Ansible Core 2.9+** - Required only for Vault-related functions (`chief.vault.*`)
  - `ansible-vault` command must be in PATH
  - Used for encrypting/decrypting secrets in Chief configurations
  - If not installed, vault functions will show helpful error messages

- **OpenShift CLI (oc)** - Required only for OpenShift-related functions (`chief.oc.*`)
  - `oc` command must be in PATH
  - Used for OpenShift cluster operations and authentication
  - If not installed, OpenShift functions will show helpful error messages

### Version Compatibility

| Component | Minimum Version | Recommended | Notes |
|-----------|----------------|-------------|-------|
| Bash | 4.0 | 5.0+ | Associative arrays, process substitution |
| Git | 2.0 | Latest | Clone, fetch, submodules |
| Ansible Core | 2.9 | Latest | Optional - vault functions only |
| OpenShift CLI (oc) | 4.0 | Latest | Optional - OpenShift functions only |

### Check Your Environment

```bash
# Check bash version
bash --version

# Check if git is available
git --version

# Check ansible (optional)
ansible-vault --version 2>/dev/null || echo "Ansible not installed (optional)"

# Check OpenShift CLI (optional)
oc version --client 2>/dev/null || echo "OpenShift CLI not installed (optional)"
```

## 🎪 What You Get Out of the Box

### Plugin Management

```bash
# Create your first plugin
chief.plugin mytools

# List all plugins
chief.plugin -?

# Find where a function is defined
chief.whereis my_function
```

### Terminal Enhancements

```bash
# Configure your experience
chief.config                     # Edit config file
chief.config_set banner false    # Quick config (sets CHIEF_CFG_BANNER=false)

# Update Chief
chief.update

# Edit shell files with auto-reload
chief.bash_profile  # Edit .bash_profile
```

### Built-in Tools (Available Immediately)

- **Git**: Enhanced git commands and completion
- **SSH**: Automatic key loading and management
- **SSL**: Certificate inspection and validation tools
- **OpenShift**: Container platform utilities (requires `oc` CLI)
- **Vault**: HashiCorp Vault integration
- **AWS**: Cloud service helpers

## 💡 Common Use Cases

### 1. Organize Your Functions

**Before:** Functions scattered across multiple files

```bash
# Hard to find, no organization
function deploy() { ... }
function backup() { ... }
function cleanup() { ... }
```

**After:** Clean plugin-based organization

```bash
# ~/chief_plugins/devops_chief-plugin.sh
function devops.deploy() { ... }
function devops.backup() { ... }
function devops.cleanup() { ... }
```

### 2. Sync Configuration Across Machines

```bash
# Set up remote plugin sync
chief.config
# Set CHIEF_CFG_PLUGINS_TYPE="remote"
# Set CHIEF_CFG_PLUGINS_GIT_REPO="git@github.com:youruser/bash-plugins.git"

# Now your plugins sync across all your machines!
```

### 3. Enhanced Development Workflow

```bash
# Create project-specific environments
chief.plugin myproject

# Auto-reload configurations when files change
chief.bash_profile  # Edit and auto-reloads

# Find any function or command instantly
chief.whereis deploy  # Shows all deploy functions across plugins
```

## 👥 Team Collaboration

Chief is designed with teams in mind. Share your bash functions, aliases, and tools across your entire team for consistent development environments.

### 🚀 Quick Team Setup

```bash
# 1. Create a team plugin repository
git init my-team-plugins
cd my-team-plugins

# 2. Create team plugins
mkdir plugins
echo '#!/usr/bin/env bash
# Team DevOps Tools

function team.deploy() {
    echo "Deploying with team standards..."
    # Your team deployment logic
}

function team.test() {
    echo "Running team test suite..."
    # Your team testing logic
}' > plugins/devops_chief-plugin.sh

# 3. Commit and push
git add .
git commit -m "Initial team plugins"
git push origin main
```

### 🔧 Team Member Setup

Each team member configures Chief to use the shared repository:

```bash
# Configure Chief for remote plugins
chief.config

# Set these values:
# CHIEF_CFG_PLUGINS_TYPE="remote"
# CHIEF_CFG_PLUGINS_GIT_REPO="git@github.com:yourteam/bash-plugins.git"
# CHIEF_CFG_PLUGINS_GIT_BRANCH="main"
# CHIEF_CFG_PLUGINS_GIT_PATH="$HOME/team-plugins"
# CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE="true"

# Restart terminal - team plugins are now available!
```

### 📦 Managing Team Plugins

```bash
# Update team plugins to latest version
chief.plugins_update

# Create new team plugin
chief.plugin teamtools

# Check which plugins are loaded
chief.plugin -?

# Find team functions
chief.whereis team.deploy
```

### 🔒 Security Best Practices

> **⚠️ Important for Team Sharing**: When sharing plugins with your team, sensitive information will be visible to all team members.

#### ✅ **Safe to Share (in team plugins):**
- Functions and aliases
- General configuration templates
- Team-wide environment variables
- Shared tool configurations

#### 🚫 **Keep Private (in personal ~/.bash_profile):**
- `CHIEF_OC_USERNAME` - Personal OpenShift credentials
- `CHIEF_SECRETS_FILE` - Path to personal encrypted secrets
- `VAULT_ADDR`, `VAULT_TOKEN` - Personal Vault credentials
- API keys, tokens, passwords
- Personal file paths and preferences

#### 📁 **Recommended Structure:**

```
team-plugins/
├── plugins/
│   ├── devops_chief-plugin.sh     # Deployment tools
│   ├── testing_chief-plugin.sh    # Test automation
│   ├── docker_chief-plugin.sh     # Container tools
│   └── k8s_chief-plugin.sh        # Kubernetes helpers
├── templates/
│   └── personal_config_template.sh # Template for personal settings
└── README.md                      # Team onboarding guide
```

### 🌟 Team Workflow Benefits

#### **Standardized Tooling**
- Everyone uses the same functions and aliases
- Consistent deployment and testing procedures
- Shared knowledge base of team practices

#### **Easy Onboarding**
- New team members get all tools instantly
- No manual setup of individual development environments
- Documentation lives with the code

#### **Version Control for Shell Environment**
- Track changes to team tools over time
- Roll back problematic updates
- Review changes before deployment

#### **Cross-Machine Consistency**
- Same tools on laptop, server, and CI/CD
- No "works on my machine" problems
- Shared configuration across all environments

### 🔄 Advanced Team Features

#### **Multiple Plugin Sources**
```bash
# Mix team plugins with personal plugins
CHIEF_CFG_PLUGINS_TYPE="remote"              # Use team repo
CHIEF_CFG_PLUGINS="/path/to/personal/plugins" # Plus personal plugins
```

#### **Branched Development**
```bash
# Use development branch for testing
CHIEF_CFG_PLUGINS_GIT_BRANCH="development"

# Switch back to stable
CHIEF_CFG_PLUGINS_GIT_BRANCH="main"
chief.plugins_update
```

#### **Selective Plugin Loading**
```bash
# Team can organize plugins by category
CHIEF_CFG_PLUGINS_GIT_PATH="$HOME/team-plugins/backend"  # Backend tools only
CHIEF_CFG_PLUGINS_GIT_PATH="$HOME/team-plugins/frontend" # Frontend tools only
```

## 🛠️ Configuration Options

Chief is highly customizable. Use `chief.config` to edit the config file or `chief.config_set <option> <value>` for direct command-line configuration.

**Interactive Behavior:** By default, `chief.config_set` prompts for confirmation before modifying your configuration file. Use `--yes` (or `-y`) to skip prompts for scripting.

```bash
# Edit configuration file
chief.config

# Set configuration variables directly (use option name without CHIEF_CFG_ prefix)
chief.config_set banner false         # Sets CHIEF_CFG_BANNER=false (prompts for confirmation)
chief.config_set --yes prompt true    # Sets CHIEF_CFG_PROMPT=true (no prompt)  
chief.config_set colored_ls true      # Sets CHIEF_CFG_COLORED_LS=true (prompts for confirmation)

# List all configuration variables and current values  
chief.config_set --list

# Disable interactive prompts globally
chief.config_set config_set_interactive false
```

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
| `CHIEF_CFG_PLUGINS_TYPE` | `"local"` | Use `"local"` or `"remote"` plugins |
| `CHIEF_CFG_SSH_KEYS_PATH` | _unset_ | Auto-load SSH keys from path |
| `CHIEF_CFG_ALIAS` | _unset_ | Create short alias (e.g., `"cf"`) |
| `CHIEF_CFG_AUTOCHECK_UPDATES` | `false` | Check for updates on startup |

### Plugin Configuration
| Configuration | Description |
|---------------|-------------|
| `CHIEF_CFG_PLUGINS_GIT_REPO` | Remote Git repository URL for plugins |
| `CHIEF_CFG_PLUGINS_GIT_BRANCH` | Git branch to use (default: "main") |
| `CHIEF_CFG_PLUGINS_GIT_PATH` | Local path for cloned repository |
| `CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE` | Auto-update plugins on startup |

## 🔧 Built-in Plugins

Chief comes with several useful plugins ready to use:

| Plugin | Commands Available | Purpose |
|--------|-------------------|---------|
| **Git** | `chief.git_*` | Enhanced git operations, branch management |
| **SSH** | `chief.ssh_*` | SSH key management, connection helpers |
| **AWS** | `chief.aws_*` | AWS credential management, S3 operations |
| **OpenShift** | `chief.oc_*` | Container platform operations (requires `oc` CLI) |
| **Vault** | `chief.vault_*` | HashiCorp Vault secret management |
| **Python** | `chief.python_*` | Python environment and tool helpers |
| **ETC** | `chief.etc_*` | Miscellaneous system utilities |

### Example Commands

```bash
# Git operations
chief.git_branch_cleanup    # Remove merged branches
chief.git_commit_stats     # Show commit statistics

# SSH management
chief.ssh_load_keys        # Load SSH keys
chief.ssh_test_connection  # Test SSH connections

# AWS helpers  
chief.aws_profile_switch   # Switch AWS profiles
chief.aws_s3_sync         # S3 synchronization

# System utilities
chief.etc_spinner         # Show progress spinner
chief.etc_confirm         # Interactive confirmation prompts
```

## 📚 Plugin Development

### Creating a Plugin

```bash
# Create a new plugin
chief.plugin myproject

# This creates ~/chief_plugins/myproject_chief-plugin.sh
# Edit it to add your functions:
```

### Plugin Template

```bash
#!/usr/bin/env bash
# Your custom plugin

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: $(basename "${BASH_SOURCE[0]}") must be sourced, not executed."
  exit 1
fi

echo "Chief plugin: myproject loaded."

# Your functions
function myproject.deploy() {
    echo "Deploying project..."
    # Your deployment logic
}

function myproject.backup() {
    echo "Backing up project..."
    # Your backup logic
}

# Your aliases
alias myproject.status='git status && docker ps'
alias myproject.logs='tail -f /var/log/myproject.log'
```

### Plugin Naming Convention

- File name: `{plugin-name}_chief-plugin.sh`
- Functions: `{plugin-name}.function_name`
- Place in: `~/chief_plugins/` directory

## 🌟 Advanced Features

### SSH Key Auto-loading

```bash
# In chief.config, set:
CHIEF_CFG_SSH_KEYS_PATH="$HOME/.ssh"

# Chief automatically loads all *.key files
# Supports RSA, ed25519, and other key types
# Use symlinks for selective loading (e.g., ln -s id_rsa mykey.key)
```

### Custom Prompt Features

> **⚠️ Important:** Only enable Chief's prompt if you're **not** using Oh My Bash, Starship, or other prompt customization tools. Chief's prompt is **disabled by default** to prevent conflicts.

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

## 📦 Installation Methods

### Method 1: Quick Install (Recommended)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

> **Note:** This installation only affects your Bash environment. Your current shell (Zsh, Fish, etc.) and any custom configurations remain completely untouched.

### Method 2: Manual Install

```bash
# 1. Clone the repository
git clone --depth=1 https://github.com/randyoyarzabal/chief.git ~/.chief

# 2. Copy configuration template
cp ~/.chief/templates/chief_config_template.sh ~/.chief_config.sh

# 3. Add to shell config file
echo 'export CHIEF_CONFIG="$HOME/.chief_config.sh"' >> ~/.bash_profile
echo 'export CHIEF_PATH="$HOME/.chief"' >> ~/.bash_profile
echo 'source ${CHIEF_PATH}/chief.sh' >> ~/.bash_profile

# 4. Restart terminal
```

### Method 3: Library-Only Usage
```bash
# Use Chief's functions without full setup
source ~/.chief/chief.sh --lib-only
```



## ⚡ Quick Start Guide

```bash
# Get comprehensive help system
chief.help                    # Full help with categories
chief.help commands           # Core commands only
chief.help plugins            # Plugin management  
chief.help config             # Configuration options
chief.help --compact          # Quick reference
chief.help --search git       # Search for git commands

# Quick tips and workflow hints
chief.hints                   # Compact tips
chief.hints --banner          # Tips with banner

# Explore all commands
chief.[tab][tab]

# Get help for any command
chief.update -?

# Find where any function/alias is defined
chief.whereis my_function

# Edit and auto-reload your bashrc
chief.bashrc

# Edit and auto-reload your bash_profile
chief.bash_profile

# Create/edit plugins instantly
chief.plugin mytools

# Set a shorter alias for Chief commands
# In chief.config: CHIEF_CFG_ALIAS="cf"
# Now use: cf.config, cf.plugin, etc.
```

## 🐚 Shell Compatibility

Chief is designed specifically for **Bash** and won't interfere with other shells:

### Bash Integration

- **Isolated to Bash only** - No impact on Zsh, Fish, or other shell environments
- Full compatibility with existing `.bash_profile` files
- Git-aware prompts using `__git_ps1` (when enabled)
- Tab completion via `complete` builtin
- **Works alongside Oh My Bash** - Chief's prompt is disabled by default to prevent conflicts

### Shell Isolation

- **Chief only loads in Bash sessions** - Your default shell remains unchanged
- **Zsh users safe** - Oh My Zsh, custom prompts, and plugins remain untouched
- **Per-shell activation** - Switch to bash when you want Chief features
- **Clean separation** - No cross-shell pollution or conflicts

### Features

- Function introspection uses Bash methods
- Prompt systems use shell-native features
- Colors and escaping adjust automatically
- Cross-shell execution prevention works everywhere

## 📖 Examples & Tutorials

### Example 1: DevOps Plugin

```bash
# Create a DevOps plugin
chief.plugin devops

# Add functions like:
function devops.docker_cleanup() {
    docker system prune -f
    docker volume prune -f
}

function devops.k8s_pods() {
    kubectl get pods --all-namespaces
}
```

### Example 2: Project Plugin
```bash
# Create project-specific plugin
chief.plugin myapp

function myapp.deploy() {
    cd ~/projects/myapp
    ./deploy.sh production
}

function myapp.logs() {
    tail -f ~/projects/myapp/logs/app.log
}
```

## 🛟 Troubleshooting

### Common Issues

#### Q: Chief commands not found after installation

```bash
# Solution: Restart terminal or source config file
source ~/.bash_profile
```

#### Q: "Bad substitution" or "Syntax error" messages

```bash
# Check bash version - Chief requires Bash 4.0+
bash --version

# If using older bash (like macOS default), upgrade:
# macOS: brew install bash
# Linux: Update your package manager
```

#### Q: Vault functions not working

```bash
# Check if ansible is installed (optional dependency)
ansible-vault --version

# Install if needed:
# macOS: brew install ansible
# Linux: pip3 install ansible-core
```

#### Q: OpenShift functions not working

```bash
# Check if OpenShift CLI is installed (optional dependency)
oc version --client

# Install if needed:
# macOS: brew install openshift-cli
# Linux: Download from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/
# Windows: Download from Red Hat or use package manager

# Verify oc is in PATH
which oc
```

#### Q: Plugins not loading

```bash
# Check plugin directory and file naming
ls ~/chief_plugins/*_chief-plugin.sh
```

#### Q: SSH keys not auto-loading

```bash
# Verify key naming (must end in .key) and path
ls ~/.ssh/*.key
chief.config  # Check CHIEF_CFG_SSH_KEYS_PATH
```

#### Q: Git prompt not working

```bash
# Enable git prompt in config
chief.config
# Set CHIEF_CFG_PROMPT=true and CHIEF_CFG_GIT_PROMPT=true
```

## 🤖 Contributing

We welcome contributions! Here's how:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Resources

- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)
- [Plugin Development Guide](docs/plugin-development.md)
- [Contributing Guidelines](CONTRIBUTING.md)

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Git completion and prompt scripts from the Git project
- Inspired by various Bash framework projects
- Built with ❤️ for the terminal-loving community

---

**Ready to transform your terminal experience?** [Get started now](#-installation) or [explore the documentation](docs/) for advanced usage.