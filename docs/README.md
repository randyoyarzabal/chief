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
