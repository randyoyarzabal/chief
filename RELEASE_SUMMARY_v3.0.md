# Chief v3.0 Release Summary

## 🚀 Major New Features

### New Configuration Management
- **`chief.config_set`**: Set configuration options directly from command line
- Interactive prompts with `--yes` flag for automation
- `--list` option to view all configuration variables

### Complete Help System Rewrite
- **`chief.help`**: New categorized help system with search (`--search`) and compact mode (`--compact`)
- **`chief.whereis`**: Complete rewrite - finds ALL occurrences with exact line numbers

### Python Virtual Environment Management
- **`chief.python_create_ve`**: Create virtual environments
- **`chief.python_start_ve`**: Smart activation with detection
- **`chief.python_stop_ve`**: Clean deactivation

### Enhanced SSH Key Management
- Support for **all SSH key types** (RSA, ed25519, ECDSA, etc.)
- **Selective key loading** via symlinks
- Improved `chief.ssh_create_keypair` with modern algorithms

### Plugin Development Enhancements
- **VSCode Integration**: Edit plugins with `chief.plugin --code <name>`
- Automatic detection and fallback to default editor

## ⚠️ Breaking Changes

### SSH Configuration Changes (Action Required)

**1. SSH Key Extension Change:**
```bash
# OLD: Keys needed .rsa extension
~/.ssh/id_rsa

# NEW: Keys need .key extension  
~/.ssh/id_rsa.key
```

**2. Configuration Variable Renamed:**
```bash
# OLD
CHIEF_CFG_RSA_KEYS_PATH="$HOME/.ssh"

# NEW
CHIEF_CFG_SSH_KEYS_PATH="$HOME/.ssh"
```

## 📋 Upgrade Instructions

### For v2.x Users

**1. Update SSH Configuration:**
```bash
# Edit your chief.config file and change:
# CHIEF_CFG_RSA_KEYS_PATH → CHIEF_CFG_SSH_KEYS_PATH

# Or use the new command:
chief.config_set ssh_keys_path "$HOME/.ssh"
```

**2. Update SSH Keys:**
```bash
# Option A: Selective loading (recommended)
cd ~/.ssh
ln -s id_rsa mykey.key           # RSA key
ln -s id_ed25519 mykey_ed.key    # ed25519 key

# Option B: Load all keys
mv id_rsa id_rsa.key
mv id_ed25519 id_ed25519.key
```

**3. Add New Configuration Options:**
```bash
# Add these new options to chief.config:
CHIEF_CFG_CONFIG_SET_INTERACTIVE=true
CHIEF_CFG_MULTILINE_PROMPT=false
CHIEF_CFG_AUTOCHECK_UPDATES=false
CHIEF_CFG_COLORED_LS=false
```

## 🐛 Critical Bug Fixes

- **Fixed `chief.update`**: Critical directory change bug resolved
- **Installation script**: Fixed prompt setup and validation
- **Terminal compatibility**: Improved icon handling

## 🎨 User Experience Improvements

- **Clean help output**: Removed repetitive prefixes
- **Better documentation**: Enhanced README with feature highlights  
- **Improved installation**: Better messaging and validation
- **Standardized usage**: Consistent formatting across all functions

## 🔧 New Configuration Options

- `CHIEF_CFG_CONFIG_SET_INTERACTIVE`: Control confirmation prompts
- `CHIEF_CFG_MULTILINE_PROMPT`: Enable multi-line prompt layout
- `CHIEF_CFG_AUTOCHECK_UPDATES`: Auto-check for updates on startup
- `CHIEF_CFG_COLORED_LS`: Colorize ls command output
- `CHIEF_CFG_SSH_KEYS_PATH`: Path to SSH keys (renamed from RSA_KEYS_PATH)

## 📖 Quick Start After Upgrade

```bash
# Check your configuration
chief.config_set --list

# View new help system
chief.help

# Test SSH key loading (if configured)
chief.ssh_load_keys

# Create your first plugin with VSCode
chief.plugin --code mytools
```

---

**Full changelog available in [UPDATES](UPDATES)**
