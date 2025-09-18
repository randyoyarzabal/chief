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

## 📋 Upgrade Notes

### For Everyone
- **No breaking changes** - all existing setups continue working
- **New test infrastructure** automatically available
- **Air-gapped support** ready for restricted environments

### For Developers
- Run `./test/run-tests.sh` locally before pushing
- Use `-v` flag for verbose test output
- Monitor build status in GitHub Actions

---

**Full details**: See [UPDATES](UPDATES) file for complete changelog and technical details.
