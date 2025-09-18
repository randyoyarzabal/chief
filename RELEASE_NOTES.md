# Chief v3.0.4-dev Release Notes (Unreleased)

## 🚀 What's New

### 🔐 Air-Gapped Installation Support
- **`./tools/install.sh --local`** - Install from local files in disconnected environments
- **Security compliant** - No internet required during installation
- **Complete transparency** - All files visible before installation
- **Manual update control** - Updates require explicit file replacement

### 🏗️ Private Function Namespace Refactoring
- **All 39 private functions** now use `__chief_*` prefix
- **Prevents conflicts** with other bash utilities
- **Clean refactoring** - no backward compatibility aliases

### 🔄 GitHub Actions CI/CD Integration
- **Automated testing** on every push to main/dev branches
- **Cross-platform validation** (Ubuntu + macOS)
- **Build status visibility** with ✅/❌ on commits
- **Zero configuration** - works immediately

### 🧪 Comprehensive Test Suite
- **Syntax validation** using `bash -n`
- **Plugin structure validation** and naming conventions
- **Integration testing** for core functionality
- **Local + CI compatible** - run `./test/run-tests.sh`

### 🚀 Enhanced Version Management
- **Development workflow** with `-dev` suffix system
- **Release automation** via `__chief.bump` commands
- **Auto documentation** updates across all files

### 🔒 SSL/TLS Certificate Management
- **`chief.ssl.view_cert`** - Comprehensive certificate analysis with multiple display options
- **`chief.ssl.get_cert`** - Download certificates from remote servers with chain support
- **`chief.ssl.create_ca`** - Simple CA creation with minimal requirements (just run it!)
- **`chief.ssl.create_tls_cert`** - Easy certificate creation signed by your CA
- **Rich help documentation** and error handling for certificate operations

### ☸️ OpenShift Management Enhancements
- **`chief.oc.show_stuck_resources`** - Enhanced with `--fix` option to automatically remove finalizers from terminating resources
- **`chief.oc_delete_stuck_ns`** - Force delete stuck terminating namespaces using Red Hat's troubleshooting methodology
- **`chief.oc.approve_csrs`** - Complete rewrite with interactive/batch modes, filtering, and safety features
- **Professional documentation** and color-coded terminal output following codebase standards

### 🛠️ System Utilities Enhancement
- **`chief.etc.chmod-f`** - Enhanced file permission management with verbose/dry-run modes and validation
- **`chief.etc.chmod-d`** - Fixed naming consistency and added comprehensive directory permission management
- **`chief.etc.create_bootusb`** - Complete safety overhaul for bootable USB creation with multi-platform support
- **`chief.etc.copy_dotfiles`** - Enhanced dotfiles management with backup options and interactive confirmations

## 📋 Upgrade Notes

### ⚠️ BREAKING CHANGES

**Plugin Function Naming Convention Update**
All plugin functions now use consistent underscore notation for better uniformity:

**Before (v3.0.3 and earlier):**
- `chief.ssl.view_cert` → **Now:** `chief.ssl_view_cert`
- `chief.oc.login` → **Now:** `chief.oc_login` 
- `chief.aws.set_role` → **Now:** `chief.aws_set_role`
- `chief.etc.chmod-f` → **Now:** `chief.etc_chmod-f`

**Migration:** Update any scripts or aliases that reference the old dot notation.

### For Everyone
- **New test infrastructure** automatically available
- **Air-gapped support** ready for restricted environments

### For Developers
- Run `./test/run-tests.sh` locally before pushing
- Use `-v` flag for verbose test output
- Monitor build status in GitHub Actions

---

**Full details**: See [UPDATES](UPDATES) file for complete changelog and technical details.
