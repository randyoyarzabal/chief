# 🚀 Chief

**Bash Plugin Manager & Terminal Enhancement Tool**

[![GitHub release](https://img.shields.io/badge/Download%20Release-v3.1.4-blue.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![Dev Branch](https://img.shields.io/badge/Dev%20Branch-v3.1.4-dev-orange.svg?style=social)](https://github.com/randyoyarzabal/chief/tree/dev) [![Main Branch](https://img.shields.io/badge/Stable-v3.1.4-green.svg?style=social)](https://github.com/randyoyarzabal/chief) [![Documentation](https://img.shields.io/badge/📖-Documentation-blue)](https://chief.reonetlabs.us)

Chief is a lightweight, powerful Bash library system that helps you organize your shell environment through a plugin-based architecture. Think of it as a package manager for your bash functions, aliases, and tools.

## ⚡ Quick Install

```bash
# Install stable version
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

**For development version**, use:

```bash
# Install development version (may be unstable)  
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/dev/tools/install.sh)"
```

**That's it!** Restart your terminal and start using Chief.

### Disconnected Installation

For environments without git connectivity:

```bash
# Download Chief, transfer to target system, then:
./tools/install.sh --local
```

## Quick Start: Portable Setup

**Real-world example**: Set up Chief with remote plugins and vault that follows you across all systems.

### One-Time Setup (any new system)

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
chief.vault_file-load  # Team vault (.chief_shared-vault - if exists)
chief.vault_file-load ~/.my-personal-vault     # Personal vault
```

For detailed vault setup and management, see: [Vault Configuration](https://chief.reonetlabs.us/configuration.html#-vault-configuration)

### Result

- **Same plugins everywhere**: Functions, aliases, and tools sync across laptop, server, CI/CD
- **Encrypted secrets**: Vault files travel with your setup (team + personal)
- **Zero reconfiguration**: New systems work identically after this setup
- **Version controlled**: Track changes to your shell environment

## 30-Second Demo

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

## Key Features

- **Vault System** - Encrypt sensitive environment variables
- **Enterprise-Ready Tools** - Built-in OpenShift, SSL/TLS, SSH, AWS, Git, and Python utilities
- **Remote Plugin Sync** - Share plugins across teams via Git 
- **Git-Aware Prompts** - Beautiful, intelligent terminal prompts
- **Instant Discovery** - Find any function with `chief.whereis`
- **Zero Disruption** - Only affects Bash, won't interfere with existing setups
- **Plugin Architecture** - Organize tools into reusable, shareable plugins

## Available Plugins

Chief comes with **8 powerful plugins** providing **58+ functions** for your daily workflow:

### Discovery & Help

- `chief.help` - Interactive help system with plugin browsing
- `chief.whereis <function>` - Find any function across all plugins
- `chief.plugins_*` - Plugin management and discovery tools

### Vault Plugin (2 functions)

- `chief.vault_file-edit` - Edit encrypted files securely
- `chief.vault_file-load` - Load encrypted environment variables

### OpenShift/Kubernetes Plugin (9 functions)

- `chief.oc_get-all-objects` - Comprehensive resource discovery with filtering
- `chief.oc_clean-olm` - OLM cleanup with selective targeting
- `chief.oc_clean-replicasets` - Clean up old replica sets with safety checks
- `chief.oc_show-stuck-resources` - Troubleshoot stuck resources with auto-fix
- `chief.oc_delete-stuck-ns` - Force delete terminating namespaces
- `chief.oc_approve-csrs` - Batch CSR approval with interactive mode
- `chief.oc_login` - Enhanced login with context management
- `chief.oc_vault-kubeadmin` - Display kubeadmin credentials from Vault
- `chief.oc_whoami` - Show current user, API server, and console information

### SSL/TLS Plugin (4 functions)

- `chief.ssl_create-ca` - Create certificate authorities with minimal setup
- `chief.ssl_create-tls-cert` - Generate TLS certificates signed by your CA
- `chief.ssl_renew-tls-cert` - Renew existing certificates with smart parameter extraction
- `chief.ssl_view-cert` - Analyze certificates with multiple display options
- `chief.ssl_get-cert` - Download certificates from remote servers

### SSH Plugin (3 functions)

- `chief.ssh_create-keypair` - Generate SSH key pairs with best practices
- `chief.ssh_get-publickey` - Extract and display public keys
- `chief.ssh_rm-host` - Clean known_hosts entries safely

### System Utilities Plugin (18 functions)

- `chief.etc_create-bootusb` - Create bootable USB drives safely
- `chief.etc_folder-sync` - Professional rsync-based directory synchronization  
- `chief.etc_copy-dotfiles` - Copy configuration files with backup support
- `chief.etc_shared_term_*` - Create and manage shared tmux sessions
- `chief.etc_chmod_*` - Enhanced file permission management
- `chief.etc_mount-share` - Network share mounting utilities
- File comparison, IP validation, system prompts, and more...

### Git Plugin (16 functions)

- `chief.git_clone` - Enhanced git cloning with safety checks
- `chief.git_commit` - Streamlined commit workflow
- `chief.git_reset_*` - Safe reset operations with dry-run support
- `chief.git_branch` - Advanced branch management
- `chief.git_config-user` - Quick user configuration setup
- Complete workflow support: tagging, amending, credential caching, URL management

### Python Plugin (4 functions)

- `chief.python_create-ve` - Virtual environment creation and setup
- `chief.python_start-ve` - Activate virtual environments
- `chief.python_stop-ve` - Deactivate environments
- `chief.python_ve-dep` - Install dependencies from requirements.txt

### AWS Plugin (2 functions)

- `chief.aws_set-role` - Switch between AWS IAM roles
- `chief.aws_export-creds` - Export AWS credentials to environment

## Safe for Everyone

- **Zsh/Oh My Zsh Users**: Chief won't touch your existing setup
- **Custom Prompts**: Prompt features disabled by default
- **Easy Removal**: Clean uninstall available anytime
- **Dry-Run Safety**: Critical operations support `--dry-run` to preview changes safely

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

## Learn More

**[Complete Documentation](https://chief.reonetlabs.us)** - Installation, tutorials, examples, and advanced features

**[Quick Start Guide](https://chief.reonetlabs.us/getting-started)** - Get productive in 5 minutes

**[Plugin Development](https://chief.reonetlabs.us/plugin-development)** - Create and share your own plugins

## Contributing

Contributions welcome! See our [documentation](https://chief.reonetlabs.us/reference#contributing) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.
