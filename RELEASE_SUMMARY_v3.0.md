# Chief v3.0.1 Release Summary

## 🚀 Key Improvements

### 🔐 Portable Vault Files
- **Multi-system sync**: Store `.chief_secret-vault` in plugins repository for automatic sync
- **Zero configuration**: Vault files detected automatically when loading remote plugins
- **Secure portability**: Encrypted secrets follow users across systems via git
- **Cross-system consistency**: Same vault file on laptop, server, and development environments
- **In-place usage**: Vault files used directly from plugins directory

### 🛡️ Enhanced Plugin Safety

- **Smart Local Changes Protection**: Prevents accidental loss of plugin customizations during auto-updates
- Interactive prompts when local changes detected: commit first, disable auto-update, or force update
- Guides users with exact commands to safely handle modifications

### 🔧 Flexible Update Management

- **Branch Configuration**: Track "main" (stable) or "dev" (bleeding-edge) with `CHIEF_CFG_UPDATE_BRANCH`
- **Improved Update Process**: Fixed branch switching and pull operations
- **Reinstall Support**: Ability to reinstall tracking different branches

### 📂 Plugin Configuration Clarity

- **Path Separation**: Clear distinction between local plugin directory and remote repo paths
- **`CHIEF_CFG_PLUGINS_PATH`**: Local plugin directory AND remote repo clone location
- **`CHIEF_CFG_PLUGINS_GIT_PATH`**: Relative path within remote repo (empty = repo root)

### 🔧 Bug Fixes & Reliability

- **Vault Plugin**: Fixed path resolution when running from different directories
- **Platform Detection**: Enhanced version/distribution detection for better compatibility
- **Installation**: Improved documentation and setup process

## 🎯 Benefits for Users

### **Team Collaboration**

- Safe auto-updates preserve local plugin modifications
- Clear plugin path configuration reduces setup confusion
- Reliable branch tracking for stable vs bleeding-edge updates

### **Developer Experience**

- Interactive prompts prevent data loss
- Better error handling and user guidance
- Consistent behavior across different working directories

### **System Reliability**

- Enhanced path resolution for cross-directory operations
- Improved git operations with proper error handling
- Platform-aware installation and configuration

## 📋 Upgrade Notes

### For Existing Users

- Configuration remains backward compatible
- New safety features activate automatically with `CHIEF_CFG_PLUGINS_GIT_AUTOUPDATE=true`
- Branch configuration defaults to "main" for stability

### For Teams

- Local changes protection ensures team members don't lose customizations
- Plugin path clarification simplifies team repository setup
- Consistent update behavior across team environments

---

**Full details**: See [UPDATES](UPDATES) file for complete changelog and technical details.
