# Chief v3.0.2 Release Notes

## 🚀 Key New Features

### 🔐 Portable Vault Files (Major Feature)
- **Multi-system sync**: Store `.chief_shared-vault` in plugins repository for automatic sync across systems
- **Zero configuration**: Vault files detected automatically when loading remote plugins  
- **Secure portability**: Encrypted secrets follow users across laptop, server, and development environments
- **Cross-system consistency**: Same vault file everywhere via git synchronization
- **In-place usage**: Vault files used directly from plugins directory (no copying required)
- **Team collaboration**: Optional team vault sharing through repository
- **🚨 Security**: In team environments, `chief.vault_file-edit` (no params) edits SHARED team vault - always specify path for personal secrets

### ⚡ Improved Vault Editing UX
- **Eliminated double password prompts**: Default behavior no longer auto-loads after editing
- **Opt-in auto-loading**: Use `--load` flag when you want automatic loading after editing
- **Better workflow**: Edit vault without being prompted for password twice
- **Maintains security**: No compromise on encryption or security practices

## 🛡️ Enhanced Safety & Reliability (from v3.0.1)

### Plugin Safety
- **Smart Local Changes Protection**: Prevents accidental loss of plugin customizations during auto-updates
- Interactive prompts when local changes detected: commit first, disable auto-update, or force update
- Fixed `chief.plugins_update` to respect local changes (no more silent overwrites)

### Update Management  
- **Branch Configuration**: Track "main" (stable) or "dev" (bleeding-edge) with `CHIEF_CFG_UPDATE_BRANCH`
- **Fixed shallow clone issues**: Installation now supports full branch switching
- **Improved git operations**: Better handling of remote branches and updates

## 🎯 Benefits for Users

### **Multi-System Portability** 🚀
- **Same setup everywhere**: Plugins and encrypted secrets sync automatically across all your systems
- **Zero reconfiguration**: Once set up, Chief works identically on laptop, server, and CI/CD
- **Secure secret sharing**: Encrypted vault files travel with your plugins via git

### **Enhanced User Experience** ⚡
- **No more double passwords**: Vault editing workflow dramatically improved
- **Protected local changes**: Auto-updates won't accidentally delete your plugin customizations
- **Better error handling**: Clear prompts and guidance when conflicts arise

### **Team Collaboration** 👥
- **Optional team vaults**: Share encrypted secrets alongside shared plugins
- **Safe plugin updates**: Team members protected from losing local modifications
- **Consistent environments**: Same functions, aliases, and tools across the entire team

## 📋 Upgrade Notes

### For Existing Users (v3.0.1 → v3.0.2)
- **No breaking changes**: All existing configurations remain compatible
- **New vault features**: Automatic if you store `.chief_shared-vault` in plugins repo
- **Better editing UX**: `chief.vault_file-edit` no longer auto-loads by default (use `--load` if desired)

### For New Users
- **Full clone installation**: New installs support branch switching out of the box
- **Portable vault ready**: Simply add `.chief_shared-vault` to your plugins repo for cross-system sync
- **⚠️ Team Security**: Use `chief.vault_file-edit ~/.personal-vault` for private secrets, not `chief.vault_file-edit` alone

---

**Full details**: See [UPDATES](UPDATES) file for complete changelog and technical details.
