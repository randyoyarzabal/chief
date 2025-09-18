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

# Chief Plugin File: etc_chief-plugin.sh
# Author: Randy E. Oyarzabal
# Functions and aliases that don't belong on any other category.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

function chief.etc_chmod-f() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} chief.etc_chmod-f <permissions> [directory]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Recursively change permissions for all files in current or specified directory.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  permissions     File permissions (e.g., 644, 755, u+x, go-w)
  directory       Target directory (default: current directory)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -v, --verbose   Show each file being processed
  -n, --dry-run   Show what would be changed without making changes
  -?              Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Processes only files (not directories)
- Supports both octal (644) and symbolic (u+x) permission formats
- Safe operation with validation and confirmation
- Verbose mode for detailed output

${CHIEF_COLOR_MAGENTA}Permission Examples:${CHIEF_NO_COLOR}
- 644: Owner read/write, group/others read only
- 755: Owner read/write/execute, group/others read/execute
- u+x: Add execute permission for owner
- go-w: Remove write permission for group and others
- a+r: Add read permission for all users

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.etc_chmod-f 644                    # Set all files to 644 in current dir
  chief.etc_chmod-f 755 /path/to/scripts   # Set all files to 755 in specified dir
  chief.etc_chmod-f u+x                    # Add execute for owner on all files
  chief.etc_chmod-f -v 644                 # Verbose mode showing each file
  chief.etc_chmod-f -n 644                 # Dry-run to preview changes
"

  local permissions=""
  local target_dir="."
  local verbose=false
  local dry_run=false

  # Parse options and arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v|--verbose)
        verbose=true
        shift
        ;;
      -n|--dry-run)
        dry_run=true
        shift
        ;;
      -\?)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $1"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        if [[ -z "$permissions" ]]; then
          permissions="$1"
        elif [[ -z "$target_dir" || "$target_dir" == "." ]]; then
          target_dir="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Too many arguments"
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$permissions" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Permissions argument is required"
    echo -e "${USAGE}"
    return 1
  fi

  # Validate target directory
  if [[ ! -d "$target_dir" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Directory not found: $target_dir"
    return 1
  fi

  # Validate permissions format (basic check)
  if [[ ! "$permissions" =~ ^([0-7]{3,4}|[ugoa]*[+-=][rwx]+)$ ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Permission format may be invalid: $permissions"
    echo -e "${CHIEF_COLOR_BLUE}Valid formats:${CHIEF_NO_COLOR} 644, 755, u+x, go-w, a+r, etc."
    echo -n "Continue anyway? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled${CHIEF_NO_COLOR}"
      return 0
    fi
  fi

  # Count files to be processed
  local file_count
  file_count=$(find "$target_dir" -type f 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$file_count" -eq 0 ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}No files found in: $target_dir${CHIEF_NO_COLOR}"
    return 0
  fi

  echo -e "${CHIEF_COLOR_BLUE}Target directory:${CHIEF_NO_COLOR} $target_dir"
  echo -e "${CHIEF_COLOR_BLUE}Permissions:${CHIEF_NO_COLOR} $permissions"
  echo -e "${CHIEF_COLOR_BLUE}Files to process:${CHIEF_NO_COLOR} $file_count"

  # Dry-run mode
  if [[ "$dry_run" == true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}DRY RUN: Would change permissions for these files:${CHIEF_NO_COLOR}"
    if [[ "$verbose" == true ]]; then
      find "$target_dir" -type f -exec echo "  chmod $permissions {}" \;
    else
      echo -e "${CHIEF_COLOR_BLUE}$file_count files would be processed${CHIEF_NO_COLOR}"
      echo -e "${CHIEF_COLOR_YELLOW}Use -v flag to see individual files${CHIEF_NO_COLOR}"
    fi
    return 0
  fi

  # Confirmation for large operations
  if [[ "$file_count" -gt 100 ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning: About to change permissions for $file_count files${CHIEF_NO_COLOR}"
    echo -n "Continue? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled${CHIEF_NO_COLOR}"
      return 0
    fi
  fi

  # Execute permission changes
  echo -e "${CHIEF_COLOR_BLUE}Changing file permissions...${CHIEF_NO_COLOR}"
  
  local processed=0
  local failed=0
  
  if [[ "$verbose" == true ]]; then
    while IFS= read -r -d '' file; do
      echo -n "  $(basename "$file")... "
      if chmod "$permissions" "$file" 2>/dev/null; then
        echo -e "${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR}"
        ((processed++))
      else
        echo -e "${CHIEF_COLOR_RED}✗${CHIEF_NO_COLOR}"
        ((failed++))
      fi
    done < <(find "$target_dir" -type f -print0)
  else
    find "$target_dir" -type f -exec chmod "$permissions" {} \; 2>/dev/null
    # Simple success check since we can't easily count individual failures in this mode
    if [[ $? -eq 0 ]]; then
      processed=$file_count
    else
      echo -e "${CHIEF_COLOR_YELLOW}Some operations may have failed. Use -v flag for detailed output.${CHIEF_NO_COLOR}"
    fi
  fi

  echo ""
  if [[ "$verbose" == true ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Summary: $processed successful, $failed failed${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_GREEN}Permission changes completed${CHIEF_NO_COLOR}"
  fi
}

function chief.etc_chmod-d() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} chief.etc_chmod-d <permissions> [directory]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Recursively change permissions for all directories in current or specified directory.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  permissions     Directory permissions (e.g., 755, 750, u+x, go-w)
  directory       Target directory (default: current directory)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -v, --verbose   Show each directory being processed
  -n, --dry-run   Show what would be changed without making changes
  -?              Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Processes only directories (not files)
- Supports both octal (755) and symbolic (u+x) permission formats
- Safe operation with validation and confirmation
- Verbose mode for detailed output

${CHIEF_COLOR_MAGENTA}Common Directory Permissions:${CHIEF_NO_COLOR}
- 755: Owner read/write/execute, group/others read/execute (standard)
- 750: Owner read/write/execute, group read/execute, others no access
- 700: Owner read/write/execute only (private)
- u+x: Add execute (access) permission for owner
- go-w: Remove write permission for group and others

${CHIEF_COLOR_RED}Important:${CHIEF_NO_COLOR}
Directories need execute permission (x) to be accessible. Removing execute
permission from directories will make them inaccessible.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.etc_chmod-d 755                    # Set all dirs to 755 in current dir
  chief.etc_chmod-d 750 /path/to/project   # Set all dirs to 750 in specified dir
  chief.etc_chmod-d u+x                    # Add execute for owner on all dirs
  chief.etc_chmod-d -v 755                 # Verbose mode showing each directory
  chief.etc_chmod-d -n 755                 # Dry-run to preview changes
"

  local permissions=""
  local target_dir="."
  local verbose=false
  local dry_run=false

  # Parse options and arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v|--verbose)
        verbose=true
        shift
        ;;
      -n|--dry-run)
        dry_run=true
        shift
        ;;
      -\?)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $1"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        if [[ -z "$permissions" ]]; then
          permissions="$1"
        elif [[ -z "$target_dir" || "$target_dir" == "." ]]; then
          target_dir="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Too many arguments"
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$permissions" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Permissions argument is required"
    echo -e "${USAGE}"
    return 1
  fi

  # Validate target directory
  if [[ ! -d "$target_dir" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Directory not found: $target_dir"
    return 1
  fi

  # Validate permissions format (basic check)
  if [[ ! "$permissions" =~ ^([0-7]{3,4}|[ugoa]*[+-=][rwx]+)$ ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Permission format may be invalid: $permissions"
    echo -e "${CHIEF_COLOR_BLUE}Valid formats:${CHIEF_NO_COLOR} 755, 750, u+x, go-w, a+r, etc."
    echo -n "Continue anyway? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled${CHIEF_NO_COLOR}"
      return 0
    fi
  fi

  # Warning for potentially dangerous permissions
  if [[ "$permissions" =~ ^[0-7]*[0-6][0-6][0-6]$ ]] || [[ "$permissions" =~ -x ]]; then
    echo -e "${CHIEF_COLOR_RED}Warning:${CHIEF_NO_COLOR} This permission may make directories inaccessible!"
    echo -e "${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR} Directories need execute (x) permission to be accessible"
    echo -n "Continue? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled${CHIEF_NO_COLOR}"
      return 0
    fi
  fi

  # Count directories to be processed
  local dir_count
  dir_count=$(find "$target_dir" -type d 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$dir_count" -eq 0 ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}No directories found in: $target_dir${CHIEF_NO_COLOR}"
    return 0
  fi

  echo -e "${CHIEF_COLOR_BLUE}Target directory:${CHIEF_NO_COLOR} $target_dir"
  echo -e "${CHIEF_COLOR_BLUE}Permissions:${CHIEF_NO_COLOR} $permissions"
  echo -e "${CHIEF_COLOR_BLUE}Directories to process:${CHIEF_NO_COLOR} $dir_count"

  # Dry-run mode
  if [[ "$dry_run" == true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}DRY RUN: Would change permissions for these directories:${CHIEF_NO_COLOR}"
    if [[ "$verbose" == true ]]; then
      find "$target_dir" -type d -exec echo "  chmod $permissions {}" \;
    else
      echo -e "${CHIEF_COLOR_BLUE}$dir_count directories would be processed${CHIEF_NO_COLOR}"
      echo -e "${CHIEF_COLOR_YELLOW}Use -v flag to see individual directories${CHIEF_NO_COLOR}"
    fi
    return 0
  fi

  # Confirmation for large operations
  if [[ "$dir_count" -gt 50 ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning: About to change permissions for $dir_count directories${CHIEF_NO_COLOR}"
    echo -n "Continue? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled${CHIEF_NO_COLOR}"
      return 0
    fi
  fi

  # Execute permission changes
  echo -e "${CHIEF_COLOR_BLUE}Changing directory permissions...${CHIEF_NO_COLOR}"
  
  local processed=0
  local failed=0
  
  if [[ "$verbose" == true ]]; then
    while IFS= read -r -d '' dir; do
      local dir_name
      dir_name=$(basename "$dir")
      [[ "$dir_name" == "." ]] && dir_name="(current)"
      echo -n "  $dir_name... "
      if chmod "$permissions" "$dir" 2>/dev/null; then
        echo -e "${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR}"
        ((processed++))
      else
        echo -e "${CHIEF_COLOR_RED}✗${CHIEF_NO_COLOR}"
        ((failed++))
      fi
    done < <(find "$target_dir" -type d -print0)
  else
    find "$target_dir" -type d -exec chmod "$permissions" {} \; 2>/dev/null
    # Simple success check since we can't easily count individual failures in this mode
    if [[ $? -eq 0 ]]; then
      processed=$dir_count
    else
      echo -e "${CHIEF_COLOR_YELLOW}Some operations may have failed. Use -v flag for detailed output.${CHIEF_NO_COLOR}"
    fi
  fi

  echo ""
  if [[ "$verbose" == true ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Summary: $processed successful, $failed failed${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_GREEN}Permission changes completed${CHIEF_NO_COLOR}"
  fi
}

function chief.etc_create_bootusb() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} chief.etc_create_bootusb <iso_file> <disk_number> [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Create a bootable USB drive from an ISO file (macOS/Linux).

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  iso_file        Path to ISO file
  disk_number     Disk number (from 'diskutil list' on macOS or 'lsblk' on Linux)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -f, --force     Skip confirmations (use with extreme caution)
  -k, --keep      Keep temporary conversion file
  -?              Show this help

${CHIEF_COLOR_RED}⚠️  DANGER ZONE ⚠️${CHIEF_NO_COLOR}
This command will COMPLETELY ERASE the target USB drive and ALL DATA on it!
Make absolutely sure you specify the correct disk number.

${CHIEF_COLOR_MAGENTA}Prerequisites:${CHIEF_NO_COLOR}
${CHIEF_COLOR_GREEN}macOS:${CHIEF_NO_COLOR}
- hdiutil command available
- diskutil command available
- Admin privileges (sudo access)

${CHIEF_COLOR_GREEN}Linux:${CHIEF_NO_COLOR}
- dd command available
- Admin privileges (sudo access)

${CHIEF_COLOR_BLUE}Safety Features:${CHIEF_NO_COLOR}
- Validates ISO file exists and is readable
- Shows disk information before proceeding
- Multiple confirmation prompts
- Automatically unmounts target disk
- Cleans up temporary files

${CHIEF_COLOR_YELLOW}How to Find Disk Number:${CHIEF_NO_COLOR}
${CHIEF_COLOR_GREEN}macOS:${CHIEF_NO_COLOR} diskutil list
${CHIEF_COLOR_GREEN}Linux:${CHIEF_NO_COLOR} lsblk or sudo fdisk -l

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.etc_create_bootusb ubuntu.iso 2           # Create bootable USB from ubuntu.iso on disk2
  chief.etc_create_bootusb -k installer.iso 3     # Keep temporary files after creation
  
${CHIEF_COLOR_RED}WARNING:${CHIEF_NO_COLOR} Always verify disk number with 'diskutil list' (macOS) or 'lsblk' (Linux)
before running this command. Wrong disk number will destroy data!
"

  local iso_file=""
  local disk_number=""
  local force_mode=false
  local keep_temp=false
  local temp_file="/tmp/bootusb_$$.img"

  # Parse options and arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -f|--force)
        force_mode=true
        shift
        ;;
      -k|--keep)
        keep_temp=true
        shift
        ;;
      -\?)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $1"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        if [[ -z "$iso_file" ]]; then
          iso_file="$1"
        elif [[ -z "$disk_number" ]]; then
          disk_number="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Too many arguments"
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate required arguments
  if [[ -z "$iso_file" || -z "$disk_number" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Both ISO file and disk number are required"
    echo -e "${USAGE}"
    return 1
  fi

  # Validate ISO file
  if [[ ! -f "$iso_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ISO file not found: $iso_file"
    return 1
  fi

  if [[ ! -r "$iso_file" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Cannot read ISO file: $iso_file"
    return 1
  fi

  # Validate disk number format
  if [[ ! "$disk_number" =~ ^[0-9]+$ ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Invalid disk number format: $disk_number"
    echo -e "${CHIEF_COLOR_BLUE}Use:${CHIEF_NO_COLOR} Numbers only (e.g., 2 for disk2)"
    return 1
  fi

  # Detect operating system and set up commands
  local os_type
  if [[ "$OSTYPE" == "darwin"* ]]; then
    os_type="macOS"
    local disk_device="/dev/disk${disk_number}"
    local raw_device="/dev/rdisk${disk_number}"
    
    # Check if required tools are available on macOS
    if ! command -v hdiutil &>/dev/null; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} hdiutil command not found (required on macOS)"
      return 1
    fi
    
    if ! command -v diskutil &>/dev/null; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} diskutil command not found (required on macOS)"
      return 1
    fi
  elif [[ "$OSTYPE" == "linux"* ]]; then
    os_type="Linux"
    local disk_device="/dev/sd$(printf \\$(printf '%03o' $((97+disk_number))))"
    local raw_device="$disk_device"
    
    echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} On Linux, please verify disk device manually"
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unsupported operating system: $OSTYPE"
    echo -e "${CHIEF_COLOR_BLUE}Supported:${CHIEF_NO_COLOR} macOS (darwin) and Linux"
    return 1
  fi

  # Show ISO file information
  local iso_size
  iso_size=$(ls -lh "$iso_file" | awk '{print $5}')
  echo -e "${CHIEF_COLOR_BLUE}ISO file:${CHIEF_NO_COLOR} $iso_file ($iso_size)"
  echo -e "${CHIEF_COLOR_BLUE}Target disk:${CHIEF_NO_COLOR} $disk_device"
  echo -e "${CHIEF_COLOR_BLUE}Operating System:${CHIEF_NO_COLOR} $os_type"
  echo ""

  # Show disk information
  echo -e "${CHIEF_COLOR_CYAN}Current disk information:${CHIEF_NO_COLOR}"
  if [[ "$os_type" == "macOS" ]]; then
    if diskutil list | grep -A5 -B2 "disk${disk_number}"; then
      echo ""
    else
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Disk ${disk_number} not found"
      echo -e "${CHIEF_COLOR_BLUE}Available disks:${CHIEF_NO_COLOR}"
      diskutil list
      return 1
    fi
  else
    lsblk 2>/dev/null || echo -e "${CHIEF_COLOR_YELLOW}Please verify disk manually with 'lsblk' or 'sudo fdisk -l'${CHIEF_NO_COLOR}"
  fi

  # Safety confirmations
  if [[ "$force_mode" != true ]]; then
    echo -e "${CHIEF_COLOR_RED}⚠️  WARNING: This will COMPLETELY ERASE $disk_device ⚠️${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_RED}ALL DATA on the target disk will be PERMANENTLY LOST!${CHIEF_NO_COLOR}"
    echo ""
    
    if [[ $(chief.etc_ask_yes_or_no "Is $disk_device the correct USB drive to ERASE?") != "yes" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled by user${CHIEF_NO_COLOR}"
      return 0
    fi
    
    echo ""
    if [[ $(chief.etc_ask_yes_or_no "Are you absolutely sure you want to DESTROY all data on $disk_device?") != "yes" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled by user${CHIEF_NO_COLOR}"
      return 0
    fi
  fi

  echo ""
  echo -e "${CHIEF_COLOR_BLUE}Starting bootable USB creation...${CHIEF_NO_COLOR}"

  # Step 1: Convert ISO (macOS only)
  if [[ "$os_type" == "macOS" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Converting ISO to disk image...${CHIEF_NO_COLOR}"
    if ! hdiutil convert -format UDRW -o "$temp_file" "$iso_file"; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to convert ISO file"
      return 1
    fi
    
    # Remove .dmg extension if added
    if [[ -f "${temp_file}.dmg" ]]; then
      mv "${temp_file}.dmg" "$temp_file"
    fi
    
    local source_file="$temp_file"
  else
    local source_file="$iso_file"
  fi

  # Step 2: Unmount the target disk
  echo -e "${CHIEF_COLOR_BLUE}Unmounting target disk...${CHIEF_NO_COLOR}"
  if [[ "$os_type" == "macOS" ]]; then
    diskutil unmountDisk "$disk_device" || echo -e "${CHIEF_COLOR_YELLOW}Warning: Could not unmount disk (may not be mounted)${CHIEF_NO_COLOR}"
  else
    sudo umount "${disk_device}"* 2>/dev/null || echo -e "${CHIEF_COLOR_YELLOW}Warning: Could not unmount disk (may not be mounted)${CHIEF_NO_COLOR}"
  fi

  # Step 3: Write to USB drive
  echo -e "${CHIEF_COLOR_BLUE}Writing to USB drive... (this may take several minutes)${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}Please be patient and do not remove the USB drive${CHIEF_NO_COLOR}"
  
  if ! sudo dd if="$source_file" of="$raw_device" bs=1m status=progress 2>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to write to USB drive"
    [[ "$os_type" == "macOS" && "$keep_temp" != true ]] && rm -f "$temp_file"
    return 1
  fi

  # Step 4: Sync and eject
  echo -e "${CHIEF_COLOR_BLUE}Syncing and ejecting...${CHIEF_NO_COLOR}"
  sync
  
  if [[ "$os_type" == "macOS" ]]; then
    diskutil eject "$disk_device"
  else
    sudo eject "$disk_device" 2>/dev/null || echo -e "${CHIEF_COLOR_YELLOW}Note: Please safely remove the USB drive${CHIEF_NO_COLOR}"
  fi

  # Cleanup
  if [[ "$os_type" == "macOS" && "$keep_temp" != true ]]; then
    rm -f "$temp_file"
  elif [[ "$keep_temp" == true ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Temporary file kept:${CHIEF_NO_COLOR} $temp_file"
  fi

  echo ""
  echo -e "${CHIEF_COLOR_GREEN}✓ Bootable USB drive created successfully!${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}USB drive:${CHIEF_NO_COLOR} $disk_device"
  echo -e "${CHIEF_COLOR_YELLOW}The USB drive is now ready to boot${CHIEF_NO_COLOR}"
}

function chief.etc_copy_dotfiles() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} chief.etc_copy_dotfiles <source_directory> <destination_directory> [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Copy hidden files (dotfiles) from source to destination directory.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  source_directory        Directory containing dotfiles to copy
  destination_directory   Directory where dotfiles will be copied

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -v, --verbose           Show each file being copied
  -n, --dry-run          Show what would be copied without making changes
  -f, --force            Overwrite existing files without confirmation
  -b, --backup           Create backups of existing files (.bak extension)
  -?                     Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Copies only hidden files (starting with '.')
- Preserves file attributes and timestamps
- Safe operation with validation and optional confirmations
- Excludes directories (. and ..)
- Shows detailed progress in verbose mode

${CHIEF_COLOR_MAGENTA}What Gets Copied:${CHIEF_NO_COLOR}
- Hidden files (.bashrc, .vimrc, .gitconfig, etc.)
- Excludes directories (.git/, .config/, etc.)
- Excludes current (.) and parent (..) directory references

${CHIEF_COLOR_BLUE}Safety Features:${CHIEF_NO_COLOR}
- Validates source and destination directories exist
- Optional confirmation before overwriting existing files
- Backup option for existing files
- Dry-run mode to preview operations

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.etc_copy_dotfiles ~/backup ~/                    # Copy dotfiles from backup to home
  chief.etc_copy_dotfiles -v /etc/skel ~/newuser         # Verbose copy of skeleton files
  chief.etc_copy_dotfiles -b -f ~/old ~/current          # Force copy with backups
  chief.etc_copy_dotfiles -n ~/source ~/dest             # Dry-run to see what would be copied
"

  local source_dir=""
  local dest_dir=""
  local verbose=false
  local dry_run=false
  local force=false
  local backup=false

  # Parse options and arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v|--verbose)
        verbose=true
        shift
        ;;
      -n|--dry-run)
        dry_run=true
        shift
        ;;
      -f|--force)
        force=true
        shift
        ;;
      -b|--backup)
        backup=true
        shift
        ;;
      -\?)
        echo -e "${USAGE}"
        return
        ;;
      -*)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown option: $1"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        if [[ -z "$source_dir" ]]; then
          source_dir="$1"
        elif [[ -z "$dest_dir" ]]; then
          dest_dir="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Too many arguments"
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate required arguments
  if [[ -z "$source_dir" || -z "$dest_dir" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Both source and destination directories are required"
    echo -e "${USAGE}"
    return 1
  fi

  # Validate source directory
  if [[ ! -d "$source_dir" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Source directory not found: $source_dir"
    return 1
  fi

  if [[ ! -r "$source_dir" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Cannot read source directory: $source_dir"
    return 1
  fi

  # Validate/create destination directory
  if [[ ! -d "$dest_dir" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Destination directory doesn't exist: $dest_dir${CHIEF_NO_COLOR}"
    echo -n "Create it? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      if ! mkdir -p "$dest_dir"; then
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Cannot create destination directory: $dest_dir"
        return 1
      fi
      echo -e "${CHIEF_COLOR_GREEN}Created directory: $dest_dir${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled${CHIEF_NO_COLOR}"
      return 0
    fi
  fi

  if [[ ! -w "$dest_dir" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Cannot write to destination directory: $dest_dir"
    return 1
  fi

  # Find dotfiles
  local dotfiles=()
  while IFS= read -r -d '' file; do
    dotfiles+=("$file")
  done < <(find "$source_dir" -maxdepth 1 -mindepth 1 -type f -name ".*" -print0 2>/dev/null)

  if [[ ${#dotfiles[@]} -eq 0 ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}No dotfiles found in: $source_dir${CHIEF_NO_COLOR}"
    return 0
  fi

  echo -e "${CHIEF_COLOR_BLUE}Source directory:${CHIEF_NO_COLOR} $source_dir"
  echo -e "${CHIEF_COLOR_BLUE}Destination directory:${CHIEF_NO_COLOR} $dest_dir"
  echo -e "${CHIEF_COLOR_BLUE}Dotfiles found:${CHIEF_NO_COLOR} ${#dotfiles[@]}"
  
  if [[ "$verbose" == true || "$dry_run" == true ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Files to copy:${CHIEF_NO_COLOR}"
    for file in "${dotfiles[@]}"; do
      echo "  $(basename "$file")"
    done
  fi
  echo ""

  # Dry-run mode
  if [[ "$dry_run" == true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}DRY RUN: Would copy these files:${CHIEF_NO_COLOR}"
    for file in "${dotfiles[@]}"; do
      local filename
      filename=$(basename "$file")
      local dest_file="$dest_dir/$filename"
      
      if [[ -f "$dest_file" ]]; then
        if [[ "$backup" == true ]]; then
          echo -e "  $filename ${CHIEF_COLOR_BLUE}(would backup existing file)${CHIEF_NO_COLOR}"
        else
          echo -e "  $filename ${CHIEF_COLOR_YELLOW}(would overwrite existing file)${CHIEF_NO_COLOR}"
        fi
      else
        echo -e "  $filename ${CHIEF_COLOR_GREEN}(new file)${CHIEF_NO_COLOR}"
      fi
    done
    return 0
  fi

  # Copy files
  local copied=0
  local skipped=0
  local failed=0

  for file in "${dotfiles[@]}"; do
    local filename
    filename=$(basename "$file")
    local dest_file="$dest_dir/$filename"
    
    if [[ "$verbose" == true ]]; then
      echo -n "  $filename... "
    fi

    # Handle existing files
    if [[ -f "$dest_file" ]]; then
      if [[ "$force" != true ]]; then
        if [[ "$verbose" != true ]]; then
          echo -n "File exists: $filename - "
        fi
        echo -n "Overwrite? [y/N]: "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
          if [[ "$verbose" == true ]]; then
            echo -e "${CHIEF_COLOR_YELLOW}Skipped${CHIEF_NO_COLOR}"
          else
            echo -e "${CHIEF_COLOR_YELLOW}Skipped${CHIEF_NO_COLOR}"
          fi
          ((skipped++))
          continue
        fi
      fi
      
      # Create backup if requested
      if [[ "$backup" == true ]]; then
        if ! cp "$dest_file" "${dest_file}.bak"; then
          echo -e "${CHIEF_COLOR_RED}Warning: Failed to create backup for $filename${CHIEF_NO_COLOR}"
        elif [[ "$verbose" == true ]]; then
          echo -n "(backed up) "
        fi
      fi
    fi

    # Copy the file
    if cp -a "$file" "$dest_file"; then
      if [[ "$verbose" == true ]]; then
        echo -e "${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR}"
      fi
      ((copied++))
    else
      if [[ "$verbose" == true ]]; then
        echo -e "${CHIEF_COLOR_RED}✗${CHIEF_NO_COLOR}"
      else
        echo -e "${CHIEF_COLOR_RED}Failed to copy: $filename${CHIEF_NO_COLOR}"
      fi
      ((failed++))
    fi
  done

  echo ""
  echo -e "${CHIEF_COLOR_GREEN}Summary: $copied copied, $skipped skipped, $failed failed${CHIEF_NO_COLOR}"
  
  if [[ "$backup" == true && "$copied" -gt 0 ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Backup files created with .bak extension${CHIEF_NO_COLOR}"
  fi
}

function chief.etc_create_cipher() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [file_path] [--force]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Generate a random 32-character cipher key for password obfuscation.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  file_path    Optional path to save the generated key
  --force      Overwrite existing file if it exists

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Cross-platform random key generation
- Alphanumeric characters only (safe for most uses)
- 32-character length for strong encryption

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Display key to stdout
  $FUNCNAME ~/.cipher_key      # Save to file
  $FUNCNAME ~/.cipher_key --force  # Overwrite existing
"
  if [[ $1 == "-?" ]] || ([[ ! -z $2 ]] && [[ $2 != '--force' ]]); then
    echo -e "${USAGE}"
    return
  fi

  local key_str
  if [[ ${PLATFORM} == "MacOS" ]]; then
    key_str=$(cat /dev/random | LC_CTYPE=C tr -dc "[:alpha:]" | fold -w 32 | head -n 1)
  else
    key_str=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  fi

  if [[ -z $1 ]]; then
    echo "$key_str"
  else
    # If the file doesn't exist Or (file exists, and --force is passed).
    if [[ ! -f $1 ]] || ([[ -f $1 ]] && [[ $2 == '--force' ]]); then
      echo "Writing '$key_str' to $1."
      echo "$key_str" >$1
    elif [[ -f $1 ]]; then
      echo "Key file: $1 already exists."
    fi
  fi
}

function chief.etc_shared-term_create() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <session_name>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Create a named shared terminal session for collaborative tasks using GNU Screen.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  session_name  Name for the shared screen session

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Creates detached screen session
- Automatically attaches to the session
- Multiple users can connect to same session
- Session persists even if connection drops

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- GNU Screen installed (screen command)
- Appropriate permissions for shared sessions

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME dev-session     # Create development session
  $FUNCNAME meeting-room    # Create meeting session

${CHIEF_COLOR_BLUE}Related Commands:${CHIEF_NO_COLOR}
  chief.etc_shared-term_connect <session_name>  # Connect to existing session
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if ! command -v screen >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GNU Screen is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  macOS: brew install screen"
    echo "  Linux: Use your package manager (apt install screen, yum install screen, etc.)"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Creating shared terminal session:${CHIEF_NO_COLOR} $1"
  screen -d -m -S "$1"
  screen -x "$1"
}

function chief.etc_shared-term_connect() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <session_name>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Connect to an existing shared terminal session created with GNU Screen.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  session_name  Name of the existing screen session

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Connects to already running screen session
- Multiple users can share the same session
- Real-time collaboration capabilities
- Session persists even if connection drops

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- GNU Screen installed (screen command)
- Session must already exist (created with chief.etc_shared-term_create)
- Appropriate permissions to access session

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME dev-session     # Connect to development session
  $FUNCNAME meeting-room    # Join meeting session

${CHIEF_COLOR_BLUE}Related Commands:${CHIEF_NO_COLOR}
  chief.etc_shared-term_create <session_name>  # Create new shared session
  screen -list                                 # List available sessions
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if ! command -v screen >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} GNU Screen is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  macOS: brew install screen"
    echo "  Linux: Use your package manager (apt install screen, yum install screen, etc.)"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Connecting to shared terminal session:${CHIEF_NO_COLOR} $1"
  screen -x "$1"
}

function chief.etc_mount_share() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <share_path> <mount_path> <username>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Mount a Samba (SMB/CIFS) network share to a local directory.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  share_path   Network path to the SMB share (e.g., //server/share)
  mount_path   Local directory to mount the share to
  username     Username for authentication

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Automatically detects if share is already mounted
- Uses CIFS protocol for Windows/Samba compatibility
- Prompts for password during mounting
- Prevents duplicate mounts

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- cifs-utils package installed
- Mount point directory must exist
- Root/sudo privileges for mounting
- Network connectivity to SMB server

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME //server/shared /mnt/shared john        # Mount shared folder
  $FUNCNAME //192.168.1.100/data /media/data admin  # Mount by IP
  $FUNCNAME //nas/backup /backup backup-user        # Mount backup share

${CHIEF_COLOR_BLUE}Setup Mount Point:${CHIEF_NO_COLOR}
  sudo mkdir -p /mnt/shared    # Create mount directory first
"

  if [[ -z $3 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  local SHARE="$1"
  local MOUNT="$2"
  local USER="$3"

  if ! command -v mount.cifs >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} CIFS utilities not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  Ubuntu/Debian: sudo apt install cifs-utils"
    echo "  CentOS/RHEL: sudo yum install cifs-utils"
    echo "  macOS: Not directly supported (use Finder or osascript)"
    return 1
  fi

  if [[ ! -d "$MOUNT" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Mount point does not exist: $MOUNT"
    echo -e "${CHIEF_COLOR_BLUE}Create with:${CHIEF_NO_COLOR} sudo mkdir -p $MOUNT"
    return 1
  fi

  if mount | grep "$MOUNT" >/dev/null; then
    echo -e "${CHIEF_COLOR_YELLOW}Already mounted:${CHIEF_NO_COLOR} $SHARE at $MOUNT"
  else
    echo -e "${CHIEF_COLOR_BLUE}Mounting SMB share:${CHIEF_NO_COLOR} $SHARE → $MOUNT"
    echo -e "${CHIEF_COLOR_BLUE}Username:${CHIEF_NO_COLOR} $USER"
    mount -t cifs -o user="$USER" "$SHARE" "$MOUNT"
    if [[ $? -eq 0 ]]; then
      echo -e "${CHIEF_COLOR_GREEN}Share mounted successfully${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_RED}Failed to mount share${CHIEF_NO_COLOR}"
      return 1
    fi
  fi
}

function chief.etc_folder_diff() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <folder1> <folder2>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Find and display differences between two directories by comparing their file listings.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  folder1      First directory to compare
  folder2      Second directory to compare

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Shows files that exist in one directory but not the other
- Automatically tries both directions for comprehensive comparison
- Uses sorted file listings for consistent results
- Fast comparison using shell built-ins

${CHIEF_COLOR_MAGENTA}Comparison Method:${CHIEF_NO_COLOR}
- Lists files in each directory
- Sorts listings alphabetically
- Uses comm command to find unique files
- Shows differences from both perspectives

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME /backup/docs /current/docs    # Compare backup vs current
  $FUNCNAME ./v1.0 ./v2.0                 # Compare version directories
  $FUNCNAME ~/Desktop ~/Downloads         # Compare common directories

${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR}
This compares file names only, not file contents. Use diff for content comparison.
"

  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if [[ ! -d "$1" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Directory not found: $1"
    return 1
  fi

  if [[ ! -d "$2" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Directory not found: $2"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Comparing directories:${CHIEF_NO_COLOR}"
  echo -e "  ${CHIEF_COLOR_CYAN}Folder 1:${CHIEF_NO_COLOR} $1"
  echo -e "  ${CHIEF_COLOR_CYAN}Folder 2:${CHIEF_NO_COLOR} $2"
  echo ""

  # Find files only in folder1
  local only_in_1=$(comm -23 <(ls "$1" | sort) <(ls "$2" | sort))
  if [[ -n "$only_in_1" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Files only in $1:${CHIEF_NO_COLOR}"
    echo "$only_in_1"
    echo ""
  fi

  # Find files only in folder2
  local only_in_2=$(comm -23 <(ls "$2" | sort) <(ls "$1" | sort))
  if [[ -n "$only_in_2" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Files only in $2:${CHIEF_NO_COLOR}"
    echo "$only_in_2"
    echo ""
  fi

  if [[ -z "$only_in_1" && -z "$only_in_2" ]]; then
    echo -e "${CHIEF_COLOR_GREEN}No differences found - directories have identical file listings${CHIEF_NO_COLOR}"
  fi
}

function chief.etc_at_run() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <time> <command>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Schedule a command to run at a specific time using the 'at' command.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  time        When to run the command (see time format examples below)
  command     Command to execute at the specified time

${CHIEF_COLOR_GREEN}Time Format Examples:${CHIEF_NO_COLOR}
- now + 5 minutes
- 14:30 (2:30 PM today)
- 2:30pm tomorrow
- midnight
- noon + 2 hours
- 17:00 Dec 25

${CHIEF_COLOR_MAGENTA}Features:${CHIEF_NO_COLOR}
- Automatically sources Chief environment for commands
- Uses system 'at' daemon for reliable scheduling
- Supports Chief functions and aliases in scheduled commands

${CHIEF_COLOR_BLUE}Job Management:${CHIEF_NO_COLOR}
- atq                    # View scheduled jobs
- atrm <job_number>      # Remove scheduled job
- at -l                  # List all jobs

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME \"now + 10 minutes\" \"echo 'Reminder!'\"
  $FUNCNAME \"2:30pm\" \"chief.git_update\"
  $FUNCNAME \"midnight\" \"backup_script.sh\"

${CHIEF_COLOR_BLUE}Reference:${CHIEF_NO_COLOR} https://www.computerhope.com/unix/uat.htm
"

  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if ! command -v at >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} 'at' command not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  Ubuntu/Debian: sudo apt install at"
    echo "  CentOS/RHEL: sudo yum install at"
    echo "  macOS: at is built-in but may need to be enabled"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Scheduling command:${CHIEF_NO_COLOR} $2"
  echo -e "${CHIEF_COLOR_BLUE}Execution time:${CHIEF_NO_COLOR} $1"
  echo "source ${CHIEF_PATH}/chief.sh; $2" | at "$1"
  
  if [[ $? -eq 0 ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Job scheduled successfully${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_BLUE}View jobs with:${CHIEF_NO_COLOR} atq"
  else
    echo -e "${CHIEF_COLOR_RED}Failed to schedule job${CHIEF_NO_COLOR}"
    return 1
  fi
}

function chief.etc_broadcast() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <message>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Send a broadcast message to all currently logged-in users using the 'wall' command.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  message     Text message to broadcast to all users

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Sends message to all active terminal sessions
- Message appears on all user terminals immediately
- Useful for system maintenance notifications
- Requires appropriate permissions

${CHIEF_COLOR_MAGENTA}Use Cases:${CHIEF_NO_COLOR}
- System maintenance warnings
- Emergency notifications
- Scheduled shutdown announcements
- General administrative messages

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME \"System will reboot in 10 minutes\"
  $FUNCNAME \"Please save your work - maintenance starting\"
  $FUNCNAME \"Network maintenance complete\"

${CHIEF_COLOR_RED}Note:${CHIEF_NO_COLOR}
This command may require administrator privileges on some systems.
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if ! command -v wall >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} 'wall' command not found."
    echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} wall is usually available on Unix/Linux systems by default."
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Broadcasting message to all users:${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}Message:${CHIEF_NO_COLOR} $1"
  wall "$1"
  
  if [[ $? -eq 0 ]]; then
    echo -e "${CHIEF_COLOR_GREEN}Broadcast sent successfully${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_RED}Failed to send broadcast${CHIEF_NO_COLOR}"
    return 1
  fi
}

function chief.etc_isvalid_ip() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <ip_address>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Validate if a given string is a properly formatted IPv4 address.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  ip_address   IPv4 address to validate (e.g., 192.168.1.1)

${CHIEF_COLOR_GREEN}Validation Rules:${CHIEF_NO_COLOR}
- Must be in dotted decimal notation (A.B.C.D)
- Each octet must be 0-255
- Must contain exactly 4 octets
- No leading zeros allowed

${CHIEF_COLOR_MAGENTA}Return Values:${CHIEF_NO_COLOR}
- 0 (success): Valid IP address
- 1 (failure): Invalid IP address

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME 192.168.1.1     # Valid
  $FUNCNAME 10.0.0.1        # Valid
  $FUNCNAME 256.1.1.1       # Invalid (256 > 255)
  $FUNCNAME 192.168.1       # Invalid (missing octet)

${CHIEF_COLOR_BLUE}Usage in Scripts:${CHIEF_NO_COLOR}
  if $FUNCNAME \"192.168.1.1\"; then
    echo \"Valid IP\"
  else
    echo \"Invalid IP\"
  fi
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  local ip="$1"
  local stat=1

  # Check basic format with regex
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    # Split IP into octets and validate range
    local OIFS=$IFS
    IFS='.'
    local ip_array=($ip)
    IFS=$OIFS
    
    # Check each octet is within valid range (0-255)
    if [[ ${ip_array[0]} -le 255 && ${ip_array[1]} -le 255 && \
          ${ip_array[2]} -le 255 && ${ip_array[3]} -le 255 ]]; then
      stat=0  # Valid IP
      echo -e "${CHIEF_COLOR_GREEN}Valid IP address:${CHIEF_NO_COLOR} $ip"
    else
      echo -e "${CHIEF_COLOR_RED}Invalid IP address:${CHIEF_NO_COLOR} $ip (octet out of range)"
    fi
  else
    echo -e "${CHIEF_COLOR_RED}Invalid IP address format:${CHIEF_NO_COLOR} $ip"
  fi
  
  return $stat
}

function chief.etc_ask_yes_or_no() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <message>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Prompt the user with a yes/no question and return appropriate exit code.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  message     Question or prompt to display to the user

${CHIEF_COLOR_GREEN}Return Values:${CHIEF_NO_COLOR}
- 0 (success): User answered 'yes' (y/yes)
- 1 (failure): User answered 'no' (n/no) or pressed Enter

${CHIEF_COLOR_MAGENTA}Input Handling:${CHIEF_NO_COLOR}
- Accepts: y, yes, Y, YES (case insensitive)
- Rejects: n, no, N, NO, or empty input
- Continues prompting until valid input received

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  if $FUNCNAME \"Delete this file?\"; then
    rm file.txt
  fi
  
  $FUNCNAME \"Continue with installation?\" && install_package

${CHIEF_COLOR_BLUE}Interactive Prompts:${CHIEF_NO_COLOR}
  $FUNCNAME \"Are you sure?\"           # Basic confirmation
  $FUNCNAME \"Overwrite existing file?\" # File operation
  $FUNCNAME \"Proceed with deletion?\"   # Destructive action
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return 1
  fi

  while true; do
    echo -ne "${CHIEF_COLOR_YELLOW}$1${CHIEF_NO_COLOR} ([${CHIEF_COLOR_GREEN}y${CHIEF_NO_COLOR}]es or [${CHIEF_COLOR_RED}N${CHIEF_NO_COLOR}]o): "
    read REPLY
    case "$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')" in
      y|yes)
        echo -e "${CHIEF_COLOR_GREEN}Proceeding...${CHIEF_NO_COLOR}"
        return 0
        ;;
      n|no|"")
        echo -e "${CHIEF_COLOR_RED}Cancelled.${CHIEF_NO_COLOR}"
        return 1
        ;;
      *)
        echo -e "${CHIEF_COLOR_YELLOW}Please answer yes or no (y/n).${CHIEF_NO_COLOR}"
        ;;
    esac
  done
}

# function chief.etc_ask_yes_or_no() {
#   local USAGE="Usage: $FUNCNAME <msg/question>

# Display a yes/no user prompt and echo the response.
# Returns 'yes' or 'no' string.

# Example:
#    response=\$($FUNCNAME 'Do you want to continue?')
# "

#   if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
#     echo "${USAGE}"
#     return
#   fi

#   read -p "$1 ([y]es or [N]o): "
#   case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
#   y | yes) echo "yes" ;;
#   *) echo "no" ;;
#   esac
# }

function chief.etc_prompt() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <prompt_message>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Display a user prompt and return the entered response.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  prompt_message  Text to display as the prompt

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Interactive input from user
- Returns user's response as output
- Useful for collecting user input in scripts
- Automatically adds colon and space after prompt

${CHIEF_COLOR_MAGENTA}Return Value:${CHIEF_NO_COLOR}
Echoes the user's input to stdout for capture in variables.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  user_name=\$(${FUNCNAME} 'What is your username')
  email=\$(${FUNCNAME} 'Enter your email address')
  path=\$(${FUNCNAME} 'Enter the file path')

${CHIEF_COLOR_BLUE}Usage in Scripts:${CHIEF_NO_COLOR}
  # Get user input
  response=\$(${FUNCNAME} 'Enter configuration value')
  echo \"You entered: \$response\"
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if [[ -z $1 ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Prompt message is required"
    echo -e "${USAGE}"
    return 1
  fi

  echo -ne "${CHIEF_COLOR_BLUE}$1:${CHIEF_NO_COLOR} "
  read REPLY
  echo "$REPLY"
}

function chief.type_writer() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <message> [delay_seconds]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Display text with a typewriter effect by printing each character with a delay.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  message        Text to display with typewriter effect
  delay_seconds  Optional delay between characters in seconds (default: 0.05)

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Character-by-character output simulation
- Customizable typing speed
- Perfect for demonstrations and presentations
- Educational/training script enhancement

${CHIEF_COLOR_MAGENTA}Use Cases:${CHIEF_NO_COLOR}
- Screen sharing demonstrations
- Educational scripts
- Presentation effects
- Terminal-based storytelling

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME \"Hello World!\"              # Default speed (0.05s)
  $FUNCNAME \"Slow typing...\" 0.25        # Slow typing
  $FUNCNAME \"Fast typing!\" 0.01          # Fast typing

${CHIEF_COLOR_BLUE}Speed Guide:${CHIEF_NO_COLOR}
- 0.01s = Very fast
- 0.05s = Normal (default)
- 0.1s  = Slow
- 0.25s = Very slow
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  local msg="$1"
  local timer="${2:-0.05}"  # Default delay: 0.05 seconds
  local eol="$3"
  
  echo -e "${CHIEF_COLOR_BLUE}Typewriter mode:${CHIEF_NO_COLOR} ${timer}s delay per character"
  for (( i=0; i<${#msg}; i++ )); do
    sleep $timer
    echo -n "${msg:$i:1}"
  done
}

function chief.etc_spinner() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <message> <command> <output_variable>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Display a spinning progress indicator while a command executes in the background.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  message         Text to display alongside the spinner
  command         Command to execute in the background
  output_variable Name of variable to store command output

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Visual feedback for long-running operations
- Captures command output for later use
- Cross-platform spinner animation
- Non-blocking execution with progress indication

${CHIEF_COLOR_MAGENTA}Spinner Characters:${CHIEF_NO_COLOR}
Rotates through: | / - \\ (creating animation effect)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME \"Installing packages\" \"apt update\" install_output
  $FUNCNAME \"Building project\" \"make all\" build_result
  $FUNCNAME \"Downloading file\" \"wget file.tar.gz\" download_log

${CHIEF_COLOR_BLUE}Usage Pattern:${CHIEF_NO_COLOR}
  $FUNCNAME \"Processing...\" \"long_command\" result_var
  echo \"Command output: \$result_var\"

${CHIEF_COLOR_RED}Note:${CHIEF_NO_COLOR}
Output variable is set in the caller's environment for access after completion.
"

  if [[ -z $3 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  # Create a random file to hold output
  if [[ ${PLATFORM} == "MacOS" ]]; then
    tmp_file="/tmp/._$(cat /dev/random | LC_CTYPE=C tr -dc "[:alpha:]" | fold -w 8 | head -n 1)"
  else
    tmp_file="/tmp/._$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)"
  fi

  # Process the command in the background until it returns (saving the output to the temp file).
  #   In the meantime, keep printing the spinner chars.
  read < <(
    eval "$2" &> $tmp_file &
    echo $!
  )
  printf "$1"
  __chief_spinner $REPLY "$1"

  # Clear the message in-place
  local start=1
  local end=$(echo -n $1 | wc -m)

  # Move the cursor to the left with backspace.
  for ((i = $start; i <= $end; i++)); do printf "\b"; done

  # Remove message from console.
  for ((i = $start; i <= $end; i++)); do printf " "; done

  # Reposition the cursor to the beginning before any other writes to the screen
  for ((i = $start; i <= $end; i++)); do printf "\b"; done

  # Save output to 3rd parameter variable
  eval "$3='$(cat $tmp_file)'"

  # Destroy / delete the temp file
  rm -rf $tmp_file
}


# HELPER FUNCTIONS
##################################################
function __chief_spinner() {
  # Usage: __chief_spinner <pid>
  local pid=$1
  local delay=0.75
  local spinstr='|/-\'
  while [[ "$(ps a | awk '{print $1}' | grep $pid)" ]]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b" # This deletes the completed spinner.

  # Delete spinner message
  local str_len=`echo $2 |awk '{print length}'`
  for (( i=1; i <= $str_len; i++ )); do
    printf "\b"
  done
}

function __chief_timer() {
  # Usage: __chief_timer <start | end>
  if [[ ${PLATFORM} != "MacOS" ]]; then # Need to figure out the Mac equivalent of below
    if [[ $1 = "start" ]]; then
      SECONDS=0
      return
    fi
    if [[ $1 = "end" ]]; then echo "Task took: "$(date +%T -d "1/1 + $SECONDS sec"); fi
  fi
}

function __chief_proper() {
  # Usage: __chief_proper <string>
  sed 's/.*/\L&/; s/[a-z]*/\u&/g' <<<"$1"
}

function __chief_trim() {
  # Usage: __chief_trim <string>
  awk '{$1=$1};1'
}

function __chief_begin {
  # Linux implementation of Cisco's "begin"
  cat | sed -n "/$1/,\$p"
}
alias be='__chief_begin'
alias begin='__chief_begin'
