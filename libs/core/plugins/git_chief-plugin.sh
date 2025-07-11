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
# ver. 1.0
# Functions and aliases that are development to Git.

alias chief.git_url='git config --get remote.origin.url'

function chief.git_clone() {
  local USAGE="Usage: $FUNCNAME <repo URL>

Modified version of git clone that also grabs submodules automatically."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  git clone --recurse-submodules --remote-submodules "$1"
}

function chief.git_update() {
  local USAGE="Usage: $FUNCNAME [-p]

Perform a full update (pull/push) to update local with remote/server origin.
  Optionally pass '-p' to pull-only (skipping push and fetching tag changes)."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
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
  local USAGE="Usage: $FUNCNAME <commit message>

Commit (if necessary) any changes to Git and apply message."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  git config --get remote.origin.url
  git pull
  git add .
  if [[ -z $1 ]]; then
    git commit -a
  else
    git commit -a -m "$1"
  fi
  git push
}

function chief.git_tag() {
  local USAGE="Usage: $FUNCNAME <version> [tag commit message]

Tag current state of git repo. Optionally pass a tag commit message."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  local commit_msg="Tag $1 creation."
  if [[ -n "$2" ]]; then
    commit_msg=$2
  fi
  git tag -a "$1" -m "$commit_msg"
  git push origin "$1"
}

function chief.git_branch() {
  local USAGE="Usage: $FUNCNAME <branch name>

Create a git branch and push remotely."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  git checkout -b "$1"
  git push -u origin "$1"
}

function chief.git_rename_branch() {
  local USAGE="Usage: $FUNCNAME <old_name> <new_name>

Rename git branch and push changes to remote."

  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  local current_branch=$(git branch --show-current)
  echo "Renaming $1 to $2"
  if [[ "$current_branch" == "$1" ]]; then
    git branch -m "$2"
  else
    git branch -m "$1" "$2"
  fi
  echo "Pushing changes to git remote"
  git push origin ":$1" "$2"
  git push origin -u "$2"
}

function chief.git_delete_tag() {
  local USAGE="Usage: $FUNCNAME <tag name>

Delete a git tag and push remotely."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  git tag -d "$1"
  git push origin ":refs/tags/$1"
}

function chief.git_delete_branch() {
  local USAGE="Usage: $FUNCNAME <branch name>

Delete a git branch and push remotely."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  git branch -d "$1"
  git push origin --delete "$1"
}

function chief.git_cred_cache() {
  local USAGE="Usage: $FUNCNAME <# of seconds>

Cache git credentials for the passed # of seconds. Default is 1 day."
  re='^[0-9]+$'
  if [[ -z $1 ]]; then
    git config --global credential.helper "cache --timeout=86400"
    echo "Git credentials will be cached for 86400 seconds."
  elif [[ $1 =~ $re ]]; then
    git config --global credential.helper "cache --timeout=$1"
    echo "Git credentials will be cached for $1 seconds."
  elif [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi
}

function chief.git_set_url() {
  local USAGE="Usage: $FUNCNAME <url>

Change / set the remote git url."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  echo "Current URL:"
  git config --get remote.origin.url
  echo "Changing to...$1"
  git remote set-url origin "$1"
}

function chief.git_reset-local() {
  local USAGE="Usage: $FUNCNAME

Reset local branch repo to match latest server version."

  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  git config --get remote.origin.url
  git reset --hard
}

function chief.git_untrack() {
  local USAGE="Usage: $FUNCNAME <file>

Untrack a file from being versioned in Git."

  if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  git config --get remote.origin.url
  git update-index --no-assume-unchanged $1
  git rm -r --cached $1
}

function chief.git_legend() {
  local USAGE="Usage: $FUNCNAME

Display character legend for git prompt when CHIEF_CFG_GIT_PROMPT is set."
  echo "Git prompt legend when CHIEF_CFG_GIT_PROMPT is set:"
  echo "  '=' = local / remote version matches"
  echo "  '<' = pull needed to get remote changes to local"
  echo "  '>' = push needed to push local changes to remote"
  echo "  '*' = unstaged changes"
  echo "  '+' = staged changes"
  echo "  '$' = stashed changes"
  echo "  '%' = untracked changes"
}
