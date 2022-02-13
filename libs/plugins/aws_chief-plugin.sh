#!/usr/bin/env bash
# Chief Plugin File: aws_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0
# AWS related functions and aliases

# Note this library requires python3

AWS_CREDS_SCRIPT="$CHIEF_PATH/libs/plugins/python/aws_creds.py"

function aws.set_role() {
  local USAGE="Usage: $FUNCNAME <role> <region>

Set role as default role in AWS credentials file.
"
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_ACCESS_KEY_ID
  unset AWS_SESSION_TOKEN
  unset AWS_REGION
  unset AWS_DEFAULT_REGION

  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  $AWS_CREDS_SCRIPT -u "$1" -r "$2"
}

function aws.export_creds() {
  local USAGE="Usage: $FUNCNAME <role> <region>

Export role and rename AWS credentials file.
"
  if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  # For some reason this doesn't work
  #source <("$AWS_CREDS_SCRIPT -u $1 -r $2 -e")

  # Work around
  output=$(eval "$AWS_CREDS_SCRIPT -u $1 -r $2 -e")
  echo "$output" > ~/.aws_envs  && source ~/.aws_envs $$ rm ~/.aws_envs
  echo "Credentials exported."
  echo "$output" | grep '#'
}
