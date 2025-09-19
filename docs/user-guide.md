---
layout: default
title: User Guide
description: "Complete guide to using Chief's core features and commands"
---

[← Back to Home](https://chief.reonetlabs.us/)

# User Guide

Complete guide to using Chief's core features, commands, and workflows.
{: .fs-6 .fw-300 }

## Table of contents

{: .no_toc .text-delta }

1. TOC
{:toc}

---

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

---

## 🎯 Core Features

### Plugin Management

```bash
# Create your first plugin
chief.plugin mytools

# List all plugins
chief.plugin -?

# Find where a function is defined
chief.whereis my_function

# Reload all plugins after changes
chief.reload
```

### Configuration Management

```bash
# View current configuration
chief.config_show

# Set configuration options
chief.config_set PROMPT true
chief.config_set EDITOR "code"

# Interactive configuration editor
chief.config

# Update configuration with new features
chief.config_update
```

### Discovery and Navigation

```bash
# Find any function, alias, or variable
chief.whereis git_status

# Edit your bash profile with auto-reload
chief.bash_profile

# Edit your bashrc with auto-reload  
chief.bashrc

# Quick command exploration
chief.[tab][tab]
```

---

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

### 2. Enhanced Development Workflow

```bash
# Create project-specific environments
chief.plugin myproject

# Auto-reload configurations when files change
chief.bash_profile  # Edit and auto-reloads

# Find any function or command instantly
chief.whereis deploy  # Shows all deploy functions across plugins
```

### 3. Team Collaboration

```bash
# Set up remote plugin sync
chief.config
# Set CHIEF_CFG_PLUGINS_TYPE="remote"
# Set CHIEF_CFG_PLUGINS_GIT_REPO="git@github.com:youruser/bash-plugins.git"

# Now your plugins sync across all your machines!
```

---

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

### Configuration Editor

```bash
# Interactive configuration (opens in your editor)
chief.config

# Quick config changes
chief.config_set PROMPT true
chief.config_set MULTILINE_PROMPT true
```

### Enhanced Terminal

```bash
# Git-aware prompts (when enabled)
# Shows: user@host:~/project (main*) $

# SSH key auto-loading
# Automatically loads ~/.ssh/*.key files

# Better colors and formatting
# Consistent color scheme across tools
```

### Built-in Tools

```bash
# Git utilities (git_chief-plugin.sh)
git.branch_clean              # Clean merged branches
git.uncommitted               # Find uncommitted changes

# Vault utilities (vault_chief-plugin.sh) 
chief.vault_file-edit         # Create/edit encrypted files
chief.vault_file-load         # Load secrets

# SSH utilities (ssh_chief-plugin.sh)
ssh.key_add                   # Add SSH keys to agent
ssh.agent_status              # Check SSH agent status

# SSL/TLS utilities (ssl_chief-plugin.sh)
chief.ssl_create-ca           # Create Certificate Authority
chief.ssl_create-tls-cert     # Create TLS certificates
chief.ssl_view-cert           # View/analyze certificates
chief.ssl_get-cert            # Download certificates from servers

# System utilities (etc_chief-plugin.sh)
chief.etc_chmod-f             # Recursive file permission changes
chief.etc_chmod-d             # Recursive directory permission changes
chief.etc_create_bootusb      # Create bootable USB drives
chief.etc_copy_dotfiles       # Copy hidden files between directories
chief.etc_create_cipher       # Generate random cipher keys
chief.etc_mount_share         # Mount SMB/CIFS network shares
chief.etc_spinner             # Progress spinner for long operations
chief.etc_ask_yes_or_no       # Interactive yes/no prompts

# OpenShift utilities (openshift_chief-plugin.sh)
chief.oc_login                # Login to OpenShift with Vault integration
chief.oc_approve_csrs         # Approve Certificate Signing Requests
chief.oc_show_stuck_resources # Show and fix stuck resources
chief.oc_delete_stuck_ns      # Force delete stuck namespaces
```

---

## 🔧 Advanced Plugin Features

### SSL/TLS Certificate Management

Chief includes comprehensive SSL/TLS certificate management tools for creating, analyzing, and downloading certificates.

#### Create Certificate Authority

```bash
# Create a basic CA with defaults
chief.ssl_create-ca

# Create a named CA with custom organization
chief.ssl_create-ca mycompany -o "ACME Corp" -d 7300

# Create CA with full customization
chief.ssl_create-ca production \
  -c US -s CA -l "San Francisco" \
  -o "Production CA" -e admin@company.com \
  -d 3650 -k 4096
```

#### Create TLS Certificates

```bash
# Create basic server certificate
chief.ssl_create-tls-cert webserver

# Create certificate with Subject Alternative Names
chief.ssl_create-tls-cert api --san "api.example.com,api.test.com"

# Create certificate with IP addresses
chief.ssl_create-tls-cert server --ip "192.168.1.10,10.0.0.5"

# Create wildcard certificate
chief.ssl_create-tls-cert web --san "*.example.com" -d 730 -k 4096
```

#### Certificate Analysis and Download

```bash
# View certificate details
chief.ssl_view-cert cert.pem
chief.ssl_view-cert -s cert.pem          # Subject only
chief.ssl_view-cert -d cert.pem          # Dates only

# Download certificates from servers
chief.ssl_get-cert google.com
chief.ssl_get-cert mail.example.com 993  # IMAPS
chief.ssl_get-cert -c example.com        # Full certificate chain
```

### System Administration Tools

The ETC plugin provides essential system administration utilities for common tasks.

#### File and Directory Management

```bash
# Recursively change file permissions
chief.etc_chmod-f 644                    # All files to 644
chief.etc_chmod-f 755 /path/to/scripts   # Executable scripts
chief.etc_chmod-f -v 644                 # Verbose output
chief.etc_chmod-f -n 644                 # Dry run preview

# Recursively change directory permissions
chief.etc_chmod-d 755                    # Standard directory permissions
chief.etc_chmod-d 750 /secure/path       # Restricted access
```

#### Dotfiles Management

```bash
# Copy hidden files between directories
chief.etc_copy_dotfiles ~/backup ~/
chief.etc_copy_dotfiles -v /etc/skel ~/newuser  # Verbose
chief.etc_copy_dotfiles -b -f ~/old ~/current   # Force with backup
```

#### Bootable Media Creation

```bash
# Create bootable USB drive (macOS/Linux)
chief.etc_create_bootusb ubuntu.iso 2          # disk2 on macOS
chief.etc_create_bootusb -n ubuntu.iso 2       # Dry-run: SAFE preview
chief.etc_create_bootusb -k installer.iso 3    # Keep temp files
```

**⚠️ Safety First**: Always use `-n` flag first to preview what will happen before creating bootable media, as this operation completely erases the target drive.

#### Network and Collaboration Tools

```bash
# Mount SMB/CIFS network shares
chief.etc_mount_share //server/shared /mnt/shared john

# Create shared terminal sessions
chief.etc_shared-term_create dev-session
chief.etc_shared-term_connect dev-session

# Schedule commands to run later
chief.etc_at_run "now + 10 minutes" "echo 'Reminder!'"
chief.etc_at_run "2:30pm" "backup_script.sh"
```

### OpenShift Container Platform Management

Advanced OpenShift cluster management with Vault integration for secure authentication.

#### Cluster Authentication

```bash
# Login with Vault-stored credentials
chief.oc_login hub                # User credentials from Vault
chief.oc_login hub -kc            # Kubeconfig from Vault
chief.oc_login hub -ka            # Kubeadmin password from Vault
chief.oc_login hub -i             # Skip TLS verification
```

#### Certificate and Resource Management

```bash
# Approve pending Certificate Signing Requests
chief.oc_approve_csrs             # Interactive approval
chief.oc_approve_csrs -l          # List pending CSRs
chief.oc_approve_csrs -a          # Approve all pending
chief.oc_approve_csrs -f "node-"  # Filter by pattern

# Diagnose stuck resources
chief.oc_show_stuck_resources my-namespace
chief.oc_show_stuck_resources production --dry-run
chief.oc_show_stuck_resources dev-environment --fix

# Force delete stuck namespaces
chief.oc_delete_stuck_ns stuck-namespace --dry-run
chief.oc_delete_stuck_ns broken-ns
```

#### Vault Integration Configuration

For seamless OpenShift authentication, configure Vault secrets:

```bash
# Set up environment variables
export VAULT_ADDR="https://vault.company.com"
export VAULT_TOKEN="your-vault-token"
export CHIEF_VAULT_OC_PATH="secrets/openshift"

# Store cluster credentials in Vault
vault kv put secrets/openshift/hub \
  api="https://api.hub.cluster.com:6443" \
  kubeconfig="$(cat ~/.kube/config)" \
  kubeadmin="password123"
```

---

## 📖 Command Reference

### Core Commands

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

### Configuration Commands

```bash
# View current configuration
chief.config_show

# Set configuration values
chief.config_set PROMPT true
chief.config_set EDITOR "vim"

# Interactive configuration editor
chief.config

# Update config with new features (after upgrade)
chief.config_update
chief.config_update --dry-run

# Reload Chief after changes
chief.reload
```

### Plugin Commands

```bash
# Create/edit plugins
chief.plugin mytools          # Create or edit 'mytools' plugin
chief.plugin list             # List all available plugins

# Plugin discovery
chief.whereis function_name   # Find where function is defined
chief.help plugins            # Show plugin-provided commands

# Plugin management
chief.plugins_update          # Update remote plugins (if configured)
chief.plugins_root             # Navigate to plugins directory
```

---

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

### Example 3: Git Workflow Plugin

```bash
# Create git workflow plugin
chief.plugin gitflow

function gitflow.feature_start() {
    local feature_name="$1"
    git checkout develop
    git pull origin develop
    git checkout -b "feature/${feature_name}"
}

function gitflow.feature_finish() {
    local current_branch=$(git branch --show-current)
    git checkout develop
    git merge "${current_branch}"
    git branch -d "${current_branch}"
}
```

### Git Safety: Dry-Run Operations

Chief's Git functions include dry-run capabilities for potentially destructive operations:

```bash
# SAFE: Preview what git reset --hard would affect
chief.git_reset-hard -n

# Example output shows:
# Modified files that would be reset:
#   - src/config.js
#   - README.md
# Staged files that would be reset:
#   - package.json
# ⚠️ WARNING: This would permanently discard the above changes!

# Only run without -n after reviewing the changes
chief.git_reset-hard
```

**Best Practice**: Always run Git operations with `-n` first to understand what will be affected.
---

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

---

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

# Verify plugin syntax
bash -n ~/chief_plugins/myplugin_chief-plugin.sh

# Check plugin path configuration
chief.config_show | grep PLUGINS_PATH
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

### Getting Help

- Run `chief.help` for the built-in help system
- Use `chief.help --search <term>` to find specific commands
- Check configuration with `chief.config_show`
- Find function definitions with `chief.whereis <function>`
- [Open an issue](https://github.com/randyoyarzabal/chief/issues) on GitHub for bugs

### Debug Mode

```bash
# Enable debug output for troubleshooting
export CHIEF_DEBUG=1
source ~/.bash_profile

# This will show detailed loading information
```

---

## 🎯 Next Steps

- **[Plugin Development](plugin-development.html)** - Create custom plugins
- **[Configuration](configuration.html)** - Advanced setup and team sharing
- **[Reference](reference.html)** - Complete command and feature reference

---

[← Back to Home](https://chief.reonetlabs.us/)
