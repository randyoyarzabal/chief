# Version Management in Chief

## Overview

Chief uses a centralized version management system to maintain consistency across all scripts and documentation.

## Files Involved

### Core Constants File
- **`VERSION`** - Master file containing all version and URL constants
  - `CHIEF_VERSION` - Current version (e.g., "v2.1.2")  
  - `CHIEF_REPO` - GitHub repository URL
  - `CHIEF_WEBSITE` - Official website URL
  - `CHIEF_AUTHOR` - Author information
  - `CHIEF_GIT_REPO` - Git repository URL with .git extension
  - `CHIEF_INSTALL_GIT_BRANCH` - Default git branch for installation

### Scripts That Source Constants
- **`libs/core/chief_library.sh`** - Sources `${CHIEF_PATH}/VERSION`
- **`tools/install.sh`** - Sources `../VERSION` with fallback constants
- **`tools/uninstall.sh`** - Sources `${CHIEF_PATH}/VERSION` with fallback

### Documentation Files
- **`README.md`** - Contains version badge that should be updated manually
- **`docs/README.md`** - Contains version badge that should be updated manually

## Updating Versions

### For a New Release

1. **Update the master VERSION file:**
   ```bash
   # Edit /Users/royarzab/dev/chief/VERSION
   CHIEF_VERSION="v2.2.0"  # Update to new version
   ```

2. **Update documentation badges:**
   ```bash
   # Update version in README.md and docs/README.md
   [![GitHub release](https://img.shields.io/badge/Download-Release%20v2.2.0-lightgrey.svg?style=social)]
   ```

3. **Test the changes:**
   ```bash
   source chief.sh --lib-only
   echo "Version: $CHIEF_VERSION"
   ```

### Benefits

- **Single source of truth** - Only one place to update core constants
- **Consistency** - All scripts use the same values  
- **Maintainability** - Reduces chance of version mismatches
- **Fallback support** - Install/uninstall scripts work even if VERSION file is missing

### Fallback Strategy

The install and uninstall scripts include fallback constants to handle cases where:
- The VERSION file doesn't exist yet (during initial installation)
- Someone downloads just the install script without the full repository
- The Chief installation is corrupted or incomplete

This ensures robust operation in all scenarios.
