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

# Chief Plugin File: etc_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0.1
# Functions and aliases that don't belong on any other category.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

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
