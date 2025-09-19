---
layout: default
title: Chief
description: "Transform your terminal experience with organized bash functions, aliases, and a powerful plugin system."
permalink: /
---

# 🚀 Chief

**Bash Plugin Manager & Terminal Enhancement Tool**

[![GitHub release](https://img.shields.io/badge/Download-Release%20v3.1.1-dev-lightgrey.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![Documentation](https://img.shields.io/badge/📖-Documentation-blue)](https://chief.reonetlabs.us)

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

# Find any function/alias
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