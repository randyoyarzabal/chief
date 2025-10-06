---
layout: default
title: Getting Started
description: "Installation, setup, and first steps with Chief"
---

[← Back to Home](https://chief.reonetlabs.us/)

# Getting Started with Chief

*Complete guide to installing, configuring, and taking your first steps with Chief.*

## Table of Contents

- [Installation](#installation)
- [Requirements](#requirements)
- [Quick Start Tutorial](#quick-start-tutorial)
- [Next Steps](#next-steps)
- [Upgrading Chief](#upgrading-chief)
- [Uninstalling Chief](#uninstalling-chief)
- [Installation Troubleshooting](#installation-troubleshooting)

---

## Installation

### Quick Install (Recommended)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

**That's it!** Restart your terminal and start using Chief.

### Alternative Installation Methods

```bash
# Install to custom directory
CHIEF_PATH="$HOME/my-chief" bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"

# Install specific version
CHIEF_VERSION="v2.1.0" bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"

# Install from specific branch (for testing)
CHIEF_INSTALL_GIT_BRANCH="dev" bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

### Disconnected Installation

For environments without git connectivity, you can install Chief from local files:

```bash
# 1. Download Chief manually (on a connected machine)
git clone https://github.com/randyoyarzabal/chief.git
cd chief

# 2. Transfer the entire directory to your disconnected system

# 3. Install from local files
./tools/install.sh --local

# 4. Optional: Install to custom location
./tools/install.sh --local --path /opt/chief
```

**Benefits of disconnected installation:**

- ✓ **No internet required** during installation
- ✓ **Complete transparency** - all files visible before installation
- ✓ **Security compliant** - suitable for restricted environments
- ✓ **Manual update control** - updates require explicit file replacement

> **Note:** The `--branch` option is ignored with `--local` installations since files come from the local directory, not Git.

### What Gets Installed

- **Chief Library** (`~/.chief/`) - Core functionality and plugins
- **Configuration File** (`~/.chief_config.sh`) - Your personal settings
- **Bash Integration** - Automatic loading in `~/.bash_profile`

---

## Requirements

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

---

## Safety First

### Safe for Everyone

- **Zero Disruption** - Only affects Bash, won't interfere with existing setups
- **Safe for Zsh Users** - Chief only affects your Bash shell environment
- **Custom Prompts Safe** - Prompt customizations are disabled by default
- **🔄 Easy Removal** - Clean uninstall available anytime

### Compatibility Notes

> **Safe for Zsh Users:** Chief only affects your Bash shell environment. If you're currently using Zsh, Oh My Zsh, or any other shell, Chief won't interfere with your existing setup. It only activates when you explicitly run `bash` or switch to a Bash session.

> **Using Oh My Bash or Custom Prompts?** Chief's prompt customizations are **disabled by default** (`CHIEF_CFG_PROMPT=false`). If you have Oh My Bash, Starship, or other prompt tools, keep this setting disabled to avoid conflicts.

---

## Bug Reports & Support

Found a bug or need help? We're here to help! Please create an issue on GitHub:

**[Report an Issue](https://github.com/randyoyarzabal/chief/issues)**

When reporting issues, please include:
- **OS version**: Run `uname -a` to get your system details  
- **Chief version**: Run `chief.help` to see the current version
- **Steps to reproduce**: Clear, step-by-step instructions
- **Error messages**: Copy the exact error output
- **Expected vs actual behavior**: What you expected vs what happened

This helps us quickly identify and fix issues!

---

## Quick Start Tutorial

### 1. Verify Installation

After restarting your terminal:

```bash
# Check Chief is loaded
chief.help

# See your current configuration
chief.config_show
```

### 2. Explore Basic Commands

```bash
# Get help for any command
chief.help search

# Find where functions are defined
chief.whereis git_status

# List all available plugins
chief.plugin -?
```

### 3. Create Your First Plugin

```bash
# Create a custom plugin
chief.plugin mytools

# This opens your plugin file in your default editor
# Add some custom functions, save, and exit
```

Example plugin content:
```bash
#!/usr/bin/env bash
# My custom tools

# Quick directory navigation
alias ll='ls -la'
alias ..='cd ..'

# Custom function
my_status() {
    echo "System: $(uname -s)"
    echo "User: $(whoami)"
    echo "Directory: $(pwd)"
}
```

### 4. Test Your Plugin

```bash
# After saving your plugin, reload Chief
chief.reload

# Your new function is now available
my_status

# Find where it's defined
chief.whereis my_status
```

### 5. Enable Git Prompts (Optional)

```bash
# Enable beautiful git-aware prompts
chief.config_set PROMPT true

# Reload to see changes
chief.reload
```

---

## Next Steps

### Essential Configuration

```bash
# Set up your preferred editor (for plugin editing)
chief.config_set EDITOR "code"  # VS Code
# or
chief.config_set EDITOR "vim"   # Vim

# Configure multiline prompts (recommended)
chief.config_set MULTILINE_PROMPT true

# Show full paths in prompt
chief.config_set SHORT_PATH false
```

### Learn More

- **[User Guide](user-guide.html)** - Core features and commands
- **[Plugin Development](plugin-development.html)** - Create advanced plugins
- **[Configuration](configuration.html)** - Advanced setup and team sharing

---

## Upgrading Chief

### Automatic Update (Recommended)

```bash
# Update Chief with automatic config reconciliation
chief.config_update                   # Updates config with new options
chief.config_update --dry-run         # Preview changes before applying
```

### Manual Reinstall

```bash
# Reinstall over existing installation
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

### Branch Tracking

Chief supports tracking any valid Git branch for updates:

```bash
# Track stable releases (default)
chief.config_set update_branch main

# Track development features (⚠ use with caution)  
chief.config_set update_branch dev

# Update to your configured branch
chief.update
```

**What `chief.config_update` does:**

- ✓ **Adds new features** - Automatically adds new configuration options
- ✓ **Handles renames** - Seamlessly migrates renamed variables
- ✓ **Preserves customizations** - Keeps all your existing settings
- ✓ **Creates backup** - Makes timestamped backup before changes
- ✓ **Validates syntax** - Ensures new config is valid before applying

---

## Uninstalling Chief

### Quick Uninstall

```bash
# Method 1: Using Chief command (easiest if Chief is working)
chief.uninstall

# Method 2: One-liner (works from anywhere)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/uninstall.sh)"
```

### What Happens During Uninstall

- ✓ **Installation directory** (`~/.chief`) is completely removed
- ✓ **Configuration file** is backed up as `~/.chief_config.sh.backup` then removed
- ✓ **Shell configuration** (`~/.bash_profile`) is cleaned up automatically
- ✓ **Environment variables** are removed from shell
- ✓ **Custom plugins directory** remains untouched (if different from `~/.chief`)

> **Safe Uninstall**: Your personal plugins, shell customizations outside Chief, and other configurations remain completely untouched.

---

## 🛟 Installation Troubleshooting

### Common Issues

**Problem:** Command not found after installation
```bash
# Solution: Source your bash profile manually
source ~/.bash_profile

# Or restart your terminal
```

**Problem:** Permission denied during installation
```bash
# Solution: Ensure you have write access to home directory
ls -la ~ | grep chief

# If needed, fix permissions
chmod 755 ~/.chief
```

**Problem:** Git clone fails
```bash
# Solution: Check internet connection and Git configuration
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

### Getting Help

- Check our [User Guide troubleshooting section](user-guide.html#troubleshooting)
- [Open an issue](https://github.com/randyoyarzabal/chief/issues) on GitHub
- Run `chief.help` for built-in help system

---

[← Back to Home](https://chief.reonetlabs.us/)
