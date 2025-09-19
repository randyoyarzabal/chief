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
# ver. 1.0
# Functions and aliases that are Openshift related.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

# Note: Uses __print_* functions from Chief core library for consistent messaging

function chief.oc.login() {
  local USAGE="Usage: $FUNCNAME <cluster_name> [options]

Login to an OpenShift cluster using Vault secrets (preferred) or local cluster definitions.

Arguments:
  cluster_name    Name of the cluster to connect to

Options:
  -kc             Use kubeconfig authentication
  -ka             Use kubeadmin authentication  
  -i              Skip TLS verification (insecure)
  -?              Show this help

Authentication Methods (in order of preference):
  1. Vault (Recommended) - Requires:
     • VAULT_ADDR and VAULT_TOKEN environment variables
     • CHIEF_VAULT_OC_PATH (e.g., 'secrets/openshift')
     • Vault secret at: \${CHIEF_VAULT_OC_PATH}/\${cluster_name}
       - api: OpenShift API URL
       - kubeconfig: kubeconfig file content (for -kc)
       - kubeadmin: kubeadmin password (for -ka)
  
  2. Local Clusters - CHIEF_OC_CLUSTERS array:
     declare -gA CHIEF_OC_CLUSTERS=(
       ['cluster1']='https://api.cluster1.com,username,password'
     )

  3. Environment Variables (fallback):
     • CHIEF_OC_USERNAME and optionally CHIEF_OC_PASSWORD

Examples:
  $FUNCNAME hub -kc         # Login with kubeconfig
  $FUNCNAME hub -ka         # Login as kubeadmin  
  $FUNCNAME hub -i          # Login with TLS verification disabled
  $FUNCNAME hub             # Login with user credentials"
  # Parse arguments
  local cluster="$1"
  local auth_method="user"
  local tls_option=""

  if [[ -z "$cluster" || "$cluster" == "-?" ]]; then
    echo "${USAGE}"
    return 0
  fi

  # Parse options
  shift
  while [[ $# -gt 0 ]]; do
    case $1 in
      -kc) auth_method="kubeconfig"; shift ;;
      -ka) auth_method="kubeadmin"; shift ;;
      -i) tls_option="--insecure-skip-tls-verify=true"; shift ;;
      *) __print_error "Unknown option: $1"; return 1 ;;
    esac
  done

  # Validate prerequisites
  if ! command -v oc &>/dev/null; then
    __print_error "OpenShift CLI (oc) is not installed or not in PATH."
    return 1
  fi

  # Handle specific authentication methods (don't fall back to others)
  if [[ "$auth_method" == "kubeconfig" ]]; then
    __oc_try_vault_login "$cluster" "$auth_method" "$tls_option"
    return $?
  elif [[ "$auth_method" == "kubeadmin" ]]; then
    __oc_try_vault_login "$cluster" "$auth_method" "$tls_option"
    return $?
  fi
  
  # Try authentication methods in order of preference (auto mode)
  if __oc_try_vault_login "$cluster" "$auth_method" "$tls_option"; then
    return 0
  elif __oc_try_local_clusters_login "$cluster" "$auth_method" "$tls_option"; then
    return 0
  elif __oc_try_env_login "$cluster" "$auth_method" "$tls_option"; then
    return 0
  else
    __print_error "All authentication methods failed for cluster: $cluster"
    return 1
  fi
}

# Helper function to attempt Vault-based login
function __oc_try_vault_login() {
  # Usage: __oc_try_vault_login <cluster> <auth_method> <tls_option>
  # 
  # Developer usage: Attempts to authenticate to OpenShift using Vault secrets
  # - Checks Vault CLI availability and prerequisites (VAULT_ADDR, VAULT_TOKEN, CHIEF_VAULT_OC_PATH)
  # - Validates that cluster secret exists in Vault
  # - Delegates to specific authentication method handlers
  # - Returns 0 on success, 1 on failure with appropriate warning messages
  #
  # Arguments:
  #   cluster - Name of the cluster to connect to
  #   auth_method - Authentication method: "kubeconfig", "kubeadmin", or "user"
  #   tls_option - TLS option string (e.g., "--insecure-skip-tls-verify=true" or "")
  
  local cluster="$1"
  local auth_method="$2" 
  local tls_option="$3"
  
  # Check Vault prerequisites
  if ! command -v vault &>/dev/null; then
    __print_warn "Vault CLI not available, skipping Vault authentication"
    return 1
  fi

  if [[ -z "$VAULT_ADDR" || -z "$VAULT_TOKEN" ]]; then
    __print_warn "VAULT_ADDR or VAULT_TOKEN not set, skipping Vault authentication"
    return 1
  fi

  if [[ -z "$CHIEF_VAULT_OC_PATH" ]]; then
    __print_warn "CHIEF_VAULT_OC_PATH not set, skipping Vault authentication"
    return 1
  fi

  # Check if cluster secret exists
  if ! vault kv get "${CHIEF_VAULT_OC_PATH}/${cluster}" &>/dev/null; then
    __print_warn "No Vault secret found at ${CHIEF_VAULT_OC_PATH}/${cluster}"
    return 1
  fi

  __print_info "Using Vault authentication for cluster: $cluster"
  
  local api_url
  api_url=$(vault kv get -field=api "${CHIEF_VAULT_OC_PATH}/${cluster}" 2>/dev/null)
  if [[ -z "$api_url" ]]; then
    __print_error "API URL not found in Vault secret"
    return 1
  fi

  case "$auth_method" in
    kubeconfig)
      __oc_vault_kubeconfig_login "$cluster" "$api_url" "$tls_option"
      ;;
    kubeadmin)
      __oc_vault_kubeadmin_login "$cluster" "$api_url" "$tls_option"
      ;;
    user)
      __oc_vault_user_login "$cluster" "$api_url" "$tls_option"
      ;;
  esac
}

# Helper function for Vault kubeconfig login
function __oc_vault_kubeconfig_login() {
  # Usage: __oc_vault_kubeconfig_login <cluster> <api_url> <tls_option>
  # 
  # Developer usage: Handles kubeconfig-based authentication using Vault secrets
  # - Retrieves kubeconfig content from Vault secret
  # - Writes kubeconfig to /tmp/kubeconfig and sets KUBECONFIG environment variable
  # - Used specifically for -kc authentication method
  # - Returns 0 on success, 1 if kubeconfig not found in Vault
  #
  # Arguments:
  #   cluster - Name of the cluster (used for Vault path)
  #   api_url - OpenShift API URL (retrieved from Vault)
  #   tls_option - TLS option string (not used in kubeconfig method)
  
  local cluster="$1"
  local api_url="$2"
  local tls_option="$3"
  
  local kubeconfig
  kubeconfig=$(vault kv get -field=kubeconfig "${CHIEF_VAULT_OC_PATH}/${cluster}" 2>/dev/null)
  if [[ -z "$kubeconfig" ]]; then
    __print_error "Kubeconfig not found in Vault (try -ka for kubeadmin)"
    return 1
  fi

  __print_info "Setting up kubeconfig from Vault..."
  
  # Remove existing kubeconfig if it exists to avoid overwrite protection
  [[ -f /tmp/kubeconfig ]] && rm -f /tmp/kubeconfig
  
  # Write kubeconfig to temp file
  echo "$kubeconfig" > /tmp/kubeconfig
  chmod 600 /tmp/kubeconfig  # Secure permissions
  
  export KUBECONFIG=/tmp/kubeconfig
  __print_success "KUBECONFIG set to /tmp/kubeconfig"
  
  # Validate that the login actually works
  local current_user
  current_user=$(oc whoami 2>/dev/null)
  
  if [[ -n "$current_user" && "$current_user" != "Unknown" ]]; then
    __print_success "Logged in as: $current_user"
    return 0
  else
    __print_error "Login validation failed - kubeconfig may have invalid CA or expired credentials"
    __print_error "Try refreshing the kubeconfig in Vault or use -ka for kubeadmin login"
    return 1
  fi
}

# Helper function for Vault kubeadmin login  
function __oc_vault_kubeadmin_login() {
  # Usage: __oc_vault_kubeadmin_login <cluster> <api_url> <tls_option>
  # 
  # Developer usage: Handles kubeadmin authentication using Vault secrets
  # - Retrieves kubeadmin password from Vault secret
  # - Performs oc login with kubeadmin user and retrieved password
  # - Used specifically for -ka authentication method
  # - Returns 0 on successful login, 1 if password not found or login fails
  #
  # Arguments:
  #   cluster - Name of the cluster (used for Vault path)
  #   api_url - OpenShift API URL to connect to
  #   tls_option - TLS option string for oc login command
  
  local cluster="$1"
  local api_url="$2"
  local tls_option="$3"
  
  local kubepass
  kubepass=$(vault kv get -field=kubeadmin "${CHIEF_VAULT_OC_PATH}/${cluster}" 2>/dev/null)
  if [[ -z "$kubepass" ]]; then
    __print_error "Kubeadmin password not found in Vault (try -kc for kubeconfig)"
    return 1
  fi

  __print_info "Logging in as kubeadmin to $api_url..."
  if oc login -u "kubeadmin" -p "$kubepass" "$api_url" $tls_option; then
    __print_success "Logged in as: $(oc whoami) - Console: $(oc whoami --show-console 2>/dev/null || echo 'N/A')"
    return 0
  else
    __print_error "Kubeadmin login failed"
    return 1
  fi
}

# Helper function for Vault user login
function __oc_vault_user_login() {
  # Usage: __oc_vault_user_login <cluster> <api_url> <tls_option>
  # 
  # Developer usage: Handles user credential authentication with API URL from Vault
  # - Uses CHIEF_OC_USERNAME and optionally CHIEF_OC_PASSWORD environment variables
  # - Performs oc login with user credentials to API URL retrieved from Vault
  # - Used for default authentication method (no -kc or -ka flags)
  # - Returns 0 on successful login, 1 if username not set or login fails
  #
  # Arguments:
  #   cluster - Name of the cluster (used for Vault path)
  #   api_url - OpenShift API URL to connect to
  #   tls_option - TLS option string for oc login command
  
  local cluster="$1"
  local api_url="$2"
  local tls_option="$3"
  
  if [[ -z "$CHIEF_OC_USERNAME" ]]; then
    __print_error "CHIEF_OC_USERNAME not set for user authentication"
    return 1
  fi

  __print_info "Logging in as $CHIEF_OC_USERNAME to $api_url..."
  if [[ -n "$CHIEF_OC_PASSWORD" ]]; then
    oc login -u "$CHIEF_OC_USERNAME" -p "$CHIEF_OC_PASSWORD" --server="$api_url" $tls_option
  else
    oc login -u "$CHIEF_OC_USERNAME" --server="$api_url" $tls_option
  fi
  
  if [[ $? -eq 0 ]]; then
    __print_success "Logged in as: $(oc whoami) - Console: $(oc whoami --show-console 2>/dev/null || echo 'N/A')"
    return 0
  else
    __print_error "User login failed"
    return 1
  fi
}

# Helper function to attempt local cluster login
function __oc_try_local_clusters_login() {
  # Usage: __oc_try_local_clusters_login <cluster> <auth_method> <tls_option>
  # 
  # Developer usage: Attempts authentication using local CHIEF_OC_CLUSTERS array
  # - Checks if cluster is defined in CHIEF_OC_CLUSTERS associative array
  # - Only supports "user" authentication method (not kubeconfig or kubeadmin)
  # - Parses cluster definition format: "api_url,username,password"
  # - Returns 0 on successful login, 1 if cluster not found or login fails
  #
  # Arguments:
  #   cluster - Name of the cluster to look up in CHIEF_OC_CLUSTERS
  #   auth_method - Authentication method (must be "user" for local clusters)
  #   tls_option - TLS option string for oc login command
  
  local cluster="$1"
  local auth_method="$2"
  local tls_option="$3"

  if [[ -z "${CHIEF_OC_CLUSTERS[$cluster]}" ]]; then
    __print_warn "No local cluster definition found for: $cluster"
    return 1
  fi

  if [[ "$auth_method" != "user" ]]; then
    __print_error "Local clusters only support user authentication (not -kc or -ka)"
    return 1
  fi

  __print_info "Using local cluster definition for: $cluster"
  
  local api_url username password
  IFS=',' read -r api_url username password <<< "${CHIEF_OC_CLUSTERS[$cluster]}"
  
  if [[ -z "$api_url" || -z "$username" ]]; then
    __print_error "Incomplete cluster definition for: $cluster"
    return 1
  fi

  __print_info "Logging in as $username to $api_url..."
  if [[ -n "$password" ]]; then
    oc login -u "$username" -p "$password" --server="$api_url" $tls_option
  else
    oc login -u "$username" --server="$api_url" $tls_option
  fi

  if [[ $? -eq 0 ]]; then
    __print_success "Logged in as: $(oc whoami) - Console: $(oc whoami --show-console 2>/dev/null || echo 'N/A')"
    return 0
  else
    __print_error "Local cluster login failed"
    return 1
  fi
}

# Helper function to attempt environment variable login
function __oc_try_env_login() {
  # Usage: __oc_try_env_login <cluster> <auth_method> <tls_option>
  # 
  # Developer usage: Fallback authentication using only environment variables
  # - Currently returns failure as it lacks API URL information
  # - Only supports "user" authentication method
  # - Requires CHIEF_OC_USERNAME to be set
  # - This is a placeholder for future enhancement or legacy support
  # - Always returns 1 (failure) in current implementation
  #
  # Arguments:
  #   cluster - Name of the cluster (used for error messages only)
  #   auth_method - Authentication method (must be "user")
  #   tls_option - TLS option string (not used in current implementation)
  
  local cluster="$1"
  local auth_method="$2"
  local tls_option="$3"

  if [[ "$auth_method" != "user" ]]; then
    __print_error "Environment variable authentication only supports user mode"
    return 1
  fi

  if [[ -z "$CHIEF_OC_USERNAME" ]]; then
    __print_error "CHIEF_OC_USERNAME not set for fallback authentication"
    __print_info "Try using explicit Vault authentication instead:"
    __print_info "  chief.oc.login $cluster -kc  (kubeconfig from Vault)"
    __print_info "  chief.oc.login $cluster -ka  (kubeadmin from Vault)"
    return 1
  fi

  __print_warn "Using fallback environment variable authentication"
  __print_error "No API URL available for cluster: $cluster"
  return 1
}