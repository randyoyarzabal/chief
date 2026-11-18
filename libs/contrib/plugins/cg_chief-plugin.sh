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

# Chief Plugin File: cg_chief-plugin.sh
# Author: Randy E. Oyarzabal
#
# CONTRIB plugin: shipped with Chief and scanned on every load, but OFF by default.
# Turn it on with:  chief.plugin enable contrib.cg    (off again: chief.plugin disable contrib.cg)
#
# Exposes the Chainguard customer-success helper functions under a "cg." namespace,
# following Chief's "<prefix>.<function>" convention (like chief.help), so `cg.[tab]`
# lists them all. See: https://github.com/randyoyarzabal/chief
#
# This plugin does NOT ship the helper functions. It sources your local copy from the
# path in CHIEF_CFG_CG_HELPER_FUNCTIONS; set it once with:
#   chief.config-set cg_helper_functions "/path/to/customer-success/scripts/.helper_functions.sh"
# The original functions are left untouched; each cg.* wrapper adds -?/--help and
# passes all other arguments straight through.

CG_HELPER_FUNCTIONS=""
CG_HELPERS_LOADED=false

# Source the local helper functions from CHIEF_CFG_CG_HELPER_FUNCTIONS.
# No default location is assumed: everyone keeps their clone somewhere different.
function __cg_load_helpers() {
  CG_HELPERS_LOADED=false
  CG_HELPER_FUNCTIONS="${CHIEF_CFG_CG_HELPER_FUNCTIONS:-}"
  if [[ -z "${CG_HELPER_FUNCTIONS}" || ! -f "${CG_HELPER_FUNCTIONS}" ]]; then
    if [[ -n "${CG_HELPER_FUNCTIONS}" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}cg plugin:${CHIEF_NO_COLOR} helper functions not found at ${CHIEF_COLOR_CYAN}${CG_HELPER_FUNCTIONS}${CHIEF_NO_COLOR}" >&2
    else
      echo -e "${CHIEF_COLOR_YELLOW}cg plugin:${CHIEF_NO_COLOR} path to the customer-success helper functions is not set." >&2
    fi
    echo -e "  Point it at .helper_functions.sh in your local clone of chainguard-dev/customer-success:" >&2
    echo -e "  ${CHIEF_COLOR_GREEN}chief.config-set cg_helper_functions \"/path/to/customer-success/scripts/.helper_functions.sh\"${CHIEF_NO_COLOR}" >&2
    return 1
  fi
  # shellcheck source=/dev/null
  if source "${CG_HELPER_FUNCTIONS}"; then
    CG_HELPERS_LOADED=true
  else
    echo -e "${CHIEF_COLOR_RED}cg plugin:${CHIEF_NO_COLOR} failed to source ${CG_HELPER_FUNCTIONS}" >&2
    return 1
  fi
}

# Shared wrapper: prints help for -?/--help, otherwise calls the original function.
# Usage: __cg_call <original_fn> <args_usage> <description> [args...]
function __cg_call() {
  local fn="$1" args_usage="$2" description="$3"
  shift 3
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} cg.${fn} ${args_usage}

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
${description}

${CHIEF_COLOR_BLUE}Source:${CHIEF_NO_COLOR} ${fn}() in ${CG_HELPER_FUNCTIONS}"
    return 0
  fi
  if [[ ${CG_HELPERS_LOADED} != true ]] || ! declare -F "${fn}" >/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} ${fn}() is not loaded. Check the path, then run ${CHIEF_COLOR_GREEN}cg.reload${CHIEF_NO_COLOR}." >&2
    return 1
  fi
  "${fn}" "$@"
}

function cg.reset_login() {
  __cg_call reset_login "" \
"Log out of chainctl, log back in as your Google federated identity (\$CGR_GOOGLE_IDENTITY),
and reconfigure Docker credentials for it." "$@"
}

function cg.check_auth() {
  __cg_call check_auth "" \
"Check that chainctl is logged in as \$CGR_GOOGLE_IDENTITY; if not, log out and back in as it.
Fails with setup instructions if CGR_GOOGLE_IDENTITY is not set." "$@"
}

function cg.create_publisher() {
  __cg_call create_publisher "<org_id>" \
"Grant the Chainguard image-pusher identity the registry.push role on <org_id>.
Retries up to 3 times, then prints the manual command." "$@"
}

function cg.setup_customer_org() {
  __cg_call setup_customer_org "<customer_domain>" \
"Create a customer organization named <customer_domain> (asks for confirmation),
then grant publisher access to it. Steps 1-2 of the new-customer playbook." "$@"
}

function cg.get_customer_id() {
  __cg_call get_customer_id "<customer_domain>" \
"Print the ID of \"<customer_domain> support identity\" in the chainguard-support org.
Exists only after the org is added to support.tf and provisioning has run." "$@"
}

function cg.cli() {
  __cg_call cli "<customer_domain>" \
"Log in to chainctl (and apk.cgr.dev, Docker) as the customer's support identity." "$@"
}

function cg.console() {
  __cg_call console "<customer_domain>" \
"Open the Chainguard Console logged in as the customer's support identity.
Log out of console.chainguard.dev in your browser first." "$@"
}

function cg.tag_history() {
  __cg_call tag_history "[<parent>/]<repo>[:<tag>]" \
"Show the tag history for a cgr.dev repo.
<parent> defaults to chainguard-private; <tag> defaults to latest." "$@"
}

function cg.create_customer_yaml() {
  __cg_call create_customer_yaml "<customer_domain>" \
"Write a starter ./<customer_domain>.yaml for the images-private customers directory
(appends if the file exists)." "$@"
}

function cg.reload() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Re-source the helper functions from ${CG_HELPER_FUNCTIONS}
(e.g. after git pull in your customer-success clone)."
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi
  __cg_load_helpers && echo -e "${CHIEF_SYMBOL_CHECK:-✓} Reloaded ${CG_HELPER_FUNCTIONS}"
}

function cg.help() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
List the cg.* commands. Run any of them with -? or --help for details."
  if [[ $1 == "-?" || $1 == "--help" ]]; then
    echo -e "${USAGE}"
    return 0
  fi
  local status="${CHIEF_COLOR_GREEN}loaded${CHIEF_NO_COLOR}"
  [[ ${CG_HELPERS_LOADED} == true ]] || status="${CHIEF_COLOR_RED}not loaded${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_CYAN}Chainguard helper functions${CHIEF_NO_COLOR} (${status}): ${CG_HELPER_FUNCTIONS:-path not set; run: chief.config-set cg_helper_functions <path>}

  ${CHIEF_COLOR_GREEN}cg.setup_customer_org${CHIEF_NO_COLOR} <customer_domain>   Create a customer org and grant publisher access
  ${CHIEF_COLOR_GREEN}cg.create_customer_yaml${CHIEF_NO_COLOR} <customer_domain> Write a starter images-private customer YAML
  ${CHIEF_COLOR_GREEN}cg.get_customer_id${CHIEF_NO_COLOR} <customer_domain>      Print the customer's support identity ID
  ${CHIEF_COLOR_GREEN}cg.cli${CHIEF_NO_COLOR} <customer_domain>                  Log in to the CLI as the support identity
  ${CHIEF_COLOR_GREEN}cg.console${CHIEF_NO_COLOR} <customer_domain>              Open the Console as the support identity
  ${CHIEF_COLOR_GREEN}cg.tag_history${CHIEF_NO_COLOR} [<parent>/]<repo>[:<tag>]  Show tag history for a cgr.dev repo
  ${CHIEF_COLOR_GREEN}cg.check_auth${CHIEF_NO_COLOR}                             Ensure you're logged in as \$CGR_GOOGLE_IDENTITY
  ${CHIEF_COLOR_GREEN}cg.reset_login${CHIEF_NO_COLOR}                            Log back in as \$CGR_GOOGLE_IDENTITY
  ${CHIEF_COLOR_GREEN}cg.create_publisher${CHIEF_NO_COLOR} <org_id>              Grant registry.push to the image pusher
  ${CHIEF_COLOR_GREEN}cg.reload${CHIEF_NO_COLOR}                                 Re-source the helper functions

Disable this plugin with: ${CHIEF_COLOR_GREEN}chief.plugin disable contrib.cg${CHIEF_NO_COLOR}"
}

# A missing/unset path only warns; the plugin still loads so cg.help and --help work.
__cg_load_helpers || true
