#!/usr/bin/env bash
# Chief plugin name: $CHIEF_PLUGIN_NAME
###################################################################################################
# THIS IS A TEMPLATE FOR THE CHIEF UTILITY LIBRARY. 
# You can edit this template defined in $CHIEF_CFG_PLUGIN_TEMPLATE
# The variable $CHIEF_PLUGIN_NAME will be replaced with the name of the plugin upon creation.
# 
# Here are sample alias and function definitions for the plugin.
# It is helpful to name your function and aliases with a prefix that includes the plugin name
# to avoid conflicts with other plugins or the core Chief library. 
# It is also easy to find later with the command: <plugin name>.[tab]
#
# This template is meant to be used as a starting point for your own Chief utility library plugin.
# FEEL FREE TO REMOVE THIS HEADER UPON CREATION OF YOUR PLUGIN.
###################################################################################################

# This file will be loaded as a plugin and can be edited with: 
# $>chief.plugin $CHIEF_PLUGIN_NAME
# Once created, try the command: 
# $>$CHIEF_PLUGIN_NAME.[tab]

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

echo "Chief plugin: $CHIEF_PLUGIN_NAME loaded."

# Sample alias 
alias $CHIEF_PLUGIN_NAME.weather='curl -s --connect-timeout 3 -m 5 http://wttr.in/Sitka,AK?0/u'

# Sample function
function $CHIEF_PLUGIN_NAME.function1() {
  local USAGE="Usage: $FUNCNAME
This is a sample plugin function for the Chief utility library.
"
  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  echo "This is a sample plugin function for the Chief utility library."
  echo "PS: If you like the weather alias, see options at: https://github.com/chubin/wttr.in"
}

