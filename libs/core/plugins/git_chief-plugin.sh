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

# Chief Plugin File: git_chief-plugin.sh
# Author: Randy E. Oyarzabal
# Functions and aliases that are development to Git.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

alias chief.git_url='git config --get remote.origin.url'

function chief.git_clone() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <repo_url>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Clone a Git repository with automatic submodule initialization and updates.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  repo_url     Git repository URL to clone

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Automatically clones with --recurse-submodules
- Updates submodules to latest remote commits
- Single command replaces multiple git operations

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME https://github.com/user/repo.git
  $FUNCNAME git@github.com:user/repo.git
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if [[ -z "$1" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Repository URL is required"
    echo -e "${USAGE}"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Cloning repository with submodules...${CHIEF_NO_COLOR}"
  git clone --recurse-submodules --remote-submodules "$1"
}

function chief.git_update() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Perform a full Git repository update including pull, push, and tag synchronization.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -p           Pull-only mode (skip push and tag operations)
  -?           Show this help

${CHIEF_COLOR_GREEN}Default Operations:${CHIEF_NO_COLOR}
1. Fetch latest changes from remote
2. Pull changes into current branch
3. Push local commits to remote
4. Fetch and update tags

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME        # Full update (pull + push + tags)
  $FUNCNAME -p     # Pull-only update
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  git config --get remote.origin.url
  git pull
  if [[ $1 != "-p" ]]; then
    git push
    git fetch origin --tags --force # Get any new tags from origin
    git pull --prune --tags  # Get any renamed tags
  fi
}

function chief.git_commit() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [commit_message]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Stage all changes, commit with message, and push to remote repository.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  commit_message  Optional descriptive message for the commit
                  (default: \"Auto-commit: \$(date)\")

${CHIEF_COLOR_GREEN}Operations Performed:${CHIEF_NO_COLOR}
1. Pull latest changes from remote
2. Stage all modified files (git add .)
3. Commit changes with message
4. Push to remote repository

${CHIEF_COLOR_MAGENTA}Safety Features:${CHIEF_NO_COLOR}
- Pulls before committing to avoid conflicts
- Shows current remote URL for verification
- Uses timestamped default message if none provided

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                                # Uses default timestamp message
  $FUNCNAME \"Fix user authentication bug\"  # Custom message
  $FUNCNAME \"Add new feature: dashboard\"   # Custom message
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  # Use provided message or generate default with timestamp
  local commit_message="${1:-Auto-commit: $(date '+%Y-%m-%d %H:%M:%S')}"

  echo -e "${CHIEF_COLOR_BLUE}Repository:${CHIEF_NO_COLOR} $(git config --get remote.origin.url)"
  echo -e "${CHIEF_COLOR_BLUE}Pulling latest changes...${CHIEF_NO_COLOR}"
  git pull
  echo -e "${CHIEF_COLOR_BLUE}Staging all changes...${CHIEF_NO_COLOR}"
  git add .
  echo -e "${CHIEF_COLOR_BLUE}Committing with message:${CHIEF_NO_COLOR} $commit_message"
  git commit -a -m "$commit_message"
  echo -e "${CHIEF_COLOR_BLUE}Pushing to remote...${CHIEF_NO_COLOR}"
  git push
  echo -e "${CHIEF_COLOR_GREEN}Commit and push completed${CHIEF_NO_COLOR}"
}

function chief.git_tag() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <version> [tag_message]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Create an annotated tag for the current repository state and push to remote.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  version       Version/tag name (e.g., v1.0.0, release-2023)
  tag_message   Optional custom tag message (default: \"Tag <version> creation.\")

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Creates annotated tags (recommended over lightweight tags)
- Automatically pushes tag to remote repository
- Includes timestamp and tagger information

${CHIEF_COLOR_MAGENTA}Tag Naming Best Practices:${CHIEF_NO_COLOR}
- Semantic versioning: v1.0.0, v2.1.3
- Release names: release-2023-Q1, stable-build
- Feature tags: feature-auth, milestone-beta

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME v1.0.0                    # Tag with default message
  $FUNCNAME v1.2.0 \"Release 1.2.0\"   # Tag with custom message
  $FUNCNAME stable \"Stable release\"   # Named release
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  local commit_msg="Tag $1 creation."
  if [[ -n "$2" ]]; then
    commit_msg="$2"
  fi
  
  echo -e "${CHIEF_COLOR_BLUE}Creating annotated tag:${CHIEF_NO_COLOR} $1"
  echo -e "${CHIEF_COLOR_BLUE}Tag message:${CHIEF_NO_COLOR} $commit_msg"
  git tag -a "$1" -m "$commit_msg"
  echo -e "${CHIEF_COLOR_BLUE}Pushing tag to remote...${CHIEF_NO_COLOR}"
  git push origin "$1"
  echo -e "${CHIEF_COLOR_GREEN}Tag created and pushed successfully${CHIEF_NO_COLOR}"
}

function chief.git_branch() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <branch_name>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Create a new Git branch and set up remote tracking.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  branch_name  Name for the new branch

${CHIEF_COLOR_GREEN}Operations Performed:${CHIEF_NO_COLOR}
1. Create new branch from current HEAD
2. Switch to the new branch
3. Push to remote with upstream tracking

${CHIEF_COLOR_MAGENTA}Branch Naming Best Practices:${CHIEF_NO_COLOR}
- feature/feature-name (new features)
- bugfix/issue-description (bug fixes)
- hotfix/urgent-fix (production fixes)
- release/version-number (release branches)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME feature/user-auth     # Feature branch
  $FUNCNAME bugfix/login-error    # Bug fix branch
  $FUNCNAME release/v2.0          # Release branch
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_BLUE}Creating new branch:${CHIEF_NO_COLOR} $1"
  git checkout -b "$1"
  echo -e "${CHIEF_COLOR_BLUE}Setting up remote tracking...${CHIEF_NO_COLOR}"
  git push -u origin "$1"
  echo -e "${CHIEF_COLOR_GREEN}Branch created and tracking set up${CHIEF_NO_COLOR}"
}

function chief.git_rename_branch() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <old_name> <new_name>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Rename a Git branch locally and update the remote repository.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  old_name  Current name of the branch
  new_name  New name for the branch

${CHIEF_COLOR_GREEN}Operations Performed:${CHIEF_NO_COLOR}
1. Rename branch locally
2. Delete old branch from remote
3. Push renamed branch with tracking

${CHIEF_COLOR_MAGENTA}Branch Detection:${CHIEF_NO_COLOR}
- Automatically detects if you're on the branch being renamed
- Handles both current and non-current branch renaming

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME feature-old feature/new-auth     # Rename to follow conventions
  $FUNCNAME bugfix-123 bugfix/issue-123     # Add proper namespace
  $FUNCNAME temp release/v1.0                # Rename for release
"

  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  local current_branch=$(git branch --show-current)
  echo -e "${CHIEF_COLOR_BLUE}Renaming branch:${CHIEF_NO_COLOR} $1 → $2"
  
  if [[ "$current_branch" == "$1" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Renaming current branch...${CHIEF_NO_COLOR}"
    git branch -m "$2"
  else
    echo -e "${CHIEF_COLOR_BLUE}Renaming non-current branch...${CHIEF_NO_COLOR}"
    git branch -m "$1" "$2"
  fi
  
  echo -e "${CHIEF_COLOR_BLUE}Updating remote repository...${CHIEF_NO_COLOR}"
  git push origin ":$1" "$2"
  git push origin -u "$2"
  echo -e "${CHIEF_COLOR_GREEN}Branch renamed successfully${CHIEF_NO_COLOR}"
}

function chief.git_delete_tag() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <tag_name>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Delete a Git tag both locally and from the remote repository.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  tag_name  Name of the tag to delete

${CHIEF_COLOR_RED}Warning:${CHIEF_NO_COLOR}
This operation permanently removes the tag from both local and remote repositories.
Use with caution, especially for published releases.

${CHIEF_COLOR_GREEN}Operations Performed:${CHIEF_NO_COLOR}
1. Delete tag from local repository
2. Delete tag from remote repository
3. Verify removal

${CHIEF_COLOR_MAGENTA}Common Use Cases:${CHIEF_NO_COLOR}
- Remove incorrectly created tags
- Delete test/development tags
- Clean up abandoned release candidates

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME v1.0.0-rc1      # Delete release candidate
  $FUNCNAME test-tag        # Remove test tag
  $FUNCNAME old-release     # Clean up old tag
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} This will permanently delete tag: $1"
  echo -e "${CHIEF_COLOR_BLUE}Deleting local tag...${CHIEF_NO_COLOR}"
  git tag -d "$1"
  echo -e "${CHIEF_COLOR_BLUE}Deleting remote tag...${CHIEF_NO_COLOR}"
  git push origin ":refs/tags/$1"
  echo -e "${CHIEF_COLOR_GREEN}Tag deleted successfully${CHIEF_NO_COLOR}"
}

function chief.git_amend() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [commit_message]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Amend the last commit with staged changes and/or update the commit message.
Handles both local-only commits and commits that have been pushed to remote.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  commit_message  Optional new commit message (if omitted, keeps current message)

${CHIEF_COLOR_GREEN}Operations Performed:${CHIEF_NO_COLOR}
1. Stage any new changes (git add .)
2. Amend last commit with staged changes and/or new message
3. Intelligently push to remote (force-with-lease if previously pushed)

${CHIEF_COLOR_MAGENTA}Smart Push Logic:${CHIEF_NO_COLOR}
- If commit was never pushed: performs regular push
- If commit was already pushed: uses --force-with-lease for safety
- Automatically detects push status to prevent errors

${CHIEF_COLOR_BLUE}Common Use Cases:${CHIEF_NO_COLOR}
- Add forgotten files to last commit
- Fix typos in commit message
- Add Jira ID required by pre-commit hooks
- Include additional changes in last commit
- Correct commit message format

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                           # Amend with staged changes, keep message
  $FUNCNAME \"PROJ-123: Fix login bug\"  # Amend with new message
  $FUNCNAME \"Add missing Jira ID\"       # Fix message for pre-commit hooks

${CHIEF_COLOR_RED}Safety Notes:${CHIEF_NO_COLOR}
- Only amends the most recent commit
- Uses --force-with-lease to prevent overwriting others' work
- Automatically stages changes before amending
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_BLUE}Repository:${CHIEF_NO_COLOR} $(git config --get remote.origin.url)"
  
  # Stage any new changes
  echo -e "${CHIEF_COLOR_BLUE}Staging changes...${CHIEF_NO_COLOR}"
  git add .
  
  # Check if there are any staged changes or if we're just changing the message
  local has_staged_changes
  has_staged_changes=$(git diff --cached --name-only | wc -l)
  
  # Amend the commit
  if [[ -n "$1" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Amending commit with new message:${CHIEF_NO_COLOR} $1"
    git commit --amend -m "$1"
  else
    if [[ $has_staged_changes -gt 0 ]]; then
      echo -e "${CHIEF_COLOR_BLUE}Amending commit with staged changes (keeping message)...${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_YELLOW}No staged changes found. Use with a message to update commit message only.${CHIEF_NO_COLOR}"
      return 1
    fi
    git commit --amend --no-edit
  fi
  
  # Check if the commit has been pushed to remote
  local current_branch
  local local_commit
  local remote_commit
  current_branch=$(git branch --show-current)
  local_commit=$(git rev-parse HEAD)
  remote_commit=$(git rev-parse "origin/${current_branch}" 2>/dev/null)
  
  if [[ -n "$remote_commit" ]] && git merge-base --is-ancestor "$local_commit" "origin/${current_branch}" 2>/dev/null; then
    # Commit was already pushed, use force-with-lease
    echo -e "${CHIEF_COLOR_BLUE}Commit was previously pushed, using force-with-lease...${CHIEF_NO_COLOR}"
    git push --force-with-lease
  else
    # This is a new commit or remote doesn't exist, use regular push
    echo -e "${CHIEF_COLOR_BLUE}Pushing amended commit...${CHIEF_NO_COLOR}"
    if ! git push 2>/dev/null; then
      echo -e "${CHIEF_COLOR_YELLOW}Regular push failed, trying force-with-lease...${CHIEF_NO_COLOR}"
      git push --force-with-lease
    fi
  fi
  
  echo -e "${CHIEF_COLOR_GREEN}Commit amended and pushed successfully${CHIEF_NO_COLOR}"
}

function chief.git_delete_branch() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <branch_name>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Delete a Git branch both locally and from the remote repository.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  branch_name  Name of the branch to delete

${CHIEF_COLOR_RED}Warning:${CHIEF_NO_COLOR}
This operation permanently removes the branch from both local and remote repositories.
Ensure the branch is merged or no longer needed.

${CHIEF_COLOR_GREEN}Operations Performed:${CHIEF_NO_COLOR}
1. Delete branch from local repository
2. Delete branch from remote repository
3. Verify removal

${CHIEF_COLOR_MAGENTA}Safety Features:${CHIEF_NO_COLOR}
- Git will prevent deletion of unmerged branches (use -D to force)
- Cannot delete currently checked out branch

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME feature/completed-auth    # Delete merged feature
  $FUNCNAME bugfix/fixed-issue-123    # Remove completed bugfix
  $FUNCNAME temp-experiment           # Clean up experimental branch
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  local current_branch=$(git branch --show-current)
  if [[ "$current_branch" == "$1" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Cannot delete currently checked out branch: $1"
    echo -e "${CHIEF_COLOR_BLUE}Switch to another branch first:${CHIEF_NO_COLOR} git checkout main"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Deleting local branch:${CHIEF_NO_COLOR} $1"
  git branch -d "$1"
  echo -e "${CHIEF_COLOR_BLUE}Deleting remote branch...${CHIEF_NO_COLOR}"
  git push origin --delete "$1"
  echo -e "${CHIEF_COLOR_GREEN}Branch deleted successfully${CHIEF_NO_COLOR}"
}

function chief.git_cred_cache() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options] [seconds]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Configure Git credential handling to avoid repeated password prompts.
Supports both cache-based and environment variable authentication.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --env, -e     Use environment variables (GIT_USER, GIT_PASSWORD)
  -?            Show this help

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  seconds       Cache timeout in seconds (cache mode only, default: 86400 = 1 day)

${CHIEF_COLOR_GREEN}Cache Mode (Default):${CHIEF_NO_COLOR}
- Stores credentials in memory with timeout
- Prompts once, then reuses cached credentials
- Automatically expires after specified time

${CHIEF_COLOR_GREEN}Environment Mode (--env):${CHIEF_NO_COLOR}
- Reads credentials from GIT_USER and GIT_PASSWORD environment variables
- No caching or timeouts needed
- Ideal for CI/CD pipelines and automated environments

${CHIEF_COLOR_MAGENTA}Common Cache Timeouts:${CHIEF_NO_COLOR}
- 3600    = 1 hour
- 14400   = 4 hours  
- 28800   = 8 hours
- 86400   = 1 day (default)
- 604800  = 1 week

${CHIEF_COLOR_BLUE}Security Considerations:${CHIEF_NO_COLOR}
- Cache mode: credentials stored in memory only
- Environment mode: ensure GIT_USER/GIT_PASSWORD are secure
- Use shorter timeouts on shared machines

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                # Cache for 1 day (default)
  $FUNCNAME 3600           # Cache for 1 hour
  $FUNCNAME --env          # Use environment variables
  $FUNCNAME -e             # Use environment variables (short form)

${CHIEF_COLOR_BLUE}Environment Variable Setup:${CHIEF_NO_COLOR}
  export GIT_USER=your_username
  export GIT_PASSWORD=your_password
  $FUNCNAME --env
"

  local re='^[0-9]+$'
  local use_env_mode=false
  local timeout_value=""
  
  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      --env|-e)
        use_env_mode=true
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
        if [[ -z "$timeout_value" ]]; then
          timeout_value="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Multiple timeout values provided"
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Environment variable mode
  if [[ "$use_env_mode" == true ]]; then
    if [[ -n "$timeout_value" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Timeout value ignored in environment mode"
    fi
    
    echo -e "${CHIEF_COLOR_BLUE}Configuring environment variable credential helper...${CHIEF_NO_COLOR}"
    git config --global credential.helper '!f() { echo "username=$GIT_USER"; echo "password=$GIT_PASSWORD"; }; f'
    echo -e "${CHIEF_COLOR_GREEN}Git credentials configured to use GIT_USER and GIT_PASSWORD environment variables${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_YELLOW}Ensure the following variables are set:${CHIEF_NO_COLOR}"
    echo -e "  export GIT_USER=your_username"
    echo -e "  export GIT_PASSWORD=your_password"
    return
  fi

  # Cache mode (default behavior)
  if [[ -z "$timeout_value" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Setting default credential cache:${CHIEF_NO_COLOR} 86400 seconds (1 day)"
    git config --global credential.helper "cache --timeout=86400"
    echo -e "${CHIEF_COLOR_GREEN}Git credentials will be cached for 1 day${CHIEF_NO_COLOR}"
  elif [[ $timeout_value =~ $re ]]; then
    local hours=$((${timeout_value}/3600))
    echo -e "${CHIEF_COLOR_BLUE}Setting credential cache:${CHIEF_NO_COLOR} $timeout_value seconds (~$hours hours)"
    git config --global credential.helper "cache --timeout=$timeout_value"
    echo -e "${CHIEF_COLOR_GREEN}Git credentials will be cached for $timeout_value seconds${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Invalid timeout value. Must be a number."
    echo -e "${USAGE}"
    return 1
  fi
}

function chief.git_set_url() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <new_url>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Change the remote origin URL for the Git repository.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  new_url  New remote repository URL

${CHIEF_COLOR_GREEN}Supported URL Formats:${CHIEF_NO_COLOR}
- HTTPS: https://github.com/user/repo.git
- SSH: git@github.com:user/repo.git
- GitHub CLI: gh:user/repo
- Local: /path/to/local/repo.git

${CHIEF_COLOR_MAGENTA}Common Use Cases:${CHIEF_NO_COLOR}
- Switch from HTTPS to SSH authentication
- Change repository ownership/organization
- Move repository to different hosting service
- Update after repository rename

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME git@github.com:user/repo.git          # Switch to SSH
  $FUNCNAME https://gitlab.com/user/repo.git      # Move to GitLab
  $FUNCNAME git@github.com:neworg/repo.git        # Change organization
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_BLUE}Current URL:${CHIEF_NO_COLOR}"
  git config --get remote.origin.url
  echo -e "${CHIEF_COLOR_BLUE}Changing to:${CHIEF_NO_COLOR} $1"
  git remote set-url origin "$1"
  echo -e "${CHIEF_COLOR_GREEN}Remote URL updated successfully${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_BLUE}New URL:${CHIEF_NO_COLOR} $(git config --get remote.origin.url)"
}

function chief.git_config_user() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options] <username> [email]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Configure Git username and email for the current repository or globally.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -g, --global      Apply configuration globally (all repositories)
  -l, --local       Apply to current repository only (default)
  -s, --show        Show current configuration and exit
  -?                Show this help

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  username          Git username for commits
  email             Git email address (optional)

${CHIEF_COLOR_GREEN}Local Mode (Default):${CHIEF_NO_COLOR}
- Configuration applies to current repository only
- Overrides global settings for this repository
- Requires being inside a Git repository

${CHIEF_COLOR_GREEN}Global Mode (--global):${CHIEF_NO_COLOR}
- Configuration applies to all repositories
- Sets default values for new repositories
- Can be overridden by local repository settings

${CHIEF_COLOR_MAGENTA}Configuration Priority:${CHIEF_NO_COLOR}
1. Local repository settings (highest priority)
2. Global user settings
3. System-wide settings (lowest priority)

${CHIEF_COLOR_BLUE}Common Use Cases:${CHIEF_NO_COLOR}
- Set personal info for all repositories globally
- Use work email for specific work repositories
- Configure different identities for different projects
- Update email after changing providers

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME \"John Doe\" john@example.com         # Set both locally
  $FUNCNAME -g \"John Doe\" john@example.com      # Set both globally
  $FUNCNAME \"John Doe\"                          # Set username only (locally)
  $FUNCNAME -g \"John Doe\"                       # Set username only (globally)
  $FUNCNAME -s                                   # Show current settings
  $FUNCNAME --show                               # Show current settings

${CHIEF_COLOR_BLUE}Verification:${CHIEF_NO_COLOR}
After configuration, verify with:
  git config user.name
  git config user.email
"

  local scope="--local"
  local show_config=false
  local username=""
  local email=""
  
  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      -g|--global)
        scope="--global"
        shift
        ;;
      -l|--local)
        scope="--local"
        shift
        ;;
      -s|--show)
        show_config=true
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
        if [[ -z "$username" ]]; then
          username="$1"
        elif [[ -z "$email" ]]; then
          email="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Too many arguments"
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Show configuration mode
  if [[ "$show_config" == true ]]; then
    if [[ -n "$username" || -n "$email" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} Username/email arguments ignored in show mode"
    fi
    
    echo -e "${CHIEF_COLOR_CYAN}Current Git Configuration:${CHIEF_NO_COLOR}"
    echo ""
    
    # Show local settings if in a git repository
    if git rev-parse --git-dir >/dev/null 2>&1; then
      echo -e "${CHIEF_COLOR_BLUE}Local (Repository):${CHIEF_NO_COLOR}"
      local local_name
      local local_email
      local_name=$(git config --local user.name 2>/dev/null || echo "${CHIEF_COLOR_YELLOW}(not set)${CHIEF_NO_COLOR}")
      local_email=$(git config --local user.email 2>/dev/null || echo "${CHIEF_COLOR_YELLOW}(not set)${CHIEF_NO_COLOR}")
      echo -e "  Name:  $local_name"
      echo -e "  Email: $local_email"
      echo ""
    fi
    
    # Show global settings
    echo -e "${CHIEF_COLOR_BLUE}Global (User):${CHIEF_NO_COLOR}"
    local global_name
    local global_email
    global_name=$(git config --global user.name 2>/dev/null || echo "${CHIEF_COLOR_YELLOW}(not set)${CHIEF_NO_COLOR}")
    global_email=$(git config --global user.email 2>/dev/null || echo "${CHIEF_COLOR_YELLOW}(not set)${CHIEF_NO_COLOR}")
    echo -e "  Name:  $global_name"
    echo -e "  Email: $global_email"
    echo ""
    
    # Show effective settings
    echo -e "${CHIEF_COLOR_BLUE}Effective (Current):${CHIEF_NO_COLOR}"
    local effective_name
    local effective_email
    effective_name=$(git config user.name 2>/dev/null || echo "${CHIEF_COLOR_RED}(not configured)${CHIEF_NO_COLOR}")
    effective_email=$(git config user.email 2>/dev/null || echo "${CHIEF_COLOR_RED}(not configured)${CHIEF_NO_COLOR}")
    echo -e "  Name:  $effective_name"
    echo -e "  Email: $effective_email"
    
    return
  fi

  # Validate arguments
  if [[ -z "$username" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Username is required"
    echo -e "${USAGE}"
    return 1
  fi

  # Check if we're in a git repository for local mode
  if [[ "$scope" == "--local" ]] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Not in a Git repository. Use --global or run from inside a repository."
    return 1
  fi

  # Apply configuration
  local scope_text
  if [[ "$scope" == "--global" ]]; then
    scope_text="globally"
  else
    scope_text="for current repository"
    echo -e "${CHIEF_COLOR_BLUE}Repository:${CHIEF_NO_COLOR} $(git config --get remote.origin.url 2>/dev/null || echo "$(pwd)")"
  fi

  echo -e "${CHIEF_COLOR_BLUE}Configuring Git user $scope_text...${CHIEF_NO_COLOR}"
  
  # Set username
  git config $scope user.name "$username"
  echo -e "${CHIEF_COLOR_GREEN}Username set:${CHIEF_NO_COLOR} $username"
  
  # Set email if provided
  if [[ -n "$email" ]]; then
    git config $scope user.email "$email"
    echo -e "${CHIEF_COLOR_GREEN}Email set:${CHIEF_NO_COLOR} $email"
  fi
  
  echo -e "${CHIEF_COLOR_GREEN}Git user configuration completed${CHIEF_NO_COLOR}"
  
  # Show verification info
  echo -e "${CHIEF_COLOR_YELLOW}Verify with:${CHIEF_NO_COLOR}"
  echo -e "  git config user.name"
  echo -e "  git config user.email"
}

function chief.git_reset-soft() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Undo the last commit while keeping all changes staged for re-commit.

${CHIEF_COLOR_GREEN}Operations Performed:${CHIEF_NO_COLOR}
1. Reset HEAD pointer to previous commit (HEAD~1)
2. Keep all changes from last commit in staging area
3. Preserve working directory files unchanged

${CHIEF_COLOR_MAGENTA}Key Benefits:${CHIEF_NO_COLOR}
- Safe operation (no data loss)
- Changes remain staged for easy re-commit
- Allows fixing commit messages or adding forgotten files
- Ideal for correcting the most recent commit

${CHIEF_COLOR_BLUE}When to Use:${CHIEF_NO_COLOR}
- Fix typos in the last commit message
- Add forgotten files to the last commit
- Split the last commit into multiple commits
- Correct staging mistakes in recent commit

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME          # Undo last commit, keep changes staged
  
${CHIEF_COLOR_BLUE}After running this command:${CHIEF_NO_COLOR}
- Previous commit is removed from history
- All files from that commit remain staged
- Use 'git commit' to create new commit with same or different message
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_BLUE}Repository:${CHIEF_NO_COLOR} $(git config --get remote.origin.url)"
  echo -e "${CHIEF_COLOR_BLUE}Undoing last commit (keeping changes staged)...${CHIEF_NO_COLOR}"
  git reset --soft HEAD~1
  echo -e "${CHIEF_COLOR_GREEN}Last commit undone - changes remain staged${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}Tip:${CHIEF_NO_COLOR} Use 'git status' to see staged files"
}

function chief.git_reset-hard() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Reset local repository to match the latest remote version, discarding all local changes.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -n, --dry-run   Show what files would be affected without making changes
  -?              Show this help

${CHIEF_COLOR_RED}Warning:${CHIEF_NO_COLOR}
This operation permanently discards all uncommitted local changes!
Use with extreme caution.

${CHIEF_COLOR_GREEN}Operations Performed:${CHIEF_NO_COLOR}
1. Display current remote URL for verification
2. Perform hard reset to HEAD
3. Discard all working directory changes

${CHIEF_COLOR_MAGENTA}When to Use:${CHIEF_NO_COLOR}
- Local repository is in broken state
- Want to abandon all local changes
- Need clean slate matching remote
- Resolving complex merge conflicts

${CHIEF_COLOR_BLUE}Safer Alternatives:${CHIEF_NO_COLOR}
- git stash (save changes temporarily)
- git checkout -- <file> (reset specific files)
- git clean -fd (remove untracked files only)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME              # Reset repository, discarding all local changes
  $FUNCNAME -n           # Dry-run: show what files would be affected (SAFE)

${CHIEF_COLOR_YELLOW}Recovery Note:${CHIEF_NO_COLOR}
Changes reset by this command cannot be recovered unless previously committed.
"

  local dry_run=false
  
  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
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
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} This command takes no positional arguments"
        echo -e "${USAGE}"
        return 1
        ;;
    esac
  done

  echo -e "${CHIEF_COLOR_BLUE}Repository:${CHIEF_NO_COLOR} $(git config --get remote.origin.url)"
  
  # Dry-run mode
  if [[ "$dry_run" == true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}DRY RUN: Analyzing what would be affected by git reset --hard${CHIEF_NO_COLOR}"
    echo ""
    
    # Show modified files that would be reset
    local modified_files
    modified_files=$(git diff --name-only HEAD 2>/dev/null)
    if [[ -n "$modified_files" ]]; then
      echo -e "${CHIEF_COLOR_CYAN}Modified files that would be reset:${CHIEF_NO_COLOR}"
      while IFS= read -r file; do
        [[ -n "$file" ]] && echo "  - $file"
      done <<< "$modified_files"
      echo ""
    fi
    
    # Show staged files that would be reset
    local staged_files
    staged_files=$(git diff --name-only --cached 2>/dev/null)
    if [[ -n "$staged_files" ]]; then
      echo -e "${CHIEF_COLOR_CYAN}Staged files that would be reset:${CHIEF_NO_COLOR}"
      while IFS= read -r file; do
        [[ -n "$file" ]] && echo "  - $file"
      done <<< "$staged_files"
      echo ""
    fi
    
    # Show untracked files that would be removed (if git clean would run)
    local untracked_files
    untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null)
    if [[ -n "$untracked_files" ]]; then
      echo -e "${CHIEF_COLOR_CYAN}Untracked files that would remain (git reset --hard doesn't remove these):${CHIEF_NO_COLOR}"
      while IFS= read -r file; do
        [[ -n "$file" ]] && echo "  - $file"
      done <<< "$untracked_files"
      echo ""
      echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} To remove untracked files, use: git clean -fd"
    fi
    
    # Show current branch and HEAD info
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    local head_commit
    head_commit=$(git rev-parse --short HEAD 2>/dev/null)
    
    echo -e "${CHIEF_COLOR_BLUE}Current branch:${CHIEF_NO_COLOR} $current_branch"
    echo -e "${CHIEF_COLOR_BLUE}HEAD commit:${CHIEF_NO_COLOR} $head_commit"
    echo -e "${CHIEF_COLOR_BLUE}Reset target:${CHIEF_NO_COLOR} HEAD (same commit)"
    echo ""
    
    if [[ -z "$modified_files" && -z "$staged_files" ]]; then
      echo -e "${CHIEF_SYMBOL_CHECK} No changes to reset - working directory is clean"
    else
      echo -e "${CHIEF_COLOR_RED}${CHIEF_SYMBOL_WARNING}  WARNING: This would permanently discard the above changes!${CHIEF_NO_COLOR}"
    fi
    
    echo ""
    echo -e "${CHIEF_COLOR_GREEN}DRY RUN COMPLETE${CHIEF_NO_COLOR} - No changes were made"
    echo -e "${CHIEF_COLOR_YELLOW}Remove -n/--dry-run flag to perform actual reset${CHIEF_NO_COLOR}"
    return 0
  fi

  echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} This will discard ALL local changes!"
  echo -e "${CHIEF_COLOR_BLUE}Performing hard reset...${CHIEF_NO_COLOR}"
  git reset --hard
  echo -e "${CHIEF_COLOR_GREEN}Local repository reset to match remote${CHIEF_NO_COLOR}"
}

function chief.git_untrack() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <file_or_directory>

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Remove a file or directory from Git tracking while keeping it in the working directory.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  file_or_directory  Path to file or directory to untrack

${CHIEF_COLOR_GREEN}Operations Performed:${CHIEF_NO_COLOR}
1. Clear assume-unchanged flag
2. Remove from Git index (staging area)
3. Keep file in working directory

${CHIEF_COLOR_MAGENTA}Common Use Cases:${CHIEF_NO_COLOR}
- Stop tracking configuration files with sensitive data
- Untrack build artifacts that were accidentally added
- Remove large files from version control
- Stop tracking IDE-specific files

${CHIEF_COLOR_BLUE}Important Notes:${CHIEF_NO_COLOR}
- File remains in working directory
- Add to .gitignore to prevent re-tracking
- Use git rm to delete file entirely

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME config/secrets.yml     # Untrack config file
  $FUNCNAME build/                 # Untrack build directory
  $FUNCNAME *.log                  # Untrack log files
"

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  if [[ ! -e "$1" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} File or directory not found: $1"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Repository:${CHIEF_NO_COLOR} $(git config --get remote.origin.url)"
  echo -e "${CHIEF_COLOR_BLUE}Untracking:${CHIEF_NO_COLOR} $1"
  git update-index --no-assume-unchanged "$1"
  git rm -r --cached "$1"
  echo -e "${CHIEF_COLOR_GREEN}File untracked successfully${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}Tip:${CHIEF_NO_COLOR} Add '$1' to .gitignore to prevent re-tracking"
}

function chief.git_legend() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Display the character legend for Git prompt symbols when CHIEF_CFG_GIT_PROMPT is enabled.

${CHIEF_COLOR_GREEN}Prompt Enhancement:${CHIEF_NO_COLOR}
When CHIEF_CFG_GIT_PROMPT=true, your prompt shows Git repository status with symbolic indicators.

${CHIEF_COLOR_BLUE}Symbol Meanings:${CHIEF_NO_COLOR}
  ${CHIEF_COLOR_GREEN}=${CHIEF_NO_COLOR}  Local and remote versions match (up to date)
  ${CHIEF_COLOR_YELLOW}<${CHIEF_NO_COLOR}  Pull needed (remote has new changes)
  ${CHIEF_COLOR_YELLOW}>${CHIEF_NO_COLOR}  Push needed (local has unpushed commits)
  ${CHIEF_COLOR_RED}*${CHIEF_NO_COLOR}  Unstaged changes (modified files)
  ${CHIEF_COLOR_GREEN}+${CHIEF_NO_COLOR}  Staged changes (ready to commit)
  ${CHIEF_COLOR_BLUE}\$${CHIEF_NO_COLOR}  Stashed changes (saved work)
  ${CHIEF_COLOR_MAGENTA}%${CHIEF_NO_COLOR}  Untracked files (new files not in Git)

${CHIEF_COLOR_MAGENTA}Configuration:${CHIEF_NO_COLOR}
Set CHIEF_CFG_GIT_PROMPT=true in chief.config to enable Git prompt indicators.

${CHIEF_COLOR_YELLOW}Example Prompt:${CHIEF_NO_COLOR}
  user@host ~/project (main *+) \$  # On main branch with unstaged and staged changes
"

  if [[ $1 == "-?" ]]; then
    echo -e "${USAGE}"
    return
  fi

  echo -e "${CHIEF_COLOR_CYAN}Git Prompt Legend${CHIEF_NO_COLOR} (when CHIEF_CFG_GIT_PROMPT=true):"
  echo ""
  echo -e "  ${CHIEF_COLOR_GREEN}=${CHIEF_NO_COLOR}  Local and remote versions match"
  echo -e "  ${CHIEF_COLOR_YELLOW}<${CHIEF_NO_COLOR}  Pull needed to get remote changes"
  echo -e "  ${CHIEF_COLOR_YELLOW}>${CHIEF_NO_COLOR}  Push needed to send local changes"
  echo -e "  ${CHIEF_COLOR_RED}*${CHIEF_NO_COLOR}  Unstaged changes (modified files)"
  echo -e "  ${CHIEF_COLOR_GREEN}+${CHIEF_NO_COLOR}  Staged changes (ready to commit)"
  echo -e "  ${CHIEF_COLOR_BLUE}\$${CHIEF_NO_COLOR}  Stashed changes (temporarily saved)"
  echo -e "  ${CHIEF_COLOR_MAGENTA}%${CHIEF_NO_COLOR}  Untracked files (new, not in Git)"
  echo ""
  echo -e "${CHIEF_COLOR_BLUE}Enable with:${CHIEF_NO_COLOR} chief.config → CHIEF_CFG_GIT_PROMPT=true"
}
