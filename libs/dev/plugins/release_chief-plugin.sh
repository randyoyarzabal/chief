#!/usr/bin/env bash
# Copyright (C) 2025 Randy E. Oyarzabal <github@randyoyarzabal.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
########################################################################

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

# Chief Plugin File: release_chief-plugin.sh
# Author: Randy E. Oyarzabal
#
# DEV plugin: release tooling for Chief maintainers. It is NOT a user feature.
# Chief loads libs/dev/plugins only when BOTH are true (see __chief_dev_tools_state):
#   1. Chief's own checkout ($CHIEF_PATH) is on the "dev" branch, and
#   2. CHIEF_CFG_DEV_TOOLS=true in the config   (chief.config-set dev_tools true)
# On main or any release checkout it never loads, and release archives leave libs/dev out
# (.gitattributes export-ignore).
#
# Commands:
#   chief.release_status                       Where the release stands and what to run next
#   chief.release_prepare                      Optional: stage the release on dev (tests, bump, commit, push)
#   chief.release_publish --next vX.Y.Z        The whole release, resuming wherever it stands
#
# Overridable for tests: CHIEF_RELEASE_REMOTE (default origin), CHIEF_RELEASE_REPO (owner/name),
# CHIEF_RELEASE_CI_INTERVAL (seconds, default 10), CHIEF_RELEASE_CI_TIMEOUT (seconds, default 1800),
# CHIEF_RELEASE_TEST_CMD (command for the test step, default tests/run-tests.sh).


# VERSION BUMP (moved from the core library; was __chief.bump)
########################################################################

function __chief_release_bump() {
  local usage="Usage: $FUNCNAME release|next-dev <vX.Y.Z>|<vX.Y.Z> [--dry-run] [--backup] [--skip-tests]

Internal: rewrites VERSION, release notes and README/docs badges for a release or a new
dev cycle. Called by chief.release_prepare / chief.release_publish; it never commits,
pushes, or touches your config.
  release             vX.Y.Z-dev -> vX.Y.Z (renames release-notes/vX.Y.Z-dev.md)
  next-dev vA.B.C     vX.Y.Z -> vA.B.C-dev (creates release-notes/vA.B.C-dev.md)"

  # Parse arguments
  local new_version=""
  local target_version=""
  local dry_run=false
  local create_backups=false
  local skip_tests=false
  local positional_args=()
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-h)
        echo -e "$usage"
        return 0
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --backup)
        create_backups=true
        shift
        ;;
      --skip-tests)
        skip_tests=true
        shift
        ;;
      -*)
        __chief_print_error "Unknown option: $1"
        echo -e "$usage"
        return 1
        ;;
      *)
        positional_args+=("$1")
        shift
        ;;
    esac
  done
  
  # Handle positional arguments
  if [[ ${#positional_args[@]} -eq 0 ]]; then
    __chief_print_error "New version is required"
    echo -e "$usage"
    return 1
  elif [[ ${#positional_args[@]} -eq 1 ]]; then
    new_version="${positional_args[0]}"
  elif [[ ${#positional_args[@]} -eq 2 && "${positional_args[0]}" == "next-dev" ]]; then
    new_version="${positional_args[0]}"
    target_version="${positional_args[1]}"
  else
    __chief_print_error "Too many arguments"
    echo -e "$usage"
    return 1
  fi
  
  
  # Get current version early for keyword processing
  # Read the file, not $CHIEF_VERSION: the loaded value goes stale during a release.
  local current_version
  current_version="$(__chief_release_version)"
  
  # Handle special keywords
  if [[ "$new_version" == "release" ]]; then
    if [[ "$current_version" =~ ^(v[0-9]+\.[0-9]+(\.[0-9]+)?)-dev$ ]]; then
      new_version="${BASH_REMATCH[1]}"
      __chief_print_info "Release mode: Converting $current_version → $new_version"
    else
      __chief_print_error "Current version ($current_version) is not a -dev version"
      return 1
    fi
  elif [[ "$new_version" == "next-dev" ]]; then
    # Allow both release versions (v3.1.1) and dev versions (v3.1.1-dev) for next-dev workflow
    if [[ "$current_version" =~ ^v([0-9]+)\.([0-9]+)(\.([0-9]+))?(-dev)?$ ]]; then
      local major="${BASH_REMATCH[1]}"
      local minor="${BASH_REMATCH[2]}"
      local patch="${BASH_REMATCH[4]:-0}"
      
      if [[ -n "$target_version" ]]; then
        # Use provided target version
        if [[ ! "$target_version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
          __chief_print_error "Invalid target version format: $target_version"
          __chief_print_error "Expected format: v4.0 or v4.0.0 (must be prefixed with 'v')"
          return 1
        fi
        new_version="${target_version}-dev"
        __chief_print_info "Next dev mode: Converting $current_version → $new_version (custom target)"
      else
        # Auto-increment minor version for next development cycle
        ((minor++))
        new_version="v${major}.${minor}.0-dev"
        __chief_print_info "Next dev mode: Converting $current_version → $new_version (auto-increment)"
      fi
    else
      __chief_print_error "Current version ($current_version) is not a valid release version"
      return 1
    fi
  fi
  
  # Validate version format (MUST be prefixed with 'v')
  # Accept v4.0, v4.0.0 formats, and -dev versions for development workflow
  if [[ ! "$new_version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?(-dev)?$ ]]; then
    __chief_print_error "Invalid version format: $new_version"
    __chief_print_error "Expected format: v4.0 or v4.0.0 (must be prefixed with 'v'), optionally with -dev suffix"
    return 1
  fi
  
  # Normalize to full semantic version (add .0 if missing patch version)
  if [[ "$new_version" =~ ^v[0-9]+\.[0-9]+$ ]]; then
    new_version="${new_version}.0"
  fi
  
  # Test validation for releases only
  local is_release_workflow=false
  local is_next_dev_workflow=false
  
  if [[ "${positional_args[0]}" == "release" ]] || [[ ! "$new_version" =~ -dev$ ]]; then
    is_release_workflow=true
  elif [[ "${positional_args[0]}" == "next-dev" ]]; then
    is_next_dev_workflow=true
  fi
  
  # Only run tests for release workflows (next-dev skips tests since it follows a successful release)
  if ! $dry_run && ! $skip_tests && $is_release_workflow; then
    local test_script="${CHIEF_PATH}/tests/run-tests.sh"
    
    if [[ -f "$test_script" ]]; then
      __chief_print_info "Running test suite (required for releases)..."
      
      if ! "$test_script"; then
        __chief_print_error "Test suite failed!"
        __chief_print_error "Cannot proceed with release while tests are failing."
        __chief_print_info "Fix failing tests or use --skip-tests (NOT recommended)"
        return 1
      else
        __chief_print_success "All tests passed! ✅"
        echo ""
      fi
    else
      __chief_print_warn "Test suite not found at: $test_script"
      __chief_print_warn "Proceeding without test validation (not recommended)"
    fi
  elif $skip_tests && $is_release_workflow; then
    __chief_print_warn "⚠️  SKIPPING TESTS FOR RELEASE - THIS IS DANGEROUS!"
    __chief_print_warn "Release versions should always pass tests before deployment."
    echo ""
  elif $is_next_dev_workflow; then
    __chief_print_info "Skipping tests for next-dev (tests passed in previous release cycle)"
    echo ""
  fi
  
  # Set version file path
  local version_file="${CHIEF_PATH}/VERSION"
  
  __chief_print_info "Chief Development Version Bump"
  __chief_print_info "Current version: $current_version"
  __chief_print_info "New version: $new_version"
  __chief_print_info "Dry run: $dry_run"
  echo ""
  
  # Check if versions are the same  
  if [[ "$current_version" == "$new_version" ]]; then
    __chief_print_warn "Version is already $new_version"
    if ! $dry_run; then
      __chief_print_info "Re-applying version to ensure consistency..."
    fi
  fi
  
  # Files to update with version references
  local files_to_update=(
    "${CHIEF_PATH}/VERSION"
    "${CHIEF_PATH}/README.md"
    "${CHIEF_PATH}/docs/index.md"
    "${CHIEF_PATH}/docs/getting-started.md"
  )
  
  # Special handling for next-dev workflow
  local is_next_dev=false
  if [[ "${positional_args[0]}" == "next-dev" ]]; then
    is_next_dev=true
    
    # Create version-specific release notes file  
    local release_notes_dir="${CHIEF_PATH}/release-notes"
    local release_notes_file="${release_notes_dir}/${new_version}.md"
    
    if ! $dry_run; then
      # Ensure release-notes directory exists
      mkdir -p "$release_notes_dir"
      
      # Create new release notes file if it doesn't exist
      if [[ ! -f "$release_notes_file" ]]; then
        __chief_print_info "Creating new release notes: release-notes/${new_version}.md"
        
        cat > "$release_notes_file" << EOF
# Chief ${new_version} Release Notes

## 🚀 What's New

### 🔧 Version ${new_version} Development

- Ready for development work on ${new_version}

## 📋 Upgrade Notes

### For Developers

- This is a development version - features and changes will be documented as they are implemented

---

**Full details**: See [release-notes](../release-notes/) directory for complete changelog and version history.
EOF
      else
        __chief_print_info "Release notes file already exists: release-notes/${new_version}.md"
      fi
    fi
    
    if $dry_run; then
      __chief_print_info "Would create new release notes file: release-notes/${new_version}.md"
    fi
  fi

  # Special handling for release workflow - transform dev release notes to final
  if $is_release_workflow && [[ "${positional_args[0]}" == "release" ]]; then
    local release_notes_dir="${CHIEF_PATH}/release-notes"
    local dev_release_notes="${release_notes_dir}/${new_version}-dev.md"
    local final_release_notes="${release_notes_dir}/${new_version}.md"
    
    if [[ -f "$dev_release_notes" ]]; then
      if ! $dry_run; then
        __chief_print_info "Transforming development release notes to final release..."
        __chief_print_info "  ${new_version}-dev.md → ${new_version}.md"
        
        # Transform the content: remove -dev references and update status
        # First, ensure we have content to work with
        if [[ ! -s "$dev_release_notes" ]]; then
          __chief_print_warn "Development release notes file is empty: $dev_release_notes"
          __chief_print_info "Creating basic release notes template..."
          
          cat > "$final_release_notes" << EOF
# Chief ${new_version} Release Notes

## 🚀 What's New in ${new_version}

### 🔧 Version ${new_version} Release

- Release version ${new_version}

## 📋 Upgrade Notes

### For Users

- This is a release version

---

**Status:** Released  
**Release Date:** ${new_version}  
**Breaking Changes:** TBD  
**New Features:** TBD
EOF
        else
          # Transform the content with more flexible patterns
          # Apply patterns in order that works with transformations
          sed -e 's/## 🚀 What'\''s New$/## 🚀 What'\''s New in '"${new_version}"'/g' \
              -e 's/## 🚀 What'\''s New in Development/## 🚀 What'\''s New in '"${new_version}"'/g' \
              -e 's/### 🔧 Version '"${new_version}"'-dev Development/### 🔧 Version '"${new_version}"' Release/g' \
              -e 's/- Ready for development work on '"${new_version}"'-dev/- Release version '"${new_version}"'/g' \
              -e 's/\*\*Status:\*\* Development in progress/\*\*Status:\*\* Released/g' \
              -e 's/\*\*Target Release:\*\* '"${new_version}"'/\*\*Release Date:\*\* '"${new_version}"'/g' \
              -e "s/${new_version}-dev/${new_version}/g" \
              "$dev_release_notes" > "$final_release_notes"
        fi
        
        # Remove the development version file
        rm "$dev_release_notes"
        __chief_print_success "Release notes updated for ${new_version} release"
      else
        __chief_print_info "Would transform: ${new_version}-dev.md → ${new_version}.md"
        __chief_print_info "Would update content to reflect released status"
      fi
    elif [[ ! -f "$final_release_notes" ]]; then
      if ! $dry_run; then
        __chief_print_warn "No development release notes found at: ${dev_release_notes}"
        __chief_print_info "Creating basic release notes for ${new_version}..."
        
        mkdir -p "$release_notes_dir"
        cat > "$final_release_notes" << EOF
# Chief ${new_version} Release Notes

## 🚀 What's New in ${new_version}

### 🔧 Version ${new_version} Release

- Release version ${new_version}

## 📋 Upgrade Notes

### For Users

- This is a release version

---

**Status:** Released  
**Release Date:** ${new_version}  
**Breaking Changes:** TBD  
**New Features:** TBD
EOF
        __chief_print_info "Created basic release notes: release-notes/${new_version}.md"
      else
        __chief_print_info "Would create basic release notes: release-notes/${new_version}.md"
      fi
    else
      __chief_print_info "Final release notes already exist: release-notes/${new_version}.md"
    fi
  fi

  # Update each file
  local updated_count=0
  for file in "${files_to_update[@]}"; do
    if [[ ! -f "$file" ]]; then
      __chief_print_warn "File not found, skipping: $(basename "$file")"
      continue
    fi
    
    # Note: No special UPDATES handling needed - using release-notes structure
    
    # Check if file already has the new version (both regular and badge formats)
    # Handle badge URL encoding with proper shields.io format: label-message-color
    local badge_current=""
    
    # For Download Release badge: should always show the latest stable version
    local download_release_version=""
    if [[ "${positional_args[0]}" == "next-dev" ]]; then
      # For next-dev: Download Release shows the current stable version (remove -dev from current)
      download_release_version="${current_version%-dev}"
    elif [[ "${positional_args[0]}" == "release" ]]; then
      # For release: Download Release shows the new release version
      download_release_version="${new_version}"
    else
      # Default case
      download_release_version="${new_version}"
    fi
    
    local badge_new_encoded="${download_release_version//-/--}"  # Double dashes for shields.io
    local badge_new="Download%20Release-${badge_new_encoded}"
    
    # For badge_current: determine what the current Download Release badge should contain
    local current_download_release_version=""
    if [[ "${positional_args[0]}" == "release" ]]; then
      # For release: current badge might show dev version, will change to release version
      current_download_release_version="${current_version%-dev}"  # Strip -dev to get stable version
    elif [[ "${positional_args[0]}" == "next-dev" ]]; then
      # For next-dev: current badge shows stable version, should continue showing stable version
      current_download_release_version="${current_version%-dev}"  # Strip -dev to get stable version
    else
      # Default case
      current_download_release_version="${current_version}"
    fi
    
    local badge_current_encoded="${current_download_release_version//-/--}"  # Double dashes for shields.io
    badge_current="Download%20Release-${badge_current_encoded}"
    
    # Handle dev badge updates for two-badge structure
    local dev_badge_current=""
    local dev_badge_new=""
    
    # For release workflow: v3.1.1-dev → v3.1.1, dev badge should show next dev version  
    if [[ "${positional_args[0]}" == "release" && "$current_version" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)-dev$ ]]; then
      local major="${BASH_REMATCH[1]}"
      local minor="${BASH_REMATCH[2]}"
      local patch="${BASH_REMATCH[3]}"
      # Next development cycle: increment minor version for next dev
      ((minor++))
      local current_encoded="${current_version//-/--}"  # Double dashes for shields.io
      dev_badge_current="Dev%20Branch-${current_encoded}"
      dev_badge_new="Dev%20Branch-v${major}.${minor}.0"
    # For next-dev workflow: v3.1.1 → v3.1.2-dev, dev badge should show the new dev version
    elif [[ "${positional_args[0]}" == "next-dev" ]]; then
      # Current version would be release version, new version would be dev version
      dev_badge_current="Dev%20Branch-.*"  # Pattern to match any current dev badge
      local dev_badge_new_encoded="${new_version//-/--}"  # Double dashes for shields.io
      dev_badge_new="Dev%20Branch-${dev_badge_new_encoded}"
    fi
    
    # Check if file already has the new version (check version first, then badges if they exist)
    local has_new_version=false
    local has_badges=false
    local badge_needs_update=false
    
    # Up to date only if the new version is present AND the old one is gone.
    # A plain substring check is not enough: "v3.2.0" matches inside "v3.2.0-dev".
    if grep -qF "$new_version" "$file" 2>/dev/null && ! grep -qF "$current_version" "$file" 2>/dev/null; then
      has_new_version=true
    fi
    
    # Check if file has badges at all
    if grep -q "shields\.io\|badge" "$file" 2>/dev/null; then
      has_badges=true
      # If it has badges, check if they need updating
      if ! grep -q "$badge_new" "$file" 2>/dev/null; then
        badge_needs_update=true
      fi
    fi
    
    # For README.md, also check content structure for dev vs release versions
    local readme_content_correct=true
    if [[ "$(basename "$file")" == "README.md" ]]; then
      if [[ "${positional_args[0]}" == "next-dev" ]]; then
        # For next-dev, README should have dev content structure (accept # Chief or # 🚀 Chief)
        if ! grep -qE "# (🚀 )?Chief \(Development Version\)" "$file" 2>/dev/null; then
          readme_content_correct=false
        elif ! grep -q "Warning.*development branch" "$file" 2>/dev/null; then
          readme_content_correct=false
        elif ! grep -q "Quick Install (Development Version)" "$file" 2>/dev/null; then
          readme_content_correct=false
        fi
      elif [[ "${positional_args[0]}" == "release" ]]; then
        # For release, README should have release content structure
        if ! grep -q "^# 🚀 Chief$" "$file" 2>/dev/null; then
          readme_content_correct=false
        elif grep -q "Warning.*development branch" "$file" 2>/dev/null; then
          readme_content_correct=false
        elif ! grep -q "^## ⚡ Quick Install$" "$file" 2>/dev/null; then
          readme_content_correct=false
        fi
      fi
    fi
    
    # File is up to date if version is correct AND (no badges OR badges are correct) AND README content is correct
    if $has_new_version && (! $has_badges || ! $badge_needs_update) && $readme_content_correct; then
      __chief_print_info "$(basename "$file"): Already up to date ($new_version)"
      continue
    fi
    
    if $dry_run; then
      # Describe what the real run would touch in this file
      local changes=()
      if grep -v "img\.shields\.io/badge/" "$file" 2>/dev/null | grep -qF "$current_version"; then
        changes+=("version")
      fi
      if grep -q "img\.shields\.io/badge/" "$file" 2>/dev/null; then
        changes+=("badges")
      fi
      if [[ "$(basename "$file")" == "README.md" ]]; then
        changes+=("content structure")
      fi
      if [[ ${#changes[@]} -eq 0 ]]; then
        __chief_print_info "$(basename "$file"): No version or badge references found; nothing to change"
        continue
      fi
      local changes_str
      changes_str="$(IFS='|'; echo "${changes[*]}")"
      __chief_print_info "$(basename "$file"): Would update ${changes_str//|/ + } ($current_version → $new_version)"
      continue
    fi
    
    # Create backup if requested
    if $create_backups; then
      cp "$file" "${file}.backup.$(date +%s)"
    fi
    
    # Perform replacements (both regular version and badge URLs)
    local success=true
    
    # Badge versions. Each badge has a fixed meaning regardless of branch:
    #   Download Release / Stable  -> latest *released* (stable) version, never "-dev"
    #   Dev Branch                 -> in-progress development version, always "-dev"
    # shields.io encodes a literal "-" inside the message as "--".
    local stable_version="" dev_version=""
    if [[ "${positional_args[0]}" == "release" ]]; then
      stable_version="${new_version}"
      if [[ "$current_version" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)-dev$ ]]; then
        dev_version="v${BASH_REMATCH[1]}.$((BASH_REMATCH[2] + 1)).0-dev"
      fi
    elif [[ "${positional_args[0]}" == "next-dev" ]]; then
      stable_version="${current_version%-dev}"
      dev_version="${new_version}"
    else
      stable_version="${new_version%-dev}"
      [[ "$new_version" == *-dev ]] && dev_version="${new_version}"
    fi
    local stable_enc="${stable_version//-/--}"
    local dev_enc="${dev_version//-/--}"
    # Matches a badge version token such as v3.1.4 or v3.2.0--dev (portable BRE, BSD + GNU sed)
    local ver_re='v[0-9][0-9.]*\(--dev\)\{0,1\}'
    local current_version_re="${current_version//./\\.}"

    # Update regular version references everywhere EXCEPT shields.io badge lines,
    # so a global replace can never turn a stable badge into a dev badge.
    if ! sed -i.tmp1 "/img\.shields\.io\/badge\//!s/${current_version_re}/${new_version}/g" "$file" 2>/dev/null; then
      success=false
    fi

    # Rewrite each badge explicitly from its intended meaning
    if $success && grep -q "img\.shields\.io/badge/" "$file" 2>/dev/null; then
      if ! sed -i.tmp2 \
        -e "s|Download%20Release-${ver_re}-|Download%20Release-${stable_enc}-|g" \
        -e "s|Download-Release%20${ver_re}-|Download-Release%20${stable_enc}-|g" \
        -e "s|Stable-${ver_re}-|Stable-${stable_enc}-|g" \
        "$file" 2>/dev/null; then
        success=false
      fi

      if $success && [[ -n "$dev_enc" ]]; then
        if grep -q "Dev%20Branch-" "$file" 2>/dev/null; then
          if ! sed -i.tmp_dev "s|Dev%20Branch-${ver_re}-|Dev%20Branch-${dev_enc}-|g" "$file" 2>/dev/null; then
            success=false
          fi
        elif [[ "$(basename "$file")" == "README.md" ]]; then
          # README has no Dev Branch badge yet: insert one right after the Download Release badge
          if ! sed -i.tmp_dev "s|\(\[!\[[^]]*\](https://img\.shields\.io/badge/Download%20Release-[^)]*)\]([^)]*)\)|\1 [![Dev Branch](https://img.shields.io/badge/Dev%20Branch-${dev_enc}-orange.svg?style=social)](https://github.com/randyoyarzabal/chief/tree/dev)|" "$file" 2>/dev/null; then
            success=false
          fi
        fi
      fi
    fi
    
    # For release bumps (not next-dev), remove "(Unreleased)" markers
    if $success && [[ "${positional_args[0]}" == "release" ]]; then
      # Handle different unreleased patterns
      if ! sed -i.tmp3 "s/## Unreleased (${new_version})/## ${new_version}/g" "$file" 2>/dev/null; then
        success=false
      fi
      if $success && ! sed -i.tmp4 "s/# Chief ${new_version} Release Notes (Unreleased)/# Chief ${new_version} Release Notes/g" "$file" 2>/dev/null; then
        success=false
      fi
    fi
    
    # Handle README.md content changes for dev vs release versions
    if $success && [[ "$(basename "$file")" == "README.md" ]]; then
      if [[ "${positional_args[0]}" == "release" ]]; then
        # RELEASE: Remove dev-specific content from README
        # 1. Remove "(Development Version)" from title
        if ! sed -i.tmp5 "s/# 🚀 Chief (Development Version)/# 🚀 Chief/g" "$file" 2>/dev/null; then
          success=false
        fi
        
        # 2. Remove warning box (multi-line pattern)
        if $success; then
          # Use perl for multi-line replacement to remove the warning block
          if ! perl -i -pe 'BEGIN{undef $/;} s/\n> ⚠️ \*\*Warning\*\*: This is the development branch.*?\[main branch\]\(.*?\)\.\n//smg' "$file" 2>/dev/null; then
            success=false
          fi
        fi
        
        # 3. Simplify installation section
        if $success; then
          # Replace development install section with simple install
          if ! sed -i.tmp6 's/## ⚡ Quick Install (Development Version)/## ⚡ Quick Install/g' "$file" 2>/dev/null; then
            success=false
          fi
          
          # Remove the dev install block and stable alternative, keep only main install
          if $success; then
            # Use perl to replace the complex install section
            perl -i -pe 'BEGIN{undef $/;} s/```bash\n# Install development version \(may be unstable\)\nbash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/dev\/tools\/install\.sh\)"\n```\n\n\*\*For stable release\*\*, use:\n```bash\n# Install stable version from main branch\nbash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/main\/tools\/install\.sh\)"\n```/```bash\nbash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/main\/tools\/install\.sh\)"\n```/smg' "$file" 2>/dev/null || success=false
          fi
        fi
        
      elif [[ "${positional_args[0]}" == "next-dev" ]]; then
        # NEXT-DEV: Add dev-specific content to README
        # 1. Add "(Development Version)" to title (accept "# Chief" or "# 🚀 Chief")
        if grep -q "^# Chief$" "$file" 2>/dev/null; then
          sed -i.tmp5 "s/^# Chief$/# Chief (Development Version)/g" "$file" 2>/dev/null || success=false
        elif grep -q "^# 🚀 Chief$" "$file" 2>/dev/null; then
          sed -i.tmp5 "s/# 🚀 Chief$/# 🚀 Chief (Development Version)/g" "$file" 2>/dev/null || success=false
        fi

        # 2. Add warning box after title (only if it doesn't exist)
        if $success; then
          if ! grep -q "Warning.*development branch" "$file" 2>/dev/null; then
            local warning_line="> ⚠️ **Warning**: This is the development branch. Features may be unstable. For stable releases, use the [main branch](https://github.com/randyoyarzabal/chief/tree/main)."
            if ! WARNING_LINE="$warning_line" perl -i.tmp6 -pe 'if (/^\*\*Bash Plugin Manager & Terminal Enhancement Tool\*\*$/) { $_ .= "\n\n" . $ENV{WARNING_LINE} . "\n" }' "$file" 2>/dev/null; then
              success=false
            fi
          fi
        fi

        # 3. Expand installation section (accept "## Quick Install" or "## ⚡ Quick Install")
        if $success; then
          if grep -q '^## ⚡ Quick Install$' "$file" 2>/dev/null; then
            sed -i.tmp7 's/## ⚡ Quick Install$/## ⚡ Quick Install (Development Version)/g' "$file" 2>/dev/null || success=false
          elif grep -q '^## Quick Install$' "$file" 2>/dev/null; then
            sed -i.tmp7 's/## Quick Install$/## Quick Install (Development Version)/g' "$file" 2>/dev/null || success=false
          fi
        fi

        # 4. Replace install block with dev-first version (optional; skip if already in dev format)
        if $success && grep -q "Install stable version" "$file" 2>/dev/null && grep -q "refs/heads/main/tools/install" "$file" 2>/dev/null; then
          if perl -i.tmp_install -pe 'BEGIN{undef $/;} s/(```bash\n)(# Install stable version\n)?(bash -c "\$\(curl -fsSL https:\/\/raw\.githubusercontent\.com\/randyoyarzabal\/chief\/refs\/heads\/main\/tools\/install\.sh\)"\n```)/$1# Install development version (may be unstable)\nbash -c "$(curl -fsSL https:\/\/raw.githubusercontent.com\/randyoyarzabal\/chief\/refs\/heads\/dev\/tools\/install.sh)"\n```\n\n**For stable release**, use:\n```bash\n# Install stable version from main branch\nbash -c "$(curl -fsSL https:\/\/raw.githubusercontent.com\/randyoyarzabal\/chief\/refs\/heads\/main\/tools\/install.sh)"\n```/smg' "$file" 2>/dev/null; then
            rm -f "${file}.tmp_install" 2>/dev/null
          else
            rm -f "${file}.tmp_install" 2>/dev/null
          fi
        fi
      fi
    fi
    
    if $success; then
      rm -f "${file}.tmp1" "${file}.tmp2" "${file}.tmp3" "${file}.tmp4" "${file}.tmp5" "${file}.tmp6" "${file}.tmp7" "${file}.tmp_dev" "${file}.tmp_stable" "${file}.tmp_install" 2>/dev/null
      if [[ "$(basename "$file")" == "README.md" ]]; then
        __chief_print_success "$(basename "$file"): Updated $current_version → $new_version (including badges and content structure)"
      else
        __chief_print_success "$(basename "$file"): Updated $current_version → $new_version (including badges)"
      fi
      ((updated_count++))
    else
      # Restore backup on failure if it exists
      if $create_backups; then
        local backup_file="${file}.backup.$(date +%s)"
        if [[ -f "$backup_file" ]]; then
          mv "$backup_file" "$file" 2>/dev/null
        fi
      fi
      rm -f "${file}.tmp1" "${file}.tmp2" "${file}.tmp3" "${file}.tmp4" "${file}.tmp5" "${file}.tmp6" "${file}.tmp7" "${file}.tmp_dev" "${file}.tmp_stable" "${file}.tmp_install" 2>/dev/null
      __chief_print_error "$(basename "$file"): Failed to update"
      return 1
    fi
  done
  
  
  # Summary
  echo ""
  if $dry_run; then
    __chief_print_info "Dry run completed. No files were modified."
    __chief_print_info "Run without --dry-run to apply changes."
  else
    __chief_print_success "Version bump completed: $current_version → $new_version"
    __chief_print_info "Files updated: $updated_count"
    
    # Clean up old backups (keep only the 3 most recent) - only if backups were created
    if $create_backups; then
      local backup_files
      backup_files=$(find "${CHIEF_PATH}" -name "*.backup.*" -type f 2>/dev/null | sort)
      if [[ -n "$backup_files" ]]; then
        local total_backups
        total_backups=$(echo "$backup_files" | wc -l | tr -d ' ')
        if [[ "$total_backups" -gt 3 ]]; then
          local files_to_delete=$((total_backups - 3))
          echo "$backup_files" | head -n "$files_to_delete" | xargs rm -f 2>/dev/null || true
          __chief_print_info "Cleaned up old backup files (kept 3 most recent)"
        fi
      fi
    fi
  fi
}

# INTERNAL HELPERS
########################################################################

function __chief_release_git() { git -C "$CHIEF_PATH" "$@"; }
function __chief_release_remote() { echo "${CHIEF_RELEASE_REMOTE:-origin}"; }

# owner/name of the GitHub repository, from the remote URL.
function __chief_release_repo() {
  if [[ -n "${CHIEF_RELEASE_REPO:-}" ]]; then
    echo "$CHIEF_RELEASE_REPO"
    return 0
  fi
  local url
  url="$(__chief_release_git remote get-url "$(__chief_release_remote)" 2>/dev/null)"
  url="${url%.git}"
  url="${url#*github.com[:/]}"
  if [[ "$url" == */* && "$url" != *:* ]]; then echo "$url"; else echo "randyoyarzabal/chief"; fi
}

# CHIEF_VERSION from a VERSION file read on stdin.
function __chief_release_parse_version() { grep -o 'CHIEF_VERSION="[^"]*"' | head -1 | cut -d'"' -f2; }
function __chief_release_version() { __chief_release_parse_version < "${CHIEF_PATH}/VERSION"; }
function __chief_release_version_at() { __chief_release_git show "$1:VERSION" 2>/dev/null | __chief_release_parse_version; }

# Returns 0 when version $1 is newer than $2 (vX.Y.Z).
function __chief_release_ver_gt() {
  local a="${1#v}" b="${2#v}" i x y
  local IFS=.
  local -a A=($a) B=($b)
  for i in 0 1 2; do
    x="${A[i]:-0}"; y="${B[i]:-0}"
    ((10#$x > 10#$y)) && return 0
    ((10#$x < 10#$y)) && return 1
  done
  return 1
}

# The usual next versions after a release: "version|kind" lines (patch, minor, major).
function __chief_release_candidates() {
  local ma mi pa
  IFS=. read -r ma mi pa <<< "${1#v}"
  echo "v${ma}.${mi}.$((${pa:-0} + 1))|patch"
  echo "v${ma}.$((mi + 1)).0|minor"
  echo "v$((ma + 1)).0.0|major"
}

function __chief_release_print_candidates() {
  local line
  while IFS= read -r line; do
    echo -e "  ${CHIEF_COLOR_GREEN}chief.release_publish --next ${line%%|*}${CHIEF_NO_COLOR}   (${line##*|})"
  done < <(__chief_release_candidates "$1")
}

# Refuse to run outside an active dev-tools checkout (dev branch + dev_tools on).
function __chief_release_ready() {
  local state
  state="$(__chief_dev_tools_state)"
  [[ "$state" == active ]] && return 0
  case "$state" in
    off)    __chief_print_error "Release tools are off. Turn them on with: chief.config-set dev_tools true" ;;
    branch) __chief_print_error "Release tools only run when ${CHIEF_PATH} is on the dev branch (it is on '$(__chief_release_git symbolic-ref --short -q HEAD 2>/dev/null || echo detached)')." ;;
    *)      __chief_print_error "Release tools are not available in this checkout." ;;
  esac
  return 1
}

# Step outcomes that depend on the run mode ($mode, $dry come from __chief_release_engine).
# A step that is already done: ✓ in status, ↷ when (re)running.
function __chief_release_already() {
  __chief_steps_start
  if [[ $mode == status ]]; then __chief_steps_done "$1"; else __chief_steps_skip "$1"; fi
}

# A step that still has to happen: pending in status, "would" in a dry run.
# Returns 0 only when the caller should do the work now.
function __chief_release_todo() {
  if [[ $mode == status ]]; then
    __chief_steps_start
    __chief_steps_set pending "$1"
    return 1
  fi
  if $dry; then
    __chief_steps_would "$1"
    return 1
  fi
  __chief_steps_start "$2"
  return 0
}

# Commit the files a version bump touches and push dev.
function __chief_release_commit_push() {
  local message="$1" remote="$2"
  __chief_release_git add -A VERSION README.md docs release-notes &&
    __chief_release_git commit --quiet -m "$message" &&
    __chief_release_git push --quiet "$remote" HEAD:dev
}

# How to change the version this dev cycle releases (e.g. v3.2.1 -> v3.3.0), as copy-paste
# commands. A hint instead of a command: it's rare, and these four lines are the whole job.
# The "--dev" pattern is the Dev Branch badge (shields.io writes "-" as "--"); Stable and
# Download badges show the last release and don't match. Exercised by tests/release-tests.sh.
function __chief_release_retarget_hint() {
  local rel="$1" example re
  example="$(__chief_release_candidates "$rel" | sed -n 2p)"
  example="${example%%|*}"
  re="${rel//./\\.}"
  echo
  echo "  Change the version this cycle releases (e.g. ${rel} → ${example}):"
  echo "    cd ${CHIEF_PATH}"
  echo "    git mv release-notes/${rel}-dev.md release-notes/${example}-dev.md"
  echo "    perl -pi -e 's/${re}--dev/${example}--dev/g; s/${re}-dev/${example}-dev/g' VERSION README.md docs/index.md release-notes/${example}-dev.md"
  echo "    git commit -am \"Retarget dev to ${example}-dev\" && git push $(__chief_release_remote) dev"
}

# THE RELEASE ENGINE
########################################################################
# One engine drives status, prepare and publish so they always agree on what is done.
# Where a release stands is read from git, never from memory, so any command can be
# re-run and continues where the last run stopped:
#   unprepared  VERSION is vX.Y.Z-dev (nothing done yet)
#   bumped      VERSION was bumped to vX.Y.Z but not committed yet
#   prepared    the "Release vX.Y.Z" commit is on dev
#   nextdev     dev's last commit is "Start vA.B.C-dev development (after vX.Y.Z)"
function __chief_release_engine() {
  local mode="$1" dry="$2" next="$3" track="$4"
  local remote repo
  remote="$(__chief_release_remote)"
  repo="$(__chief_release_repo)"

  local fetch_ok=true
  __chief_release_git fetch --quiet --tags "$remote" 2>/dev/null || fetch_ok=false

  local work_ver head_ver head_subject phase rel=""
  work_ver="$(__chief_release_version)"
  head_ver="$(__chief_release_version_at HEAD)"
  head_subject="$(__chief_release_git log -1 --format=%s 2>/dev/null)"
  local start_re='^Start (v[0-9]+\.[0-9]+\.[0-9]+)-dev development \(after (v[0-9]+\.[0-9]+\.[0-9]+)\)$'
  if [[ "$head_subject" =~ $start_re && "$work_ver" == "${BASH_REMATCH[1]}-dev" ]]; then
    phase=nextdev
    rel="${BASH_REMATCH[2]}"
    next="${BASH_REMATCH[1]}"
  elif [[ "$work_ver" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-dev$ ]]; then
    phase=unprepared
    rel="${work_ver%-dev}"
  elif [[ "$work_ver" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    rel="$work_ver"
    if [[ "$head_ver" == "$work_ver" ]]; then phase=prepared; else phase=bumped; fi
  else
    __chief_print_error "Unexpected version in ${CHIEF_PATH}/VERSION: '${work_ver}' (expected vX.Y.Z-dev or vX.Y.Z)."
    return 1
  fi

  # --next is required to publish (except to finish a cycle whose next version is already set).
  if [[ $mode == publish && $phase != nextdev ]]; then
    if [[ -z "$next" ]]; then
      __chief_print_error "--next is required. For ${rel}, the next version is usually one of:"
      __chief_release_print_candidates "$rel"
      return 1
    fi
    [[ "$next" =~ ^v[0-9]+\.[0-9]+$ ]] && next="${next}.0"
    if [[ ! "$next" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      __chief_print_error "--next must look like vX.Y.Z (got '${next}')."
      return 1
    fi
    if ! __chief_release_ver_gt "$next" "$rel"; then
      __chief_print_error "--next ${next} must be newer than the version being released (${rel})."
      __chief_release_print_candidates "$rel"
      return 1
    fi
  fi

  # State that later steps check (all read-only).
  local ahead behind main_ver tag_sha="" release_url="" pr_num="" pr_url="" merged=false
  ahead="$(__chief_release_git rev-list --count "${remote}/dev..HEAD" 2>/dev/null || echo 0)"
  behind="$(__chief_release_git rev-list --count "HEAD..${remote}/dev" 2>/dev/null || echo 0)"
  main_ver="$(__chief_release_version_at "${remote}/main")"
  tag_sha="$(__chief_release_git ls-remote --tags "$remote" "refs/tags/${rel}^{}" 2>/dev/null | cut -c1-7)"
  [[ -z "$tag_sha" ]] && tag_sha="$(__chief_release_git ls-remote --tags "$remote" "refs/tags/${rel}" 2>/dev/null | cut -c1-7)"
  [[ "$main_ver" == "$rel" || -n "$tag_sha" ]] && merged=true
  local gh_ok=false
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && gh_ok=true
  if [[ $mode != prepare ]] && $gh_ok; then
    release_url="$(gh release view "$rel" --repo "$repo" --json url --jq .url 2>/dev/null)"
    if ! $merged; then
      local pr_line
      pr_line="$(gh pr list --repo "$repo" --base main --head dev --state open --json number,url --jq '.[0] | "\(.number) \(.url)"' 2>/dev/null)"
      if [[ "$pr_line" =~ ^([0-9]+)\ (.+)$ ]]; then
        pr_num="${BASH_REMATCH[1]}"; pr_url="${BASH_REMATCH[2]}"
      fi
    fi
  fi

  # The step list.
  local next_label="${next:-vX.Y.Z}"
  local steps=("Checks" "Run the test suite" "Bump to ${rel}" "Commit \"Release ${rel}\" and push dev")
  if [[ $mode != prepare ]]; then
    steps+=("Open pull request dev → main" "Wait for CI" "Merge into main" "Tag ${rel}" "Create GitHub release"
            "Merge main back into dev" "Start ${next_label}-dev" "Commit and push dev")
    [[ -n "$track" ]] && steps+=("Track the ${track} branch for your own Chief updates")
  fi
  local title
  case $mode in
    publish) title="Releasing Chief ${rel} → next ${next_label}-dev" ;;
    prepare) title="Preparing Chief ${rel} on dev" ;;
    status)  title="Chief release status: ${rel}" ;;
  esac
  $dry && title+=" (dry run, nothing will change)"
  __chief_steps_begin "$title" "${steps[@]}"

  # 1. Checks
  __chief_steps_start
  local problems=() dirty
  $fetch_ok || problems+=("Could not fetch from ${remote}.")
  ((behind > 0)) && problems+=("dev is ${behind} commit(s) behind ${remote}/dev. Run: git pull")
  dirty="$(__chief_release_git status --porcelain 2>/dev/null)"
  if [[ $phase == bumped ]]; then
    local other
    other="$(echo "$dirty" | grep -vE '^.. (VERSION|README\.md|docs/|release-notes/)' | grep -v '^$')"
    [[ -n "$other" ]] && problems+=("Uncommitted changes outside the version bump. Commit or stash them first.")
  elif [[ -n "$dirty" ]]; then
    problems+=("Uncommitted changes in ${CHIEF_PATH}. Commit or stash them first.")
  fi
  case $phase in
    unprepared) [[ -f "${CHIEF_PATH}/release-notes/${rel}-dev.md" ]] || problems+=("Missing release notes: release-notes/${rel}-dev.md") ;;
    bumped|prepared) [[ -f "${CHIEF_PATH}/release-notes/${rel}.md" ]] || problems+=("Missing release notes: release-notes/${rel}.md") ;;
  esac
  if [[ $mode != prepare ]] && ! $gh_ok; then
    problems+=("GitHub CLI is not installed or not signed in. Run: gh auth login")
  fi
  if ((${#problems[@]} > 0)); then
    if [[ $mode == status ]] || $dry; then
      # Keep listing the remaining steps; show the problems under the list.
      __chief_steps_set fail "${#problems[@]} problem(s)"
      local p
      for p in "${problems[@]}"; do __chief_steps_note "    ${CHIEF_COLOR_RED}!${CHIEF_NO_COLOR} $p"; done
    else
      __chief_steps_fail "${#problems[@]} problem(s)" "${problems[@]}"
      return 1
    fi
  else
    local check_detail="on dev, clean, up to date"
    [[ $mode != prepare ]] && check_detail+=", gh signed in"
    __chief_steps_done "$check_detail"
  fi

  # 2-4. Prepare: tests, bump, commit and push
  case $phase in
    unprepared)
      if __chief_release_todo; then
        # CHIEF_RELEASE_TEST_CMD overrides the suite (used by tests/release-tests.sh).
        if ! __chief_steps_exec bash -c "${CHIEF_RELEASE_TEST_CMD:-bash \"${CHIEF_PATH}/tests/run-tests.sh\"}"; then
          __chief_steps_fail "tests failed" "Fix them on dev, then re-run."
          __chief_steps_show_log 20
          return 1
        fi
        __chief_steps_done "all suites passed"
      fi
      if __chief_release_todo; then
        if ! __chief_steps_exec __chief_release_bump release --skip-tests; then
          __chief_steps_fail "version bump failed"
          __chief_steps_show_log 20
          return 1
        fi
        __chief_steps_done "VERSION, release notes, badges"
      fi
      ;;
    *)
      __chief_release_already "done before"
      __chief_release_already "VERSION is ${rel}"
      ;;
  esac

  # 4. Commit and push the release on dev
  if [[ $phase == nextdev ]] || { [[ $phase == prepared ]] && ((ahead == 0)); }; then
    __chief_release_already "on ${remote}/dev"
  elif __chief_release_todo; then
    if [[ $phase == unprepared || $phase == bumped ]]; then
      local preview
      preview="$(__chief_release_git status --short | sed 's/^/      /')"
      if ! __chief_steps_ask "Commit \"Release ${rel}\" and push dev to ${remote}?" "    Changes:\n${preview}"; then
        __chief_steps_fail "stopped" "Nothing was committed. The bumped files are still in ${CHIEF_PATH}; re-run to continue."
        return 1
      fi
      if ! __chief_steps_exec __chief_release_commit_push "Release ${rel}" "$remote"; then
        __chief_steps_fail "commit or push failed"; __chief_steps_show_log; return 1
      fi
    else
      if ! __chief_steps_ask "Push dev to ${remote}?"; then
        __chief_steps_fail "stopped" "Re-run to continue."; return 1
      fi
      if ! __chief_steps_exec __chief_release_git push --quiet "$remote" HEAD:dev; then
        __chief_steps_fail "push failed"; __chief_steps_show_log; return 1
      fi
    fi
    __chief_steps_done "$(__chief_release_git rev-parse --short HEAD)"
  fi

  if [[ $mode == prepare ]]; then
    if $dry; then
      __chief_steps_end "Dry run complete. Nothing was changed."
    else
      __chief_steps_end "Prepared Chief ${rel} on dev" "Publish it with one of:"
      __chief_release_print_candidates "$rel"
    fi
    return 0
  fi

  # 5. Pull request
  if $merged; then
    __chief_release_already "merged"
  elif [[ -n "$pr_num" ]]; then
    __chief_release_already "#${pr_num} already open"
  elif __chief_release_todo; then
    if ! __chief_steps_exec gh pr create --repo "$repo" --base main --head dev --title "$rel" \
         --body "Release ${rel}. See release-notes/${rel}.md."; then
      __chief_steps_fail "could not open the pull request"; __chief_steps_show_log; return 1
    fi
    pr_url="$(grep -o 'https://[^ ]*/pull/[0-9]*' "$__CHIEF_STEPS_LOG" | tail -1)"
    pr_num="${pr_url##*/}"
    __chief_steps_done "${repo}#${pr_num}"
  fi

  # 6. CI
  if $merged; then
    __chief_release_already "merged"
  elif __chief_release_todo; then
    local interval="${CHIEF_RELEASE_CI_INTERVAL:-10}" timeout="${CHIEF_RELEASE_CI_TIMEOUT:-1800}"
    local waited=0 out rc total passed pending failed f
    while :; do
      out="$(gh pr checks "$pr_num" --repo "$repo" 2>&1)"; rc=$?
      total="$(echo "$out" | awk -F'\t' 'NF>1' | wc -l | tr -d ' ')"
      passed="$(echo "$out" | awk -F'\t' '$2=="pass"' | wc -l | tr -d ' ')"
      pending="$(echo "$out" | awk -F'\t' '$2=="pending"' | wc -l | tr -d ' ')"
      if ((rc == 0)); then
        __chief_steps_done "${passed} of ${total} checks passed"
        break
      elif [[ "$out" == *"no checks reported"* ]] && ((waited >= 30)); then
        __chief_steps_done "no checks reported"
        break
      elif ((rc == 8)) || [[ "$out" == *"no checks reported"* ]]; then
        if ((waited >= timeout)); then
          __chief_steps_fail "timed out after ${waited}s" "Re-run when CI finishes: chief.release_publish --next ${next}"
          return 1
        fi
        for ((f = 0; f < interval * 10; f++)); do
          __chief_steps_tick "${passed} of ${total} checks done, ${pending} pending"
          sleep 0.1
        done
        waited=$((waited + interval))
      else
        failed="$(echo "$out" | awk -F'\t' '$2=="fail" {print $1}' | paste -sd, - | sed 's/,/, /g')"
        __chief_steps_fail "failed: ${failed:-see gh pr checks ${pr_num}}" \
          "${pr_url:-https://github.com/${repo}/pull/${pr_num}}" \
          "Fix it on dev, then re-run: chief.release_publish --next ${next}"
        return 1
      fi
    done
  fi

  # 7. Merge
  if $merged; then
    __chief_release_already "main is on ${rel}"
  elif __chief_release_todo; then
    if ! __chief_steps_ask "Merge ${repo}#${pr_num} into main?"; then
      __chief_steps_fail "stopped" "Nothing was merged. Re-run to continue."; return 1
    fi
    if ! __chief_steps_exec gh pr merge "$pr_num" --repo "$repo" --merge; then
      __chief_steps_fail "merge failed"; __chief_steps_show_log; return 1
    fi
    __chief_release_git fetch --quiet --tags "$remote" 2>/dev/null
    main_ver="$(__chief_release_version_at "${remote}/main")"
    if [[ "$main_ver" != "$rel" ]]; then
      __chief_steps_fail "main is on '${main_ver}', expected ${rel}" "Check ${pr_url}, then re-run."; return 1
    fi
    merged=true
    __chief_steps_done "${repo}#${pr_num}"
  fi

  # 8. Tag
  local asked_publish=false
  if [[ -n "$tag_sha" ]]; then
    __chief_release_already "on ${tag_sha}"
  elif __chief_release_todo; then
    if ! __chief_steps_ask "Tag ${rel} on main and publish the GitHub release?"; then
      __chief_steps_fail "stopped" "Nothing was tagged. Re-run to continue."; return 1
    fi
    asked_publish=true
    if ! __chief_release_git rev-parse -q --verify "refs/tags/${rel}" >/dev/null; then
      __chief_release_git tag -a "$rel" -m "Chief ${rel}" "${remote}/main" || { __chief_steps_fail "could not create the tag"; return 1; }
    fi
    if ! __chief_steps_exec __chief_release_git push --quiet "$remote" "refs/tags/${rel}"; then
      __chief_steps_fail "could not push the tag"; __chief_steps_show_log; return 1
    fi
    tag_sha="$(__chief_release_git rev-parse --short "${rel}^{}")"
    __chief_steps_done "on ${tag_sha}"
  fi

  # 9. GitHub release
  if [[ -n "$release_url" ]]; then
    __chief_release_already "$release_url"
  elif __chief_release_todo; then
    if ! $asked_publish && ! __chief_steps_ask "Publish the GitHub release for ${rel}?"; then
      __chief_steps_fail "stopped" "Re-run to continue."; return 1
    fi
    local notes="${TMPDIR:-/tmp}/chief-release-notes.$$.md"
    __chief_release_git show "${remote}/main:release-notes/${rel}.md" > "$notes" 2>/dev/null
    if ! __chief_steps_exec gh release create "$rel" --repo "$repo" --verify-tag --title "Chief ${rel}" --notes-file "$notes"; then
      rm -f "$notes"; __chief_steps_fail "could not create the release"; __chief_steps_show_log; return 1
    fi
    rm -f "$notes"
    release_url="$(grep -o 'https://[^ ]*/releases/tag/[^ ]*' "$__CHIEF_STEPS_LOG" | tail -1)"
    __chief_steps_done "${release_url:-created}"
  fi

  # 10. Merge main back into dev
  if [[ -n "$tag_sha" ]] && __chief_release_git merge-base --is-ancestor "${remote}/main" HEAD 2>/dev/null; then
    __chief_release_already "dev has main"
  elif __chief_release_todo; then
    if ! __chief_steps_exec __chief_release_git merge --no-edit "${remote}/main"; then
      __chief_steps_fail "merge conflict" "Resolve it in ${CHIEF_PATH}, commit, then re-run: chief.release_publish --next ${next}"
      __chief_steps_show_log; return 1
    fi
    __chief_steps_done "$(__chief_release_git rev-parse --short HEAD)"
  fi

  # 11. Start the next dev version
  if [[ $phase == nextdev || "$(__chief_release_version)" == "${next}-dev" ]]; then
    __chief_release_already "VERSION is ${next}-dev"
  elif __chief_release_todo; then
    if ! __chief_steps_exec __chief_release_bump next-dev "$next" --skip-tests; then
      __chief_steps_fail "version bump failed"; __chief_steps_show_log 20; return 1
    fi
    __chief_steps_done "VERSION, release notes, badges"
  fi

  # 12. Commit and push the new dev cycle
  if [[ $phase == nextdev ]] && ((ahead == 0)); then
    __chief_release_already "on ${remote}/dev"
  elif __chief_release_todo; then
    if ! __chief_steps_ask "Commit \"Start ${next}-dev development\" and push dev to ${remote}?"; then
      __chief_steps_fail "stopped" "Re-run to continue: chief.release_publish --next ${next}"; return 1
    fi
    if [[ "$(__chief_release_git log -1 --format=%s)" =~ $start_re ]]; then
      __chief_steps_exec __chief_release_git push --quiet "$remote" HEAD:dev
    else
      __chief_steps_exec __chief_release_commit_push "Start ${next}-dev development (after ${rel})" "$remote"
    fi || { __chief_steps_fail "commit or push failed"; __chief_steps_show_log; return 1; }
    __chief_steps_done "$(__chief_release_git rev-parse --short HEAD)"
  fi

  # 13. Optional: which branch your own Chief follows
  if [[ -n "$track" ]]; then
    if [[ "${CHIEF_CFG_UPDATE_BRANCH:-}" == "$track" ]]; then
      __chief_release_already "already ${track}"
    elif __chief_release_todo; then
      chief.config-set --yes update_branch "$track" >/dev/null 2>&1 || { __chief_steps_fail "could not update your config"; return 1; }
      __chief_steps_done "CHIEF_CFG_UPDATE_BRANCH=${track}"
    fi
  fi

  # Summary
  if [[ $mode == status ]]; then
    local summary=("Version       $(__chief_release_version) on dev, ${ahead} unpushed commit(s)")
    summary+=("main          ${main_ver:-unknown}")
    summary+=("Last tag      $(__chief_release_git describe --tags --abbrev=0 "${remote}/main" 2>/dev/null || echo none)")
    [[ -n "$pr_url" ]] && summary+=("Pull request  ${pr_url}")
    if $gh_ok; then summary+=("GitHub CLI    signed in"); else summary+=("GitHub CLI    not signed in (gh auth login)"); fi
    if [[ $phase == nextdev ]] && ((ahead == 0)); then
      __chief_steps_end "Release ${rel} is complete; dev is on ${next}-dev." "${summary[@]}"
    else
      __chief_steps_end "Next" "${summary[@]}"
      echo
      echo "  To release ${rel}, run one of:"
      __chief_release_print_candidates "$rel"
      [[ $phase == unprepared ]] && __chief_release_retarget_hint "$rel"
    fi
  elif $dry; then
    __chief_steps_end "Dry run complete. Nothing was changed."
  else
    local cfg_line="unchanged (add --track main to follow releases)"
    [[ -n "$track" ]] && cfg_line="following ${track}"
    __chief_steps_end "Released Chief ${rel}" \
      "Pull request  ${pr_url:-merged}" \
      "Tag           ${rel} → ${tag_sha} on main" \
      "Release       ${release_url:-https://github.com/${repo}/releases/tag/${rel}}" \
      "dev now on    ${next}-dev ($(__chief_release_git rev-parse --short HEAD), pushed)" \
      "Your config   ${cfg_line}"
  fi
}

# Shared option parsing for the release commands.
function __chief_release_parse_opts() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --next)     next="${2:-}"; shift 2 || { __chief_print_error "--next needs a version"; return 1; } ;;
      --next=*)   next="${1#--next=}"; shift ;;
      --track)    track="${2:-}"; shift 2 || { __chief_print_error "--track needs main or dev"; return 1; } ;;
      --track=*)  track="${1#--track=}"; shift ;;
      --dry-run)  dry=true; shift ;;
      --yes|-y)   yes=true; shift ;;
      *)          __chief_print_error "Unknown option: $1"; return 1 ;;
    esac
  done
  if [[ -n "$track" && "$track" != main && "$track" != dev ]]; then
    __chief_print_error "--track must be main or dev"
    return 1
  fi
}

# COMMANDS
########################################################################

function chief.release_status() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
  Shows where the current release stands: which steps are done, which come next,
  and the command to run. Changes nothing.

${CHIEF_COLOR_BLUE}Maintainers only:${CHIEF_NO_COLOR} available when ${CHIEF_PATH} is on the dev branch
  and dev_tools is on (chief.config-set dev_tools true)."
  if [[ "$1" == "-?" || "$1" == "--help" ]]; then echo -e "$USAGE"; return 0; fi
  __chief_release_ready || return 1
  local mode=status dry=false
  __chief_release_engine status false "" ""
}

function chief.release_prepare() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [--dry-run] [--yes]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
  Optional. Stages the release on dev without publishing anything: checks, runs the
  test suite, bumps VERSION / release notes / badges to the release version, then
  commits \"Release vX.Y.Z\" and pushes dev (after you confirm).
  chief.release_publish does this too when it has not been done, so use this only
  when you want to review before going public. Re-running continues where it stopped.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --dry-run   Show every step and what it would do; change nothing
  --yes, -y   Don't ask before committing and pushing

${CHIEF_COLOR_BLUE}Maintainers only:${CHIEF_NO_COLOR} available when ${CHIEF_PATH} is on the dev branch
  and dev_tools is on (chief.config-set dev_tools true)."
  if [[ "$1" == "-?" || "$1" == "--help" ]]; then echo -e "$USAGE"; return 0; fi
  local next="" track="" dry=false yes=false
  __chief_release_parse_opts "$@" || { echo -e "$USAGE"; return 1; }
  __chief_release_ready || return 1
  local CHIEF_STEPS_ASSUME_YES=""
  $yes && CHIEF_STEPS_ASSUME_YES=1
  local mode=prepare
  __chief_release_engine prepare "$dry" "" ""
}

function chief.release_publish() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME --next vX.Y.Z [--track main|dev] [--dry-run] [--yes]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
  Releases the version on dev and starts the next development cycle, in one run:
    checks, tests, bump, commit and push dev (if chief.release_prepare has not done it),
    open the dev → main pull request, wait for CI, merge, tag, create the GitHub release,
    merge main back into dev, start vX.Y.Z-dev, commit and push dev.
  It asks before every push, merge and publish. If it stops for any reason, run the
  same command again: it skips what is already done and continues.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --next vX.Y.Z   Required. The next development version (must be newer than the release).
  --track BRANCH  Also switch your own Chief updates to main or dev (CHIEF_CFG_UPDATE_BRANCH).
                  Without it your config is not touched.
  --dry-run       Show every step and what it would do; change nothing
  --yes, -y       Don't ask before pushes, merges and publishing

${CHIEF_COLOR_BLUE}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME --next v3.2.1 --dry-run
  $FUNCNAME --next v3.3.0

${CHIEF_COLOR_BLUE}Maintainers only:${CHIEF_NO_COLOR} available when ${CHIEF_PATH} is on the dev branch
  and dev_tools is on (chief.config-set dev_tools true)."
  if [[ "$1" == "-?" || "$1" == "--help" ]]; then echo -e "$USAGE"; return 0; fi
  local next="" track="" dry=false yes=false
  __chief_release_parse_opts "$@" || { echo -e "$USAGE"; return 1; }
  __chief_release_ready || return 1
  local CHIEF_STEPS_ASSUME_YES=""
  $yes && CHIEF_STEPS_ASSUME_YES=1
  local mode=publish
  __chief_release_engine publish "$dry" "$next" "$track"
}
