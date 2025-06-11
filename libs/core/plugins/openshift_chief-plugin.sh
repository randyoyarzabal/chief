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

# Repeated from Chief core library to avoid dependency on core library for this plugin.
# Color codes for printing messages
CHIEF_COLOR_RED='\033[0;31m'
CHIEF_COLOR_BLUE='\033[0;34m'
CHIEF_COLOR_CYAN='\033[0;36m'
CHIEF_COLOR_GREEN='\033[0;32m'
CHIEF_COLOR_YELLOW='\033[1;33m'
CHIEF_NO_COLOR='\033[0m' # Reset color/style

function __print_error(){
  echo -e "${CHIEF_COLOR_RED}Error: $1${CHIEF_NO_COLOR}"
}

function __print_warn(){
  echo -e "${CHIEF_COLOR_YELLOW}Warning: $1${CHIEF_NO_COLOR}"
}

function __print_success(){
  echo -e "${CHIEF_COLOR_GREEN}$1${CHIEF_NO_COLOR}"
}

function __print_info(){
  echo -e "${CHIEF_COLOR_CYAN}$1${CHIEF_NO_COLOR}"
}

function chief.oc.login() {
  local USAGE="Usage: $FUNCNAME <host> [-kc (kubeconfig login)] [-ka (kubeadmin)] [-i (for no tls)]

Login to an OpenShift cluster using kubeconfig, kubeadmin or user credentials.

OpenShift CLI tool (oc) is required to be installed and available in your PATH.

This function requires either option below or both (will try both in order):

  - CHIEF_OC_CLUSTERS environment variable to be set with cluster information in the format:
    CHIEF_OC_CLUSTERS['<cluster_name>']=<api_url>,<username>,<password>
    Example:

    declare -gA CHIEF_OC_CLUSTERS
    CHIEF_OC_CLUSTERS['hub']='https://api.hub.example.com,admin,password123'
    CHIEF_OC_CLUSTERS['tenant']='https://api.tenant.example.com,admin,password123'
    ...

    This allows you to login without using Vault.

  Or:

  - CHIEF_VAULT_OC_PATH environment variable to be set with the path where your OpenShift secrets are stored in Vault.
    Example: export CHIEF_VAULT_OC_PATH='secrets/openshift'
    This allows you to login using Vault secrets.
    Requirements:
      - Vault server to be running and accessible.
      - VAULT_ADDR and VAULT_TOKEN environment variables to be set for Vault access.
      - Vault secrets structure:
        - 'secrets/openshift/<host>' containing:
          - kubeconfig : kubeconfig file content
          - kubeadmin : kubeadmin password
          - api : API url of Openshift cluster

  Requirements for this function:
    - Hashicorp Vault CLI tool (vault) to be installed and configured with VAULT_ADDR and VAULT_TOKEN environment variables.

Optional Environment Variables:
  - CHIEF_OC_USERNAME : Username for OpenShift login (if not using kubeconfig or kubeadmin).
  - CHIEF_OC_PASSWORD : Password for OpenShift login (if not using kubeconfig or kubeadmin).

Options:
  -kc : Use kubeconfig to login. 
  -ka : Use kubeadmin credentials to login. 
  Note: -kc or -ka will not work if cluster is set in CHIEF_OC_CLUSTERS list.
  -i  : Skip TLS verification (insecure).

Examples: 
  Login with kubeconfig:
    $> oc.login hub_cluster -kc
  Login as kubeadmin:
    $> oc.login hub_cluster -ka
  Login as user (CHIEF_OC_USERNAME):
    $> oc.login hub_cluster
  Optionally pass -i to skip TLS verification:
    $> oc.login hub_cluster -i
    $> oc.login hub_cluster -ka -i  
"
  local cluster=$1
  local api_url
  local username
  local password
  local tls_option=""

  if [[ -z $1 || $1 == "-?" ]]; then
    echo "${USAGE}"
    return 0
  fi

  for arg in "$@"; do
    if [[ "$arg" == "-i" ]]; then
      tls_option="--insecure-skip-tls-verify=true"
      break
    fi
  done

  # Check if required environment variables and binaries are set
  if ! type oc >/dev/null 2>&1; then
    __print_error "Error: 'oc' CLI tool is not installed or not in your PATH."
    __print_info "Please install the OpenShift CLI tool (oc) to use this function."
    return 1
  fi

  # If CHIEF_OC_CLUSTERS is set, use it to get the cluster information
  local vault_fallback=false
  if [[ -n ${CHIEF_OC_CLUSTERS[$cluster]} ]]; then
    IFS=',' read -r api_url username password <<< "${CHIEF_OC_CLUSTERS[$cluster]}"
    if [[ -z ${api_url} || -z ${username} ]]; then # Password can be empty
      __print_error "Error: Cluster information for '${cluster}' is incomplete in CHIEF_OC_CLUSTERS."
      vault_fallback=true
    else
      # Do not allow use of -kc or -ka options if CHIEF_OC_CLUSTERS is used
      if [[ ${2} == "-kc" || ${2} == "-ka" ]]; then
        __print_error "Error: Cannot use -kc or -ka options when cluster is defined in CHIEF_OC_CLUSTERS."
        return 1
      fi
    fi
    if ! $vault_fallback; then
      __print_info "Logging in to OpenShift cluster '${cluster}' at '${api_url}' with credentials from CHIEF_OC_CLUSTERS."

      if [[ -z $password ]]; then
        __print_warn "Warning: Password is empty for user '${username}' in CHIEF_OC_CLUSTERS. Using passwordless login."
        oc login -u "${username}" --server="${api_url}" ${tls_option}
      else
        __print_info "Using user: ${username} and password: [REDACTED]"
        oc login -u "${username}" -p "${password}" --server="${api_url}" ${tls_option}
      fi
      echo ""
      __print_success "Currently logged in as user: $(oc whoami) - Console: $(oc whoami --show-console)"
      return 0
    fi
  else
    __print_warn "Warning: No cluster information found for '${cluster}' in CHIEF_OC_CLUSTERS, falling back to Vault."
  fi

  # Use Vault to retrieve cluster information
  if ! type vault >/dev/null 2>&1; then
    __print_error "Error: 'vault' CLI tool is not installed or not in your PATH."
    __print_info "Please install the Hashicorp Vault CLI tool to use this function."
    return 1
  fi

  # Ensure VAULT_ADDR and VAULT_TOKEN are set
  if [[ -z ${VAULT_ADDR} || -z ${VAULT_TOKEN} ]]; then
    __print_error "Error: VAULT_ADDR and VAULT_TOKEN environment variables must be set."
    __print_info "Please set them to connect to your Vault server."
    return 1
  fi

  # Ensure CHIEF_VAULT_OC_PATH is set
  if [[ -z ${CHIEF_VAULT_OC_PATH} ]]; then
    __print_error "Error: CHIEF_VAULT_OC_PATH environment variable is not set."
    __print_info "Please set CHIEF_VAULT_OC_PATH to the path where your OpenShift secrets are stored in Vault."
    __print_info "Example: export CHIEF_VAULT_OC_PATH='secrets/openshift'"
    return 1
  fi

  # Check if the cluster secret exists in Vault
  if ! vault kv get ${CHIEF_VAULT_OC_PATH}/${cluster} >/dev/null 2>&1; then
    __print_error "Secret for ${cluster} does not exist in Vault at ${CHIEF_VAULT_OC_PATH}/${cluster}."
    return 1
  fi

  local secret_keys=(
    "api"
    "kubeconfig"
    "kubeadmin"
  )

  # Loop through the secret keys and check if they exist in Vault
  for key in "${secret_keys[@]}"; do
    if ! vault kv get -field=${key} ${CHIEF_VAULT_OC_PATH}/${cluster} >/dev/null 2>&1; then
      __print_error "Error: '${key}' key not found in Vault at ${CHIEF_VAULT_OC_PATH}/${cluster}."
      if [[ ${key} == "kubeconfig" ]]; then
        __print_info "  If this is an HCP cluster, HCP clusters don't have kubeconfig, use -ka instead."
      fi
      return 1
    fi
  done

  api_url=$(vault kv get -field=api ${CHIEF_VAULT_OC_PATH}/${cluster})

  __print_info "Logging in to OpenShift cluster '${cluster}' at '${api_url}'..."
  __print_info "Using tls_option: ${tls_option:-none}" 
  __print_info "Using Vault path: ${CHIEF_VAULT_OC_PATH}/${cluster}"

  echo ""

  # Logon using kubeconfig
  if [[ ${2} == "-kc" ]]; then
    __print_info "Logging in with kubeconfig credentials..."
    local kubeconfig=$(vault kv get -field=kubeconfig ${CHIEF_VAULT_OC_PATH}/${cluster})
    if [[ -z "${kubeconfig}" ]]; then
      __print_error "Error: kubeconfig not found in Vault."
      return 1
    fi
    rm -rf /tmp/kubeconfig
    echo "${kubeconfig}" > /tmp/kubeconfig
    export KUBECONFIG=/tmp/kubeconfig
    echo "KUBECONFIG set to /tmp/kubeconfig"

  # Logon using kubeadmin
  elif [[ ${2} == "-ka" ]]; then
    __print_info "Logging in with user (kubeadmin, kubeadmin password) credentials..."
    local kubepass=$(vault kv get -field=kubeadmin ${CHIEF_VAULT_OC_PATH}/${cluster})
    if [[ -z "${kubepass}" ]]; then
      __print_error "Error: kubeadmin password not found in Vault."
      __print_info "  If this is an HCP cluster, HCP clusters don't have kubeadmin, use -kc instead."
      return 1
    fi
    oc login -u "kubeadmin" -p "${kubepass}" "${api_url}" ${tls_option}
  else
    # Logon using user credentials
    __print_info "Logging in with user (CHIEF_OC_USERNAME, CHIEF_OC_PASSWORD) credentials..."
    if [[ -z "${CHIEF_OC_USERNAME}" ]]; then
      __print_error "Error: CHIEF_OC_USERNAME must be set (exported). Optionally, CHIEF_OC_PASSWORD can be set as well."
      return 1
    fi
    if [[ -n "${CHIEF_OC_PASSWORD}" ]]; then
      __print_info "Using CHIEF_OC_USERNAME: ${CHIEF_OC_USERNAME} and CHIEF_OC_PASSWORD: [REDACTED]"
      oc login -u "${CHIEF_OC_USERNAME}" -p "${CHIEF_OC_PASSWORD}" --server="${api_url}" ${tls_option}
    else
      __print_warn "Warning: Password is empty for user '${CHIEF_OC_USERNAME}' in CHIEF_OC_CLUSTERS. Using passwordless login."
      oc login -u "${CHIEF_OC_USERNAME}" --server="${api_url}" ${tls_option}
    fi
  fi

  echo ""
  __print_success "Currently logged in as user: $(oc whoami) - Console: $(oc whoami --show-console)"
}