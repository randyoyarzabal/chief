# 🚀 Chief

## Bash Plugin Manager & Terminal Enhancement Tool

[![GitHub release](https://img.shields.io/badge/Download-Release%20v2.1.2-lightgrey.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![GitHub commits (since latest release)](https://img.shields.io/github/commits-since/randyoyarzabal/chief/latest.svg?style=social)](https://github.com/randyoyarzabal/chief/commits/master)

## What is Chief?

Chief is a Bash library system designed to help organize functions, aliases, and environment variables through "plug-ins."  It has additional features, including prompt customization and private SSH key management. It also installs various utility functions related to Git, SSL, OpenShift, Vault, and other services. Once installed, check out `chief.[tab]` to explore available features.

## Quick Start Installation

Run this command (one-line) to install, and you're all set!

```sh
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
