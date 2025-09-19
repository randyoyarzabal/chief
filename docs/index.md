---
layout: default
title: Chief
description: "Transform your terminal experience with organized bash functions, aliases, and a powerful plugin system."
permalink: /
---

# 🚀 Chief

**Bash Plugin Manager & Terminal Enhancement Tool**

[![GitHub release](https://img.shields.io/badge/Download-Release%20v3.1.0-green.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![Documentation](https://img.shields.io/badge/📖-Documentation-blue)](https://chief.reonetlabs.us)

Chief is a lightweight, powerful Bash library system that helps you organize your shell environment through a plugin-based architecture. Think of it as a package manager for your bash functions, aliases, and tools.

## ⚡ Quick Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

**That's it!** Restart your terminal and start using Chief.

### Air-Gapped Installation

For disconnected environments:

```bash
# Download Chief, transfer to target system, then:
./tools/install.sh --local
```

## ⚡ Quick Start: Portable Setup

**Real-world example**: Set up Chief with remote plugins and vault that follows you across all systems.

### 🚀 One-Time Setup (any new system)

```bash
# 1. Install Chief (one command)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"

# 2. Configure your plugin repository (replace with your repo)
chief.config_set -y PLUGINS_GIT_REPO="git@github.com:yourusername/my-plugins.git"
chief.config_set -y PLUGINS_PATH="${HOME}/chief_plugins"
chief.config_set -y PLUGINS_GIT_BRANCH="main"
chief.config_set -y PLUGINS_GIT_PATH="bash/plugins"   # or "" for repo root, this is plugins path relative to PLUGINS_PATH
chief.config_set -y PLUGINS_GIT_AUTOUPDATE="false"    # manual updates
chief.config_set -y PLUGINS_TYPE="remote"             # 🔑 Enable remote sync

# 3. (Optional) Enable multi-line prompt, useful when current working dir is deep.
chief.config_set -y MULTILINE_PROMPT=true 

# 4. (Optional) Load your encrypted secrets (if exists)
chief.vault_file-load  # Team vault (.chief_shared-vault - if exists)
chief.vault_file-load ~/.my-personal-vault     # Personal vault
```

📖 For detailed vault setup and management, see: [Vault Configuration](configuration.html#vault-configuration)

### 🎯 Result

- ✅ **Same plugins everywhere**: Functions, aliases, and tools sync across laptop, server, CI/CD
- ✅ **Encrypted secrets**: Vault files travel with your setup (team + personal)
- ✅ **Zero reconfiguration**: New systems work identically after this setup
- ✅ **Version controlled**: Track changes to your shell environment

## 🚀 30-Second Demo

```bash
# See what's available
chief.help

# See available user and core plugin tools
chief.help plugins

# Find any function, alias or environment variable
chief.whereis git_status

# Create a custom function
chief.plugin mytools
```

## ✨ Key Features

- 🔐 **Vault System** - Encrypt sensitive environment variables
- 🌐 **Remote Plugin Sync** - Share plugins across teams via Git 
- 🎨 **Git-Aware Prompts** - Beautiful, intelligent terminal prompts
- 🔍 **Instant Discovery** - Find any function with `chief.whereis`
- 🚀 **Zero Disruption** - Only affects Bash, won't interfere with existing setups
- 📦 **Plugin Architecture** - Organize tools into reusable, shareable plugins

## 🔌 Available Plugins

Chief comes with **8 powerful plugins** providing **56+ functions** for your daily workflow:

### 🔍 **Discovery & Help**

- `chief.help` - Interactive help system with plugin browsing
- `chief.whereis <function>` - Find any function across all plugins
- `chief.plugins_*` - Plugin management and discovery tools

### 🔐 **Vault Plugin** (2 functions)

- `chief.vault_file_edit` - Edit encrypted files securely
- `chief.vault_file_load` - Load encrypted environment variables

### ☸️ **OpenShift/Kubernetes Plugin** (7 functions)

- `chief.oc_get_all_objects` - Comprehensive resource discovery with filtering
- `chief.oc_clean_olm` - OLM cleanup with selective targeting
- `chief.oc_show_stuck_resources` - Troubleshoot stuck resources with auto-fix
- `chief.oc_delete_stuck_ns` - Force delete terminating namespaces
- `chief.oc_approve_csrs` - Batch CSR approval with interactive mode
- `chief.oc_login` - Enhanced login with context management

### 🔒 **SSL/TLS Plugin** (4 functions)

- `chief.ssl_create_ca` - Create certificate authorities with minimal setup
- `chief.ssl_create_tls_cert` - Generate TLS certificates signed by your CA
- `chief.ssl_view_cert` - Analyze certificates with multiple display options
- `chief.ssl_get_cert` - Download certificates from remote servers

### 🔑 **SSH Plugin** (3 functions)

- `chief.ssh_create_keypair` - Generate SSH key pairs with best practices
- `chief.ssh_get_publickey` - Extract and display public keys
- `chief.ssh_rm_host` - Clean known_hosts entries safely

### ☁️ **AWS Plugin** (2 functions)

- `chief.aws_set_role` - Switch between AWS IAM roles
- `chief.aws_export_creds` - Export AWS credentials to environment

### 🛠️ **System Utilities Plugin** (18 functions)

- `chief.etc_create_bootusb` - Create bootable USB drives safely
- `chief.etc_folder_sync` - Professional rsync-based directory synchronization  
- `chief.etc_copy_dotfiles` - Copy configuration files with backup support
- `chief.etc_shared_term_*` - Create and manage shared tmux sessions
- `chief.etc_chmod_*` - Enhanced file permission management
- `chief.etc_mount_share` - Network share mounting utilities
- File comparison, IP validation, system prompts, and more...

### 🔧 **Git Plugin** (16 functions)

- `chief.git_clone` - Enhanced git cloning with safety checks
- `chief.git_commit` - Streamlined commit workflow
- `chief.git_reset_*` - Safe reset operations with dry-run support
- `chief.git_branch` - Advanced branch management
- `chief.git_config_user` - Quick user configuration setup
- Complete workflow support: tagging, amending, credential caching, URL management

### 🐍 **Python Plugin** (4 functions)

- `chief.python_create_ve` - Virtual environment creation and setup
- `chief.python_start_ve` - Activate virtual environments
- `chief.python_stop_ve` - Deactivate environments
- `chief.python_ve_dep` - Install dependencies from requirements.txt

## 🛡️ Safe for Everyone

- **Zsh/Oh My Zsh Users**: Chief won't touch your existing setup
- **Custom Prompts**: Prompt features disabled by default
- **Easy Removal**: Clean uninstall available anytime

## 📖 Complete Documentation

Ready to dive deeper? Explore our comprehensive guides:

**[🔧 Getting Started](getting-started.html)** - Installation, setup, and first steps

**[📖 User Guide](user-guide.html)** - Core features, commands, and daily workflows  

**[🛠️ Plugin Development](plugin-development.html)** - Create and share your own plugins

**[⚙️ Configuration](configuration.html)** - Advanced setup and team collaboration

**[📋 Reference](reference.html)** - Complete command reference and troubleshooting

## 🐛 Bug Reports & Support

Found a bug or need help? We're here to help! Please create an issue on GitHub:

**[📝 Report an Issue](https://github.com/randyoyarzabal/chief/issues)**

When reporting issues, please include:

- **OS version**: Run `uname -a` to get your system details
- **Chief version**: Run `chief.help` to see the current version
- **Steps to reproduce**: Clear, step-by-step instructions
- **Error messages**: Copy the exact error output
- **Expected vs actual behavior**: What you expected vs what happened

This helps us quickly identify and fix issues!

## 🤝 Contributing

Contributions welcome! See our [reference documentation](reference.html#contributing) for guidelines.

## 📄 License

MIT License - see [LICENSE](https://github.com/randyoyarzabal/chief/blob/main/LICENSE) file for details.