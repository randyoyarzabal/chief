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

# Chief Plugin File: python_chief-plugin.sh
# Author: Randy E. Oyarzabal
# Functions and aliases related to Python.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

function chief.python_ve-dep() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Install all packages from requirements.txt in the current directory.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --ignore_version, -i    Install latest versions (ignore pinned versions)
  -?                      Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Upgrades pip, setuptools, and wheel first
- Handles both pinned and unpinned requirements
- Works in virtual environments and system Python

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- requirements.txt file in current directory
- Python and pip installed

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME           # Install exact versions from requirements.txt
  $FUNCNAME -i        # Install latest versions of all packages
"

  if [[ $1 == '-?' ]]; then
    echo -e "${USAGE}"
    return
  fi
  
  if [[ ! -f "requirements.txt" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} requirements.txt not found in current directory"
    return 1
  fi

  python -m pip install --upgrade pip setuptools wheel

  if [[ $1 == '--ignore_version' ]] || [[ $1 == '-i' ]]; then
    cat requirements.txt | cut -d'=' -f 1 | xargs pip install --upgrade
  else
    pip install -r requirements.txt
  fi
}

function chief.python_create-ve() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [venv_name] [python_version] [path]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Create a Python virtual environment using the venv module.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  venv_name       Name for the virtual environment (default: venv)
  python_version  Python version to use (default: python3)
  path           Absolute path where to create the environment

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Creates isolated Python environment
- Uses built-in venv module (Python 3.3+)
- Automatically upgrades pip in new environment
- Creates .gitignore entry for local virtual environments

${CHIEF_COLOR_MAGENTA}Default Behavior:${CHIEF_NO_COLOR}
- Home: Creates ~/.venv_name in user's home directory [DEFAULT]
- Custom: Provide any absolute path for custom location

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Create ~/.venv with python3
  $FUNCNAME myproject          # Create ~/.myproject in home directory
  $FUNCNAME myproject python3 ~/dev/myproject    # Create ~/dev/myproject
  $FUNCNAME myproject python3 ./myproject        # Create ./myproject in current dir
  $FUNCNAME venv python3.9 /opt/venvs/myapp      # Create in custom location

${CHIEF_COLOR_BLUE}Next Steps:${CHIEF_NO_COLOR}
After creation, start with: chief.python_start-ve [venv_name]
"

  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  # Parse arguments
  local venv_name=""
  local python_version="python3"
  local custom_path=""
  
  # Process arguments positionally
  if [[ $# -gt 0 && $1 != "-?" ]]; then
    venv_name="$1"
    shift
  fi
  
  if [[ $# -gt 0 && $1 =~ ^python ]]; then
    python_version="$1"
    shift
  fi
  
  if [[ $# -gt 0 ]]; then
    custom_path="$1"
    shift
  fi

  # Handle remaining arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-?)
        echo -e "${USAGE}"
        return
        ;;
      *)
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unknown argument: $1"
        return 1
        ;;
    esac
  done

  # Set defaults
  venv_name="${venv_name:-venv}"

  # Determine the full path for the virtual environment
  local venv_path=""
  local is_local=true
  
  if [[ -n "$custom_path" ]]; then
    # Custom path provided
    if [[ "$custom_path" =~ ^/ || "$custom_path" =~ ^~ ]]; then
      # Absolute path (expand ~ if present)
      venv_path="${custom_path/#\~/$HOME}"
      is_local=false
    elif [[ "$custom_path" =~ ^\./ ]]; then
      # Relative path starting with ./
      venv_path="$custom_path"
      is_local=true
    else
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Path must be absolute (/, ~) or relative (./): $custom_path"
      return 1
    fi
  else
    # Default: home directory with dot prefix
    if [[ "$venv_name" =~ ^[./] ]]; then
      venv_path="$venv_name"
      is_local=true
    else
      venv_path="$HOME/.${venv_name}"
      is_local=false
    fi
  fi

  # Check if Python is available
  if ! command -v "$python_version" &> /dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} $python_version not found in PATH"
    echo -e "${CHIEF_COLOR_YELLOW}Available Python versions:${CHIEF_NO_COLOR}"
    compgen -c python | sort | uniq
    return 1
  fi

  # Check if venv already exists
  if [[ -d "$venv_path" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Virtual environment '$venv_path' already exists"
    if ! chief.etc_ask-yes-or-no "Do you want to recreate it?"; then
      return 1
    fi
    echo -e "${CHIEF_COLOR_BLUE}Removing existing environment...${CHIEF_NO_COLOR}"
    rm -rf "$venv_path"
  fi

  echo -e "${CHIEF_COLOR_BLUE}Creating virtual environment '$venv_name' with $python_version...${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}Location:${CHIEF_NO_COLOR} $venv_path"
  
  # Create virtual environment
  if ! "$python_version" -m venv "$venv_path"; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to create virtual environment"
    return 1
  fi

  # Upgrade pip in the new environment
  echo -e "${CHIEF_COLOR_BLUE}Upgrading pip...${CHIEF_NO_COLOR}"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    "$venv_path/Scripts/python" -m pip install --upgrade pip --quiet
  else
    "$venv_path/bin/python" -m pip install --upgrade pip --quiet
  fi

  # Add to .gitignore only for local virtual environments
  if [[ "$is_local" == true ]]; then
    local gitignore_entry=$(basename "$venv_path")
    if [[ -f .gitignore ]]; then
      if ! grep -q "^${gitignore_entry}/$" .gitignore 2>/dev/null; then
        echo "${gitignore_entry}/" >> .gitignore
        echo -e "${CHIEF_COLOR_GREEN}Added '${gitignore_entry}/' to .gitignore${CHIEF_NO_COLOR}"
      fi
    else
      echo "${gitignore_entry}/" > .gitignore
      echo -e "${CHIEF_COLOR_GREEN}Created .gitignore with '${gitignore_entry}/' entry${CHIEF_NO_COLOR}"
    fi
  fi

  echo -e "${CHIEF_COLOR_GREEN}✓ Virtual environment '$venv_name' created successfully!${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}To start:${CHIEF_NO_COLOR} chief.python_start-ve $venv_name"
}

function chief.python_start-ve() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [venv_name]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Start a Python virtual environment and update your shell prompt.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  venv_name    Name/path of virtual environment to start (default: venv)

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Starts Python virtual environment
- Updates shell prompt to show active environment
- Sets up isolated Python and pip commands
- Works with environments created by venv, virtualenv, or conda

${CHIEF_COLOR_MAGENTA}Detection:${CHIEF_NO_COLOR}
Automatically detects virtual environment type and location:
- ./venv_name/ (local directory)
- ~/.venvs/venv_name/ (global venvs directory)
- Conda environments by name

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Start './venv'
  $FUNCNAME myproject          # Start './myproject' or '~/.venvs/myproject'
  $FUNCNAME /path/to/venv      # Start specific path
  $FUNCNAME                    # Auto-detect venv in current directory

${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR}
Use 'chief.python_stop-ve' or 'deactivate' to exit the virtual environment.
"

  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  # Check if already in a virtual environment
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Already in virtual environment:${CHIEF_NO_COLOR} $(basename "$VIRTUAL_ENV")"
    if ! chief.etc_ask-yes-or-no "Stop current environment and start new one?"; then
      return 1
    fi
    deactivate
  fi

  local venv_name="${1:-venv}"
  local venv_path=""

  # Try to find the virtual environment
  if [[ -d "$venv_name" ]]; then
    # Direct path or relative path
    venv_path="$venv_name"
  elif [[ -d "${HOME}/.${venv_name}" ]]; then
    # Home directory with dot prefix (default location)
    venv_path="${HOME}/.${venv_name}"
  elif [[ -d ".${venv_name}" ]]; then
    # Local dot-prefixed environment
    venv_path=".${venv_name}"
  elif [[ -d "${HOME}/.venv" && -z "$1" ]]; then
    # Default ~/.venv in home directory
    venv_path="${HOME}/.venv"
  elif [[ -d ".venv" && -z "$1" ]]; then
    # Fallback to .venv in current directory
    venv_path=".venv"
  elif [[ -d "venv" && -z "$1" ]]; then
    # Fallback to old-style venv in current directory
    venv_path="venv"
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Virtual environment '$venv_name' not found"
    echo -e "${CHIEF_COLOR_BLUE}Searched locations:${CHIEF_NO_COLOR}"
    echo "  - ./$venv_name"
    echo "  - ~/.${venv_name}"
    echo "  - ./.${venv_name}"
    [[ -z "$1" ]] && echo "  - ~/.venv (default)"
    [[ -z "$1" ]] && echo "  - ./.venv (fallback)"
    [[ -z "$1" ]] && echo "  - ./venv (fallback)"
    echo
    echo -e "${CHIEF_COLOR_YELLOW}Available environments:${CHIEF_NO_COLOR}"
    
    # List local venvs
    echo -e "${CHIEF_COLOR_BLUE}Local:${CHIEF_NO_COLOR} (in current directory)"
    local found_local=false
    # Check for dot-prefixed directories
    for dir in .*/ */; do
      if [[ -d "$dir" && "$dir" =~ ^\.(.*)/$ && "$dir" != "./" && "$dir" != "../" ]]; then
        if [[ -f "$dir/pyvenv.cfg" || -f "$dir/bin/activate" || -f "$dir/Scripts/activate" ]]; then
          echo "  - ${dir%/}"
          found_local=true
        fi
      elif [[ -d "$dir" && "$dir" =~ (venv|env)/ ]]; then
        if [[ -f "$dir/pyvenv.cfg" || -f "$dir/bin/activate" || -f "$dir/Scripts/activate" ]]; then
          echo "  - ${dir%/}"
          found_local=true
        fi
      fi
    done
    [[ "$found_local" == false ]] && echo "  - (none found)"
    
    # List home venvs
    echo -e "${CHIEF_COLOR_BLUE}Home:${CHIEF_NO_COLOR} (in ~/)"
    local found_home=false
    for dir in "$HOME"/.*; do
      if [[ -d "$dir" && -f "$dir/pyvenv.cfg" && ! "$dir" =~ /\.[.]/$ ]]; then
        echo "  - $(basename "$dir")"
        found_home=true
      fi
    done
    [[ "$found_home" == false ]] && echo "  - (none found)"
    
    return 1
  fi

  # Determine activation script path
  local activate_script=""
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    activate_script="$venv_path/Scripts/activate"
  else
    activate_script="$venv_path/bin/activate"
  fi

  # Check if activation script exists
  if [[ ! -f "$activate_script" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Activation script not found: $activate_script"
    echo -e "${CHIEF_COLOR_YELLOW}Is this a valid virtual environment?${CHIEF_NO_COLOR}"
    return 1
  fi

  # Start the virtual environment
  echo -e "${CHIEF_COLOR_BLUE}Starting virtual environment:${CHIEF_NO_COLOR} $(basename "$venv_path")"
  source "$activate_script"

  # Verify activation
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo -e "${CHIEF_COLOR_GREEN}✓ Virtual environment started!${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_BLUE}Python:${CHIEF_NO_COLOR} $(python --version)"
    echo -e "${CHIEF_COLOR_BLUE}Location:${CHIEF_NO_COLOR} $VIRTUAL_ENV"
    echo -e "${CHIEF_COLOR_YELLOW}To stop:${CHIEF_NO_COLOR} chief.python_stop-ve"
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to start virtual environment"
    return 1
  fi
}

function chief.python_stop-ve() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Stop the currently active Python virtual environment and restore the system Python.

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Stops current virtual environment
- Restores system Python and PATH
- Clears virtual environment prompt indicators
- Works with venv, virtualenv, and conda environments

${CHIEF_COLOR_BLUE}Behavior:${CHIEF_NO_COLOR}
- If no virtual environment is active, shows a friendly message
- Safely handles multiple stop calls
- Preserves your original shell environment

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Stop current virtual environment

${CHIEF_COLOR_MAGENTA}Alternative:${CHIEF_NO_COLOR}
You can also use the standard 'deactivate' command when in a virtual environment.
"

  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  # Check if in a virtual environment
  if [[ -z "$VIRTUAL_ENV" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}No virtual environment is currently active.${CHIEF_NO_COLOR}"
    return 0
  fi

  local current_env=$(basename "$VIRTUAL_ENV")
  echo -e "${CHIEF_COLOR_BLUE}Stopping virtual environment:${CHIEF_NO_COLOR} $current_env"

  # Stop the environment
  if command -v deactivate &> /dev/null; then
    deactivate
    echo -e "${CHIEF_COLOR_GREEN}✓ Virtual environment '$current_env' stopped${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_BLUE}Using system Python:${CHIEF_NO_COLOR} $(python3 --version 2>/dev/null || python --version 2>/dev/null || echo "Not found")"
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} deactivate function not found"
    echo -e "${CHIEF_COLOR_YELLOW}You may need to manually reset your environment${CHIEF_NO_COLOR}"
    return 1
  fi
}

