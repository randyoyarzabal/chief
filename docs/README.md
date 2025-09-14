<<<<<<< Updated upstream
[![GitHub release](https://img.shields.io/badge/Download-Release%20v2.1.1-lightgrey.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![GitHub commits (since latest release)](https://img.shields.io/github/commits-since/randyoyarzabal/chief/latest.svg?style=social)](https://github.com/randyoyarzabal/chief/commits/master)

## What is Chief?

Chief is a Bash library system designed to help organize functions, aliases, and environment variables through "plug-ins."  It has additional features, including prompt customization and private SSH key management. It also installs various utility functions related to Git, SSL, OpenShift, Vault, and other services. Once installed, check out `chief.[tab]` to explore available features.

## Quick Start Installation

Run this command (one-line) to install, and you're all set!

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

_Don't worry; In case Bash isn't your default shell, the installation only affects your Bash shell when you invoke it. This won't interfere with any other shell, esp. if you are currently using `zsh` or a custom prompt, such as Oh My Bash or Oh My Zsh._

Running the `install` command above will:

- Install the latest version of Chief by cloning the git repo to `$HOME/.chief`
- Configure using a copy of the default configuration template to `$HOME/.chief_config.sh`
- Add the library loading lines to `$HOME/.bashrc` (file will be created if it doesn't exist)
- To start, Chief, restart your terminal or `source ~/.bashrc`.

Type `chief.config` to edit the configuration to do things such as turn off the banner, hints, enable prompt customizations, etc.

## What's next?

Get your functions, aliases, and all things Bash organized with plugins:

- `chief.plugin` to edit the default plugin.
- `chief.plugin [plug-in name]` to create/edit a plugin. Don't worry, if the plugin doesn't, it can automatically create it.
- `chief.plugins` to cd into your plugins directory.
- `chief.plugins_update` to update/load from git repository when `CHIEF_CFG_PLUGINS_TYPE='remote'`.
- `chief.plugin -?` to list plugins.
- `chief.whereis <function | alias>` to locate the exact location of the function or alias.

Explore the following commands:

- `chief.[tab]` to see available built-in commands.
- `chief.config` to edit the configuration and explore features.
- `chief.update` to pull the latest version or set `CHIEF_CFG_AUTOCHECK_UPDATES=true`
- `chief.bash_profile` to edit your .bash_profile file.
- `chief.bashrc` to edit your .bashrc file.
- `chief.* -?` to display the help text for any chief command.
- `type chief.*` on any command if you're curious or want to reuse the internal functions.

**Notes:**

- `chief.plugin`, `chief.bash_profile`, and `chief.bashrc` will automatically load (source) if changes are detected.  You don't need to restart your terminal anymore!
- You can enable the above text in Chief by setting `CHIEF_CFG_HINTS=true` or `chief.help`

**Don't have a git-aware prompt?** Try Chief's custom prompt, set `CHIEF_CFG_PROMPT=true`.

**Want to load and manage plugins from a git repo?** Enable remote repo by setting `CHIEF_CFG_PLUGINS_TYPE='remote'` and set other git options in the configuration.

**Tired of passing SSH keys when logging to remote hosts?**  Try Chief's SSH key auto-loader, set `CHIEF_CFG_RSA_KEYS_PATH=<ssh keys path>`.  Just ensure that your private keys end with `*.rsa`; you can also use symbolic links.  This allows you to select and choose what you want to load.

**Don't want to keep typing `chief.`?**  Try setting the Chief alias. For example, `CHIEF_CFG_ALIAS=cf`.

## Configurable Features

- Safely run alongside Zsh and use custom prompts, such as Oh My Bash or Oh My Zsh.
- Management of Bash variables, aliases, and functions
- Support for local and remote git plugins
- Auto creation of new plugins
- Automated reload of edited files (plugins, .bashrc, .bash_profile)
- Private SSH key auto-loading
- Custom prompt; if you're not already using one
  - Git prompt
  - Colored prompt
  - Working directory

## Manual Installation

These steps are automated by the [Quick Start Installation](#quick-start-installation); therefore, they are not necessary unless you want to install Chief manually.

1. Clone the repo to your desired location, for example: `$HOME/.chief`

    ```sh
    git clone --depth=1 https://github.com/randyoyarzabal/chief.git $HOME/.chief
    ```

2. Make a copy a config template from the 'templates' directory. Note that it needs to be placed outside the root of Chief.

    ```sh
    cp templates/chief_config_template.sh ~/.chief_config.sh
    ```

    Modify the configuration with `chief.config` to suit your needs.

3. Define the following variables and 'source' chief.sh in your start-up script (.bash_profile, for example).

    For example:

    ```sh
    # Chief Environment
    export CHIEF_CONFIG="$HOME/.chief_config.sh"
    export CHIEF_PATH="$HOME/.chief"
    source ${CHIEF_PATH}/chief.sh
    ```

4. That's it. You're ready to use Chief! Restart your terminal.

## Uninstallation

Run this command (one-line) to uninstall. _All user-plugin files and plugin directories will not be removed._:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/uninstall.sh)"
```

Or

`chief.uninstall` within the tool.

Running the `uninstall` command will:

- Remove the installation from `$HOME/.chief`
- Backup `$HOME/.chief_config.sh` to `$HOME/.chief_config.sh.backup`
- Remove `$HOME/.chief_config.sh`
- Remove the library loading lines from `$HOME/.bashrc`
- Restart your terminal to complete the uninstallation.

## Configuration Options

TODO: Table of config options

## Built-in Plug-ins

TODO: Table of core plugins

## Contribute

All contributions are welcome. You can create your branch and submit a pull request against the main branch.

Helpful Reference Sites:

- [Bash Reference Page](https://www.gnu.org/software/bash/manual/bash.html)
=======
# 🚀 Chief

## Bash Plugin Manager & Terminal Enhancement Tool

[![GitHub release](https://img.shields.io/badge/Download-Release%20v3.0-lightgrey.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![GitHub commits (since latest release)](https://img.shields.io/github/commits-since/randyoyarzabal/chief/latest.svg?style=social)](https://github.com/randyoyarzabal/chief/commits/master)

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

## 🗑️ Uninstallation

### Method 1: Using Chief Command (Easiest)

```bash
# If Chief is currently installed and working
chief.uninstall
```

### Method 2: Quick Uninstall (One-liner)

```bash
# Works from anywhere, even if Chief installation is broken
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/uninstall.sh)"
```

### Method 3: Manual Methods

```bash
# Option A: Using local uninstall script
~/.chief/tools/uninstall.sh

# Option B: Complete manual removal
rm -rf ~/.chief
rm -f ~/.chief_config.sh
# Then manually remove Chief lines from ~/.bash_profile
```

**What happens during uninstall:**

- ✅ Installation directory (`~/.chief`) is completely removed
- ✅ Configuration file is backed up as `~/.chief_config.sh.backup` then removed
- ✅ Shell configuration (`~/.bash_profile`) is cleaned up automatically
- ✅ Custom plugins directory remains untouched (if different from `~/.chief`)

> **Note:** Your personal plugins and any custom configurations outside the Chief installation directory will not be affected.

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
>>>>>>> Stashed changes
