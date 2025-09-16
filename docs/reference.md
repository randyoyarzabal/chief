---
layout: default
title: Reference
description: "Complete command reference, examples, and additional resources"
---

[← Back to Documentation](index.html)

# Reference

Complete command reference, examples, tutorials, and additional resources.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## 📖 Complete Command Reference

### Core Chief Commands

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

### Plugin Management

```bash
# Create/edit plugins
chief.plugin mytools          # Create or edit 'mytools' plugin
chief.plugin list             # List all available plugins

# Plugin discovery
chief.whereis function_name   # Find where function is defined
chief.help plugins            # Show plugin-provided commands

# Plugin management
chief.plugins_update          # Update remote plugins (if configured)
```

### System Management

```bash
# Update Chief
chief.update

# Check for updates
chief.update --check

# Version information
chief.version

# Uninstall Chief
chief.uninstall
```

---

## 📖 Installation Methods

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

---

## 📖 Advanced Examples & Tutorials

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

function devops.deploy() {
    local environment="${1:-staging}"
    echo "Deploying to $environment..."
    
    case "$environment" in
        staging)
            kubectl apply -f k8s/staging/
            ;;
        production)
            if chief.etc_confirm "Deploy to PRODUCTION?"; then
                kubectl apply -f k8s/production/
            fi
            ;;
        *)
            echo "Unknown environment: $environment"
            return 1
            ;;
    esac
}
```

### Example 2: Project Management Plugin

```bash
# Create project-specific plugin
chief.plugin myapp

function myapp.setup() {
    cd ~/projects/myapp
    npm install
    docker-compose up -d
}

function myapp.deploy() {
    cd ~/projects/myapp
    ./deploy.sh production
}

function myapp.logs() {
    tail -f ~/projects/myapp/logs/app.log
}

function myapp.test() {
    cd ~/projects/myapp
    npm test
}
```

### Example 3: Git Workflow Plugin

```bash
# Create git workflow plugin
chief.plugin gitflow

function gitflow.feature_start() {
    local feature_name="$1"
    if [[ -z "$feature_name" ]]; then
        echo "Usage: gitflow.feature_start <feature-name>"
        return 1
    fi
    
    git checkout develop
    git pull origin develop
    git checkout -b "feature/${feature_name}"
    echo "Started feature: ${feature_name}"
}

function gitflow.feature_finish() {
    local current_branch=$(git branch --show-current)
    
    if [[ ! "$current_branch" =~ ^feature/ ]]; then
        echo "Not on a feature branch"
        return 1
    fi
    
    git checkout develop
    git merge "${current_branch}"
    git branch -d "${current_branch}"
    echo "Finished feature: ${current_branch}"
}

function gitflow.hotfix() {
    local version="$1"
    if [[ -z "$version" ]]; then
        echo "Usage: gitflow.hotfix <version>"
        return 1
    fi
    
    git checkout main
    git pull origin main
    git checkout -b "hotfix/${version}"
    echo "Started hotfix: ${version}"
}
```

### Example 4: Team Collaboration Plugin

```bash
# Create team plugin with shared utilities
chief.plugin team

function team.standup() {
    echo "📅 Daily Standup - $(date)"
    echo "🎯 Yesterday:"
    git log --oneline --since="yesterday" --author="$(git config user.email)"
    echo ""
    echo "🚀 Today's Plan:"
    echo "  • Check JIRA tickets"
    echo "  • Review PRs"
    echo "  • Continue feature development"
}

function team.pr_review() {
    local pr_number="$1"
    if [[ -z "$pr_number" ]]; then
        echo "Usage: team.pr_review <pr-number>"
        return 1
    fi
    
    gh pr checkout "$pr_number"
    git log --oneline main..HEAD
    echo "Ready to review PR #${pr_number}"
}

function team.deploy_status() {
    echo "🚀 Deployment Status:"
    echo "Staging: $(curl -s https://staging.myapp.com/health | jq -r .status)"
    echo "Production: $(curl -s https://myapp.com/health | jq -r .status)"
}
```

---

## 🛟 Comprehensive Troubleshooting

### Installation Issues

#### Q: Chief commands not found after installation

```bash
# Solution: Restart terminal or source config file
source ~/.bash_profile

# Check if Chief is loaded
echo $CHIEF_PATH
chief.help
```

#### Q: "Bad substitution" or "Syntax error" messages

```bash
# Check bash version - Chief requires Bash 4.0+
bash --version

# If using older bash (like macOS default), upgrade:
# macOS: brew install bash
# Linux: Update your package manager

# Ensure you're running bash
echo $SHELL
bash  # Switch to bash if needed
```

#### Q: Permission denied during installation

```bash
# Ensure write access to home directory
ls -la ~ | grep chief

# Fix permissions if needed
chmod 755 ~/.chief
chmod 644 ~/.chief_config.sh
```

### Configuration Issues

#### Q: Configuration changes not taking effect

```bash
# Reload Chief
chief.reload

# Check configuration syntax
bash -n ~/.chief_config.sh

# View current configuration
chief.config_show
```

#### Q: Vault functions not working

```bash
# Check if ansible is installed (optional dependency)
ansible-vault --version

# Install if needed:
# macOS: brew install ansible
# Linux: pip3 install ansible-core
# Windows: pip install ansible-core

# Check vault file permissions
ls -la ~/.chief_vault*
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

### Plugin Issues

#### Q: Plugins not loading

```bash
# Check plugin directory and file naming
ls ~/chief_plugins/*_chief-plugin.sh

# Verify plugin syntax
bash -n ~/chief_plugins/myplugin_chief-plugin.sh

# Check plugin path configuration
chief.config_show | grep PLUGINS_PATH

# Reload plugins
chief.reload
```

#### Q: Remote plugin sync not working

```bash
# Check Git configuration
cd "$CHIEF_CFG_PLUGINS_PATH"
git status
git remote -v

# Force update
chief.plugins_update --force

# Reset repository
rm -rf "$CHIEF_CFG_PLUGINS_PATH"
chief.reload  # Will re-clone
```

#### Q: SSH keys not auto-loading

```bash
# Verify key naming (must end in .key) and path
ls ~/.ssh/*.key

# Check configuration
chief.config_show | grep SSH_KEYS_PATH

# Manually load keys
ssh-add ~/.ssh/id_rsa
```

### Performance Issues

#### Q: Chief loading slowly

```bash
# Disable non-essential features
chief.config_set banner false
chief.config_set hints false
chief.config_set autocheck_updates false

# Check for large plugin files
find ~/chief_plugins -name "*.sh" -size +1M

# Enable debug mode to identify bottlenecks
export CHIEF_DEBUG=1
source ~/.bash_profile
```

### Advanced Debugging

#### Enable Debug Mode

```bash
# Enable debug output
export CHIEF_DEBUG=1
source ~/.bash_profile

# This shows detailed loading information
```

#### Check Dependencies

```bash
# Verify all requirements
bash --version     # Should be 4.0+
git --version      # Should be 2.0+
ansible-vault --version 2>/dev/null || echo "Ansible not installed (optional)"
oc version --client 2>/dev/null || echo "OpenShift CLI not installed (optional)"
```

#### Reset Chief Completely

```bash
# Backup configuration
cp ~/.chief_config.sh ~/.chief_config.sh.backup

# Remove Chief
chief.uninstall

# Clean install
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"

# Restore configuration
cp ~/.chief_config.sh.backup ~/.chief_config.sh
chief.reload
```

---

## 🤖 Contributing

We welcome contributions! Here's how to get involved:

### Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
4. **Make** your changes
5. **Test** thoroughly
6. **Commit** your changes (`git commit -m 'Add amazing feature'`)
7. **Push** to the branch (`git push origin feature/amazing-feature`)
8. **Open** a Pull Request

### Development Setup

```bash
# Clone your fork
git clone git@github.com:yourusername/chief.git
cd chief

# Install in development mode
./tools/install.sh

# Make changes and test
chief.reload

# Run tests (if available)
bash tests/run_tests.sh
```

### Contribution Guidelines

- **Code Style**: Follow existing bash scripting conventions
- **Documentation**: Update docs for new features
- **Testing**: Test on multiple bash versions and platforms
- **Commits**: Use clear, descriptive commit messages
- **Pull Requests**: Include description of changes and testing done

### Areas for Contribution

- **New Plugins**: Create useful plugins for common workflows
- **Bug Fixes**: Fix issues and improve stability
- **Documentation**: Improve guides and examples
- **Testing**: Add test coverage and CI/CD improvements
- **Performance**: Optimize loading times and memory usage

### Development Resources

- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck](https://www.shellcheck.net/) - Static analysis tool
- [Chief Plugin Template](https://github.com/randyoyarzabal/chief/blob/main/templates/chief_plugin_template.sh)

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](https://github.com/randyoyarzabal/chief/blob/main/LICENSE) file for details.

### License Summary

- ✅ **Commercial use**
- ✅ **Modification**
- ✅ **Distribution**
- ✅ **Private use**
- ❌ **Liability**
- ❌ **Warranty**

---

## 🙏 Acknowledgments

- **Git Project** - Git completion and prompt scripts
- **Bash Community** - Inspiration from various Bash framework projects
- **Contributors** - Everyone who has contributed to Chief's development
- **Users** - Feedback and bug reports that make Chief better

### Special Thanks

- Built with ❤️ for the terminal-loving community
- Inspired by the need for clean, organized shell environments
- Designed to enhance productivity without breaking existing setups

---

## 🔗 External Resources

### Official Links

- **[GitHub Repository](https://github.com/randyoyarzabal/chief)** - Source code and issue tracking
- **[Latest Release](https://github.com/randyoyarzabal/chief/releases/latest)** - Download latest version
- **[Issues](https://github.com/randyoyarzabal/chief/issues)** - Bug reports and feature requests
- **[Discussions](https://github.com/randyoyarzabal/chief/discussions)** - Community discussions

### Documentation

- **[Version Management](version-management.html)** - Technical version information
- **[Plugin Template](https://github.com/randyoyarzabal/chief/blob/main/templates/chief_plugin_template.sh)** - Starting point for new plugins
- **[Configuration Template](https://github.com/randyoyarzabal/chief/blob/main/templates/chief_config_template.sh)** - Default configuration

### Community Resources

- **Bash Learning**: [Bash Guide for Beginners](https://tldp.org/LDP/Bash-Beginners-Guide/html/)
- **Advanced Bash**: [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- **Shell Scripting**: [ShellCheck](https://www.shellcheck.net/) for script analysis

---

*Need help? Each page has detailed guides and examples. Still stuck? Check our [troubleshooting section](#-comprehensive-troubleshooting) or [open an issue](https://github.com/randyoyarzabal/chief/issues).*

---

[← Back to Documentation](index.html)
