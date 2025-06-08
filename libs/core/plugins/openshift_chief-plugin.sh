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

function chief.oc.login() {
  local USAGE="Usage: $FUNCNAME <host> [-kc (kubeconfig login)] [-ka (kubeadmin)] [-i (for no tls)]

Login to an OpenShift cluster using kubeconfig, kubeadmin or user credentials.

This function requires:
  - Hashicorp 'vault' CLI tool to be installed and configured with VAULT_ADDR and VAULT_TOKEN environment variables.
  - 'oc' CLI tool to be installed and configured in your PATH.
  - CHIEF_VAULT_OC_PATH environment variable set to the path where your Vault secrets are stored.
      For example: 'secrets/openshift', all hosts should be under this path.
  - A Vault server with the following secrets structure:
    - 'secrets/openshift/<host>' containing:
      - kubeconfig : kubeconfig file content
      - kubeadmin : kubeadmin password
      - api : API url of Openshift cluster

Optional Environment Variables:
  - CHIEF_OC_USERNAME : Username for OpenShift login (if not using kubeconfig or kubeadmin).
  - CHIEF_OC_PASSWORD : Password for OpenShift login (if not using kubeconfig or kubeadmin).

Options:
  -kc : Use kubeconfig to login.
  -ka : Use kubeadmin credentials to login.
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

  if [[ -z $1 || $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  # Check if required environment variables and binaries are set
  if ! type oc >/dev/null 2>&1; then
    echo "Error: 'oc' CLI tool is not installed or not in your PATH."
    echo "Please install the OpenShift CLI tool (oc) to use this function."
    return
  fi

  if ! type vault >/dev/null 2>&1; then
    echo "Error: 'vault' CLI tool is not installed or not in your PATH."
    echo "Please install the Hashicorp Vault CLI tool to use this function."
    return
  fi

  if ! vault kv get ${CHIEF_VAULT_OC_PATH}/${cluster} >/dev/null 2>&1; then
    echo "Secret for ${cluster} does not exist in Vault at ${CHIEF_VAULT_OC_PATH}/${cluster}."
    return
  fi

  if [[ -z ${VAULT_ADDR} && -z ${VAULT_TOKEN} ]]; then
    echo "Error: VAULT_ADDR and VAULT_TOKEN must be set to read credentials from Vault."
    return
  fi

  local url
  local tls_option=""
  local secret_keys=(
    "api"
    "kubeconfig"
    "kubeadmin"
  )

  # Loop through the secret keys and check if they exist in Vault
  for key in "${secret_keys[@]}"; do
    if ! vault kv get -field=${key} ${CHIEF_VAULT_OC_PATH}/${cluster} >/dev/null 2>&1; then
      echo "Error: '${key}' key not found in Vault at ${CHIEF_VAULT_OC_PATH}/${cluster}."
      if [[ ${key} == "kubeconfig" ]]; then
        echo "  If this is an HCP cluster, HCP clusters don't have kubeconfig, use -ka instead."
      fi
      return
    fi
  done

  for arg in "$@"; do
    if [[ "$arg" == "-i" ]]; then
      tls_option="--insecure-skip-tls-verify=true"
      break
    fi
  done

  url=$(vault kv get -field=api ${CHIEF_VAULT_OC_PATH}/${cluster})

  echo "Logging in to OpenShift cluster '${cluster}' at '${url}'..."
  echo "Using Vault path: ${CHIEF_VAULT_OC_PATH}/${cluster}"
  echo "Using tls_option: ${tls_option:-none}" 
  echo ""

  # Logon using kubeconfig
  if [[ ${2} == "-kc" ]]; then
    local kubeconfig=$(vault kv get -field=kubeconfig ${CHIEF_VAULT_OC_PATH}/${cluster})
    if [[ -z "${kubeconfig}" ]]; then
      echo "Error: kubeconfig not found in Vault."
      return
    fi
    rm -rf /tmp/kubeconfig
    echo "${kubeconfig}" > /tmp/kubeconfig
    export KUBECONFIG=/tmp/kubeconfig
    echo "KUBECONFIG set to /tmp/kubeconfig"

  # Logon using kubeadmin
  elif [[ ${2} == "-ka" ]]; then
    local kubepass=$(vault kv get -field=kubeadmin ${CHIEF_VAULT_OC_PATH}/${cluster})
    if [[ -z "${kubepass}" ]]; then
      echo "Error: kubeadmin password not found in Vault."
      echo "  If this is an HCP cluster, HCP clusters don't have kubeadmin, use -kc instead."
      return
    fi
    oc login -u "kubeadmin" -p "${kubepass}" "${url}" ${tls_option}

  else
    # Logon using user credentials
    if [[ -z "${CHIEF_OC_USERNAME}" ]]; then
      echo "Error: CHIEF_OC_USERNAME must be set (exported). Optionally, CHIEF_OC_PASSWORD can be set as well."
      return
    fi
    if [[ -n "${CHIEF_OC_PASSWORD}" ]]; then
      oc login -u "${CHIEF_OC_USERNAME}" -p "${CHIEF_OC_PASSWORD}" --server="${url}" ${tls_option}
    else
      oc login -u "${CHIEF_OC_USERNAME}" --server="${url}" ${tls_option}
    fi
  fi

  echo ""
  echo "Currently logged in as user: $(oc whoami) - Console: $(oc whoami --show-console)"
}