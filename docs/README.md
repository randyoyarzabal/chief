# 🚀 Chief - Bash Plugin Manager & Terminal Enhancement Tool

[![GitHub release](https://img.shields.io/badge/Download-Release%20v2.1.2-lightgrey.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![GitHub commits (since latest release)](https://img.shields.io/github/commits-since/randyoyarzabal/chief/latest.svg?style=social)](https://github.com/randyoyarzabal/chief/commits/master)

> **Transform your terminal experience with organized bash functions, aliases, and a powerful plugin system.**

## 🎯 What is Chief?

Chief is a lightweight, powerful Bash library system that helps you organize your shell environment through a plugin-based architecture. Think of it as a package manager for your bash functions, aliases, and tools.

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

- 👥 **Team collaboration** - Share plugins and standardize tooling
- 📚 **Built-in help** - Every command has help (`chief.* -?`)
- 🔗 **Tab completion** - All Chief commands are tab-completable
- 🚀 **Instant onboarding** - New team members get your tools instantly

## 📦 Installation

### ⚡ Quick Install (30 seconds)

```bash
# Install Chief with one command
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"

# Restart your terminal or source config file
source ~/.bash_profile

# Start exploring!
chief.[tab][tab]  # See all available commands
```

That's it! Chief is now installed and ready to use.

> **🛡️ Safe for Zsh Users:** Chief only affects your Bash shell environment. If you're currently using Zsh, Oh My Zsh, or any other shell, Chief won't interfere with your existing setup. It only activates when you explicitly run `bash` or switch to a Bash session.

### 🔧 Alternative Installation Methods

<details>
<summary>Click to see manual installation and other options</summary>

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
```

</details>

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

### Version Compatibility

| Component | Minimum Version | Recommended | Notes |
|-----------|----------------|-------------|-------|
| Bash | 4.0 | 5.0+ | Associative arrays, process substitution |
| Git | 2.0 | Latest | Clone, fetch, submodules |
| Ansible Core | 2.9 | Latest | Optional - vault functions only |

### Check Your Environment

```bash
# Check bash version
bash --version

# Check if git is available
git --version

# Check ansible (optional)
ansible-vault --version 2>/dev/null || echo "Ansible not installed (optional)"
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
chief.config

# Update Chief
chief.update

# Edit shell files with auto-reload
chief.bash_profile  # Edit .bash_profile
```

### Built-in Tools (Available Immediately)

- **Git**: Enhanced git commands and completion
- **SSH**: Automatic key loading and management
- **SSL**: Certificate inspection and validation tools
- **OpenShift**: Container platform utilities
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

### 3. Team Plugin Sharing

```bash
# Create a team plugin repository
# Everyone on your team can use the same tools
chief.plugins_update  # Pull latest team functions
```

⚠️ **Security Note for Team Sharing**: When sharing Chief plugins with a team, be aware that any variables defined in shared plugin files will be visible to all team members. Personal or sensitive variables such as:
- `CHIEF_OC_USERNAME` (OpenShift username)
- `CHIEF_SECRETS_FILE` (path to encrypted secrets)
- `VAULT_ADDR`, `VAULT_TOKEN` (HashiCorp Vault credentials)
- API keys, tokens, or personal paths

Should be placed in your personal shell configuration files (e.g., `~/.bash_profile`, `~/.bashrc`) rather than in shared plugin repositories. This ensures sensitive information remains private while still allowing team collaboration on shared functions and aliases.

## 🛠️ Configuration Options

Chief is highly customizable. Run `chief.config` to edit settings:

| Configuration | Default | Description |
|---------------|---------|-------------|
| `CHIEF_CFG_BANNER` | `true` | Show startup banner |
| `CHIEF_CFG_HINTS` | `true` | Display helpful tips on startup |
| `CHIEF_CFG_PROMPT` | `false` | Use Chief's custom prompt |
| `CHIEF_CFG_COLORED_PROMPT` | `true` | Colorize the prompt |
| `CHIEF_CFG_GIT_PROMPT` | `true` | Git-aware prompt features |
| `CHIEF_CFG_MULTILINE_PROMPT` | `false` | Enable multiline prompt display |
| `CHIEF_CFG_SHORT_PATH` | `false` | Show only current directory name in prompt |
| `CHIEF_CFG_COLORED_LS` | `false` | Colorize ls command output |
| `CHIEF_CFG_PLUGINS_TYPE` | `"local"` | Use `"local"` or `"remote"` plugins |
| `CHIEF_CFG_RSA_KEYS_PATH` | _unset_ | Auto-load SSH keys from path |
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
| **OpenShift** | `chief.oc_*` | Container platform operations |
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
CHIEF_CFG_RSA_KEYS_PATH="$HOME/.ssh"

# Chief automatically loads all *.rsa keys
# Supports symlinks for selective loading
```

### Custom Prompt Features

```bash
# Enable git-aware prompt
CHIEF_CFG_PROMPT=true
CHIEF_CFG_GIT_PROMPT=true

# Shows: user@host:~/project (main|+2-1) $ 
#        ↑              ↑     ↑    ↑  ↑
#        user           path  branch +staged -unstaged
```

### Remote Plugin Repositories

```bash
# Store your plugins in a Git repo
# Multiple machines can sync the same plugins
CHIEF_CFG_PLUGINS_TYPE="remote"
CHIEF_CFG_PLUGINS_GIT_REPO="git@github.com:yourteam/bash-plugins.git"

# Auto-update plugins
chief.plugins_update
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

## 🗑️ Uninstallation

### Quick Uninstall

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/uninstall.sh)"
```

### Or from within Chief

```bash
chief.uninstall
```

**Note:** Your custom plugins in `~/chief_plugins/` are preserved during uninstallation.


## ⚡ Quick Start Guide

```bash
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
- Git-aware prompts using `__git_ps1`
- Tab completion via `complete` builtin
- Works alongside Oh My Bash

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

#### Q: Plugins not loading

```bash
# Check plugin directory and file naming
ls ~/chief_plugins/*_chief-plugin.sh
```

#### Q: SSH keys not auto-loading

```bash
# Verify key naming (must end in .rsa) and path
ls ~/.ssh/*.rsa
chief.config  # Check CHIEF_CFG_RSA_KEYS_PATH
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

**Ready to transform your terminal experience?** [Get started now](#-quick-start-30-seconds) or [explore the documentation](docs/) for advanced usage.
