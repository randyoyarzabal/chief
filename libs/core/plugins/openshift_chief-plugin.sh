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

# Chief Plugin File: openshift_chief-plugin.sh
# Author: Randy E. Oyarzabal
# Functions and aliases that are Openshift related.

# Block interactive execution
if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "Error: $0 (Chief plugin) must be sourced; not executed interactively."
  exit 1
fi

# Note: Uses __chief_print_* functions from Chief core library for consistent messaging

# Helper function to check OpenShift login status and display cluster info
__chief_oc_check_login() {
  if ! oc whoami &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Not logged into OpenShift cluster"
    echo -e "${CHIEF_COLOR_YELLOW}Hint:${CHIEF_NO_COLOR} Run 'oc login' or 'chief.oc_login' to authenticate"
    return 1
  fi

  # Display current cluster information
  local current_user current_server current_context
  current_user=$(oc whoami 2>/dev/null)
  current_server=$(oc whoami --show-server 2>/dev/null)
  current_context=$(oc config current-context 2>/dev/null)
  
  echo -e "${CHIEF_SYMBOL_CHECK} Connected to OpenShift:"
  echo -e "${CHIEF_COLOR_BLUE}  User:${CHIEF_NO_COLOR} $current_user"
  echo -e "${CHIEF_COLOR_BLUE}  Server:${CHIEF_NO_COLOR} $current_server"
  echo -e "${CHIEF_COLOR_BLUE}  Context:${CHIEF_NO_COLOR} $current_context"
  echo ""
  return 0
}

function chief.oc_get-all-objects() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <namespace> [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Get all objects in an OpenShift namespace by discovering and listing all available
API resources that can be queried. Excludes events to reduce noise.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  namespace       Target namespace to scan for objects

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -o, --output FORMAT    Output format (table, yaml, json, wide) [default: table]
  -l, --selector LABEL   Label selector to filter objects
  -f, --field SELECTOR   Field selector to filter objects
  -q, --quiet           Suppress resource type headers
  -?                    Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Automatically discovers all listable namespaced resources
- Filters out event resources to reduce output noise
- Supports standard kubectl output formats
- Provides comprehensive namespace inventory
- Handles missing or empty resources gracefully

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- OpenShift CLI (oc) must be installed and available in PATH
- User must be logged into OpenShift cluster
- User must have list permissions for the target namespace

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME myapp                           # List all objects in 'myapp' namespace
  $FUNCNAME prod -o yaml                    # Get all objects in YAML format
  $FUNCNAME test -l app=frontend            # Filter by label selector
  $FUNCNAME dev -q                          # Quiet mode (no resource headers)
  $FUNCNAME staging --field status.phase=Running  # Filter by field selector

${CHIEF_COLOR_BLUE}Reference:${CHIEF_NO_COLOR}
Based on techniques shared by Kyle Walker from Red Hat.
"

  # Check if OpenShift CLI is available
  if ! command -v oc &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenShift CLI (oc) is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
    echo "  Or use package manager (brew install openshift-cli, etc.)"
    return 1
  fi

  local namespace=""
  local output_format="table"
  local label_selector=""
  local field_selector=""
  local quiet_mode=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -o|--output)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          output_format="$2"
          shift 2
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Output format is required"
          return 1
        fi
        ;;
      -l|--selector)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          label_selector="$2"
          shift 2
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Label selector is required"
          return 1
        fi
        ;;
      -f|--field)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          field_selector="$2"
          shift 2
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Field selector is required"
          return 1
        fi
        ;;
      -q|--quiet)
        quiet_mode=true
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
        if [[ -z "$namespace" ]]; then
          namespace="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Multiple namespaces specified. Only one namespace allowed."
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$namespace" ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Namespace is required"
    echo -e "${USAGE}"
    return 1
  fi

  # Check OpenShift login status and display cluster info
  if ! __chief_oc_check_login; then
    return 1
  fi

  # Check if namespace exists
  if ! oc get namespace "$namespace" &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Namespace '$namespace' not found or not accessible"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Scanning namespace:${CHIEF_NO_COLOR} $namespace"
  [[ -n "$label_selector" ]] && echo -e "${CHIEF_COLOR_BLUE}Label selector:${CHIEF_NO_COLOR} $label_selector"
  [[ -n "$field_selector" ]] && echo -e "${CHIEF_COLOR_BLUE}Field selector:${CHIEF_NO_COLOR} $field_selector"
  echo -e "${CHIEF_COLOR_BLUE}Output format:${CHIEF_NO_COLOR} $output_format"
  echo ""

  # Build oc command options
  local oc_options="-n $namespace --ignore-not-found -o $output_format"
  [[ -n "$label_selector" ]] && oc_options+=" -l $label_selector"
  [[ -n "$field_selector" ]] && oc_options+=" --field-selector $field_selector"

  # Get all namespaced API resources (excluding events)
  local resources
  resources=$(oc api-resources --verbs=list --namespaced -o name 2>/dev/null | \
    grep -v "events.events.k8s.io" | grep -v "^events$" | sort | uniq)

  if [[ -z "$resources" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Warning:${CHIEF_NO_COLOR} No listable resources found"
    return 0
  fi

  local resource_count=0
  local found_objects=false

  # Iterate through each resource type
  for resource in $resources; do
    # Get objects for this resource type
    local objects
    objects=$(oc get $oc_options "$resource" 2>/dev/null)
    
    # Check if any objects were found (more than just header line)
    if [[ $(echo "$objects" | wc -l) -gt 1 ]]; then
      found_objects=true
      ((resource_count++))
      
      if [[ "$quiet_mode" != true ]]; then
        echo -e "${CHIEF_COLOR_CYAN}=== Resource: ${resource} ===${CHIEF_NO_COLOR}"
      fi
      echo "$objects"
      echo ""
    fi
  done

  if [[ "$found_objects" != true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}No objects found in namespace '$namespace'${CHIEF_NO_COLOR}"
    [[ -n "$label_selector" ]] && echo -e "${CHIEF_COLOR_YELLOW}(with label selector: $label_selector)${CHIEF_NO_COLOR}"
    [[ -n "$field_selector" ]] && echo -e "${CHIEF_COLOR_YELLOW}(with field selector: $field_selector)${CHIEF_NO_COLOR}"
  else
    echo -e "${CHIEF_SYMBOL_CHECK} Scan complete: Found objects in ${resource_count} resource types"
  fi
}

function chief.oc_clean-olm() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Clean up OpenShift Operator Lifecycle Manager (OLM) pods and jobs to start fresh
when dealing with operator installation or update issues. This forces OLM to
recreate its components and can resolve stuck operator states.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -y, --yes       Skip confirmation prompts
  -n, --dry-run   Show what would be deleted without making changes
  -f, --force     Force deletion even if pods are in Running state
  -s, --selective TARGET  Clean only specific component:
                          marketplace, lifecycle-manager, or catalog
  -?              Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Cleans OLM marketplace jobs and pods
- Cleans OLM lifecycle manager pods
- Interactive confirmation by default
- Dry-run mode for safety
- Selective cleanup options
- Comprehensive error handling

${CHIEF_COLOR_MAGENTA}Components Cleaned:${CHIEF_NO_COLOR}
- openshift-marketplace namespace: jobs and pods
- openshift-operator-lifecycle-manager namespace: pods
- Catalog source pods and related resources

${CHIEF_COLOR_RED}${CHIEF_SYMBOL_WARNING}  Warning:${CHIEF_NO_COLOR}
This operation will temporarily disrupt operator management. OLM will recreate
these components automatically, but operator installations/updates in progress
may be interrupted. Use with caution in production environments.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                           # Interactive cleanup of all OLM components
  $FUNCNAME -y                        # Non-interactive cleanup
  $FUNCNAME -n                        # Dry-run: show what would be deleted
  $FUNCNAME -s marketplace            # Clean only marketplace components
  $FUNCNAME -s lifecycle-manager      # Clean only lifecycle manager components
  $FUNCNAME -f -y                     # Force cleanup without confirmation

${CHIEF_COLOR_BLUE}Reference:${CHIEF_NO_COLOR}
Based on techniques shared by Kyle Walker from Red Hat.
"

  # Check if OpenShift CLI is available
  if ! command -v oc &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenShift CLI (oc) is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
    echo "  Or use package manager (brew install openshift-cli, etc.)"
    return 1
  fi

  local auto_yes=false
  local dry_run=false
  local force_delete=false
  local selective_target=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -y|--yes)
        auto_yes=true
        shift
        ;;
      -n|--dry-run)
        dry_run=true
        shift
        ;;
      -f|--force)
        force_delete=true
        shift
        ;;
      -s|--selective)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          case "$2" in
            marketplace|lifecycle-manager|catalog)
              selective_target="$2"
              shift 2
              ;;
            *)
              echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Invalid selective target: $2"
              echo -e "${CHIEF_COLOR_YELLOW}Valid targets:${CHIEF_NO_COLOR} marketplace, lifecycle-manager, catalog"
              return 1
              ;;
          esac
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Selective target is required"
          return 1
        fi
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
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Unexpected argument: $1"
        echo -e "${USAGE}"
        return 1
        ;;
    esac
  done

  # Check OpenShift login status and display cluster info
  if ! __chief_oc_check_login; then
    return 1
  fi

  # Check cluster-admin permissions (OLM cleanup requires elevated privileges)
  if ! oc auth can-i delete pods -n openshift-marketplace &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Insufficient permissions to clean OLM components"
    echo -e "${CHIEF_COLOR_YELLOW}Required:${CHIEF_NO_COLOR} cluster-admin or equivalent permissions"
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}OpenShift OLM Cleanup${CHIEF_NO_COLOR}"
  
  # Build mode display
  local mode_display=""
  [[ "$dry_run" == true ]] && mode_display+="DRY-RUN "
  [[ "$force_delete" == true ]] && mode_display+="FORCE "
  [[ -n "$selective_target" ]] && mode_display+="SELECTIVE ($selective_target) "
  
  # Trim trailing space and set default if empty
  mode_display="${mode_display% }"
  [[ -z "$mode_display" ]] && mode_display="LIVE"
  
  echo -e "${CHIEF_COLOR_BLUE}Mode:${CHIEF_NO_COLOR} $mode_display"
  echo ""

  # Function to get resources for deletion
  __chief_get_olm_resources() {
    local namespace="$1"
    local resource_type="$2"
    local resources
    
    resources=$(oc get "$resource_type" -n "$namespace" -o name 2>/dev/null | grep -v "^No resources found")
    echo "$resources"
  }

  # Function to delete resources
  __chief_delete_olm_resources() {
    local namespace="$1"
    local resource_type="$2"
    local resources="$3"
    local force_flag=""
    
    if [[ "$force_delete" == true ]]; then
      force_flag="--force --grace-period=0"
    fi
    
    if [[ -n "$resources" ]]; then
      echo -e "${CHIEF_COLOR_CYAN}Deleting ${resource_type} in ${namespace}:${CHIEF_NO_COLOR}"
      echo "$resources" | while read -r resource; do
        [[ -n "$resource" ]] && echo "  - $resource"
      done
      
      if [[ "$dry_run" != true ]]; then
        echo "$resources" | xargs -r oc delete -n "$namespace" $force_flag 2>/dev/null || true
        echo -e "${CHIEF_SYMBOL_CHECK} ${resource_type} deletion completed"
      else
        echo -e "${CHIEF_COLOR_YELLOW}[DRY-RUN] Would delete above ${resource_type}${CHIEF_NO_COLOR}"
      fi
      echo ""
    else
      echo -e "${CHIEF_COLOR_YELLOW}No ${resource_type} found in ${namespace}${CHIEF_NO_COLOR}"
      echo ""
    fi
  }

  # Confirm operation unless auto-yes or dry-run
  if [[ "$auto_yes" != true && "$dry_run" != true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}${CHIEF_SYMBOL_WARNING}  This will delete OLM pods and jobs. OLM will recreate them automatically.${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_YELLOW}   Operator installations/updates in progress may be interrupted.${CHIEF_NO_COLOR}"
    echo ""
    echo -e "${CHIEF_COLOR_BLUE}Target cluster:${CHIEF_NO_COLOR} $(oc whoami --show-server 2>/dev/null)"
    echo -e "${CHIEF_COLOR_BLUE}Logged in as:${CHIEF_NO_COLOR} $(oc whoami 2>/dev/null)"
    echo ""
    read -p "Continue with OLM cleanup? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled${CHIEF_NO_COLOR}"
      return 0
    fi
    echo ""
  fi

  # Perform selective or full cleanup
  case "$selective_target" in
    "marketplace")
      echo -e "${CHIEF_COLOR_MAGENTA}=== Cleaning openshift-marketplace ===${CHIEF_NO_COLOR}"
      marketplace_jobs=$(__chief_get_olm_resources "openshift-marketplace" "job")
      marketplace_pods=$(__chief_get_olm_resources "openshift-marketplace" "pod")
      __chief_delete_olm_resources "openshift-marketplace" "jobs" "$marketplace_jobs"
      __chief_delete_olm_resources "openshift-marketplace" "pods" "$marketplace_pods"
      ;;
    "lifecycle-manager")
      echo -e "${CHIEF_COLOR_MAGENTA}=== Cleaning openshift-operator-lifecycle-manager ===${CHIEF_NO_COLOR}"
      olm_pods=$(__chief_get_olm_resources "openshift-operator-lifecycle-manager" "pod")
      __chief_delete_olm_resources "openshift-operator-lifecycle-manager" "pods" "$olm_pods"
      ;;
    "catalog")
      echo -e "${CHIEF_COLOR_MAGENTA}=== Cleaning catalog sources ===${CHIEF_NO_COLOR}"
      # Clean catalog source pods specifically
      catalog_pods=$(oc get pods -A -l "olm.catalogSource" -o name 2>/dev/null)
      if [[ -n "$catalog_pods" ]]; then
        echo -e "${CHIEF_COLOR_CYAN}Deleting catalog source pods:${CHIEF_NO_COLOR}"
        echo "$catalog_pods" | while read -r pod; do
          [[ -n "$pod" ]] && echo "  - $pod"
        done
        if [[ "$dry_run" != true ]]; then
          echo "$catalog_pods" | xargs -r oc delete --ignore-not-found ${force_delete:+--force --grace-period=0} 2>/dev/null || true
          echo -e "${CHIEF_COLOR_GREEN}✓ Catalog source pods deletion completed${CHIEF_NO_COLOR}"
        else
          echo -e "${CHIEF_COLOR_YELLOW}[DRY-RUN] Would delete above catalog pods${CHIEF_NO_COLOR}"
        fi
      else
        echo -e "${CHIEF_COLOR_YELLOW}No catalog source pods found${CHIEF_NO_COLOR}"
      fi
      ;;
    *)
      # Full cleanup
      echo -e "${CHIEF_COLOR_MAGENTA}=== Cleaning openshift-marketplace ===${CHIEF_NO_COLOR}"
      marketplace_jobs=$(__chief_get_olm_resources "openshift-marketplace" "job")
      marketplace_pods=$(__chief_get_olm_resources "openshift-marketplace" "pod")
      __chief_delete_olm_resources "openshift-marketplace" "jobs" "$marketplace_jobs"
      __chief_delete_olm_resources "openshift-marketplace" "pods" "$marketplace_pods"
      
      echo -e "${CHIEF_COLOR_MAGENTA}=== Cleaning openshift-operator-lifecycle-manager ===${CHIEF_NO_COLOR}"
      olm_pods=$(__chief_get_olm_resources "openshift-operator-lifecycle-manager" "pod")
      __chief_delete_olm_resources "openshift-operator-lifecycle-manager" "pods" "$olm_pods"
      ;;
  esac

  if [[ "$dry_run" != true ]]; then
    echo -e "${CHIEF_COLOR_GREEN}✅ OLM cleanup completed${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_BLUE}Note:${CHIEF_NO_COLOR} OLM will automatically recreate deleted components"
    echo -e "${CHIEF_COLOR_BLUE}Monitor:${CHIEF_NO_COLOR} Watch 'oc get pods -n openshift-marketplace' and 'oc get pods -n openshift-operator-lifecycle-manager'"
  else
    echo -e "${CHIEF_COLOR_YELLOW}[DRY-RUN] OLM cleanup simulation completed${CHIEF_NO_COLOR}"
  fi
}

function chief.oc_clean-replicasets() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options] [namespace]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Clean up old and stale ReplicaSets with zero replicas. These ReplicaSets are
typically left behind after deployments and consume resources unnecessarily.
This function identifies and removes ReplicaSets that have 0 replicas configured.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  namespace       Target namespace to clean (optional, defaults to current namespace)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -a, --all-namespaces  Clean ReplicaSets across all accessible namespaces
  -y, --yes            Skip confirmation prompts
  -n, --dry-run        Show what would be deleted without making changes
  -f, --force          Force deletion even if ReplicaSets have pods
  -l, --selector LABEL  Label selector to filter ReplicaSets
  -o, --older-than DURATION  Only delete ReplicaSets older than duration (e.g., 7d, 2w, 1m)
  -?                   Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Identifies ReplicaSets with zero replicas
- Interactive confirmation by default
- Supports namespace filtering and label selectors
- Age-based filtering for selective cleanup
- Dry-run mode for safety
- Cross-namespace cleanup option

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- OpenShift CLI (oc) must be installed and available in PATH
- jq must be installed for JSON processing
- User must be logged into OpenShift cluster
- User must have delete permissions for ReplicaSets in target namespace(s)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                           # Clean zero-replica ReplicaSets in current namespace
  $FUNCNAME myapp                     # Clean zero-replica ReplicaSets in 'myapp' namespace
  $FUNCNAME -a                        # Clean across all accessible namespaces
  $FUNCNAME -n                        # Dry-run: show what would be deleted
  $FUNCNAME -l app=frontend           # Clean only ReplicaSets with app=frontend label
  $FUNCNAME --older-than 7d -y        # Auto-delete ReplicaSets older than 7 days
  $FUNCNAME prod -f                   # Force delete in production namespace

${CHIEF_COLOR_BLUE}Reference:${CHIEF_NO_COLOR}
Based on techniques shared by Kyle Walker from Red Hat.
"

  # Check if OpenShift CLI is available
  if ! command -v oc &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenShift CLI (oc) is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
    echo "  Or use package manager (brew install openshift-cli, etc.)"
    return 1
  fi

  # Check if jq is available
  if ! command -v jq &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} jq is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  macOS: brew install jq"
    echo "  Linux: Use your package manager (apt install jq, yum install jq, etc.)"
    return 1
  fi

  local namespace=""
  local all_namespaces=false
  local auto_yes=false
  local dry_run=false
  local force_delete=false
  local label_selector=""
  local older_than=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -a|--all-namespaces)
        all_namespaces=true
        shift
        ;;
      -y|--yes)
        auto_yes=true
        shift
        ;;
      -n|--dry-run)
        dry_run=true
        shift
        ;;
      -f|--force)
        force_delete=true
        shift
        ;;
      -l|--selector)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          label_selector="$2"
          shift 2
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Label selector is required"
          return 1
        fi
        ;;
      -o|--older-than)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          older_than="$2"
          shift 2
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Duration is required"
          return 1
        fi
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
        if [[ -z "$namespace" ]]; then
          namespace="$1"
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Multiple namespaces specified. Only one namespace allowed."
          echo -e "${USAGE}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Check OpenShift login status and display cluster info
  if ! __chief_oc_check_login; then
    return 1
  fi

  # Validate namespace if specified
  if [[ -n "$namespace" && "$all_namespaces" != true ]]; then
    if ! oc get namespace "$namespace" &>/dev/null; then
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Namespace '$namespace' not found or not accessible"
      return 1
    fi
  fi

  echo -e "${CHIEF_COLOR_BLUE}OpenShift ReplicaSet Cleanup${CHIEF_NO_COLOR}"
  # Build target display
  local target_display=""
  if [[ "$all_namespaces" == true ]]; then
    target_display="All namespaces"
  elif [[ -n "$namespace" ]]; then
    target_display="Namespace: $namespace"
  else
    target_display="Current namespace"
  fi
  
  echo -e "${CHIEF_COLOR_BLUE}Target:${CHIEF_NO_COLOR} $target_display"
  [[ -n "$label_selector" ]] && echo -e "${CHIEF_COLOR_BLUE}Label selector:${CHIEF_NO_COLOR} $label_selector"
  [[ -n "$older_than" ]] && echo -e "${CHIEF_COLOR_BLUE}Age filter:${CHIEF_NO_COLOR} Older than $older_than"
  
  # Build mode display
  local mode_display=""
  [[ "$dry_run" == true ]] && mode_display+="DRY-RUN "
  [[ "$force_delete" == true ]] && mode_display+="FORCE "
  
  # Trim trailing space and set default if empty
  mode_display="${mode_display% }"
  [[ -z "$mode_display" ]] && mode_display="LIVE"
  
  echo -e "${CHIEF_COLOR_BLUE}Mode:${CHIEF_NO_COLOR} $mode_display"
  echo ""

  # Build oc command for getting ReplicaSets
  local oc_get_cmd="oc get rs -o json"
  
  if [[ "$all_namespaces" == true ]]; then
    oc_get_cmd+=" --all-namespaces"
  elif [[ -n "$namespace" ]]; then
    oc_get_cmd+=" -n $namespace"
  fi
  
  [[ -n "$label_selector" ]] && oc_get_cmd+=" -l $label_selector"

  # Get zero-replica ReplicaSets
  local jq_filter='.items[] | select(.spec.replicas == 0)'
  
  # Add age filter if specified
  if [[ -n "$older_than" ]]; then
    # Convert duration to seconds for comparison
    local cutoff_seconds
    case "$older_than" in
      *d) cutoff_seconds=$((${older_than%d} * 86400)) ;;
      *w) cutoff_seconds=$((${older_than%w} * 604800)) ;;
      *m) cutoff_seconds=$((${older_than%m} * 2592000)) ;;
      *h) cutoff_seconds=$((${older_than%h} * 3600)) ;;
      *) 
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Invalid duration format: $older_than"
        echo -e "${CHIEF_COLOR_YELLOW}Use format:${CHIEF_NO_COLOR} 7d (days), 2w (weeks), 1m (months), 24h (hours)"
        return 1
        ;;
    esac
    
    local cutoff_date
    cutoff_date=$(date -u -d "@$(($(date +%s) - cutoff_seconds))" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                  date -u -r "$(($(date +%s) - cutoff_seconds))" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    
    if [[ -n "$cutoff_date" ]]; then
      jq_filter+=" | select(.metadata.creationTimestamp < \"$cutoff_date\")"
    fi
  fi

  # Get the ReplicaSets to delete
  local replicasets_json
  replicasets_json=$(eval "$oc_get_cmd" 2>/dev/null)
  
  if [[ $? -ne 0 ]]; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Failed to retrieve ReplicaSets"
    return 1
  fi

  local replicasets_to_delete
  replicasets_to_delete=$(echo "$replicasets_json" | jq -r "$jq_filter | \"\(.metadata.namespace // \"default\") \(.metadata.name)\"" 2>/dev/null)

  if [[ -z "$replicasets_to_delete" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}No zero-replica ReplicaSets found matching criteria${CHIEF_NO_COLOR}"
    return 0
  fi

  # Display ReplicaSets to be deleted
  echo -e "${CHIEF_COLOR_CYAN}Zero-replica ReplicaSets found:${CHIEF_NO_COLOR}"
  echo "$replicasets_to_delete" | while read -r ns_name; do
    [[ -n "$ns_name" ]] && echo "  - $ns_name"
  done
  echo ""

  # Count ReplicaSets
  local rs_count
  rs_count=$(echo "$replicasets_to_delete" | grep -c . 2>/dev/null)
  echo -e "${CHIEF_COLOR_BLUE}Total ReplicaSets to clean:${CHIEF_NO_COLOR} $rs_count"
  echo ""

  # Confirm operation unless auto-yes or dry-run
  if [[ "$auto_yes" != true && "$dry_run" != true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}${CHIEF_SYMBOL_WARNING}  This will delete the above ReplicaSets.${CHIEF_NO_COLOR}"
    echo ""
    echo -e "${CHIEF_COLOR_BLUE}Target cluster:${CHIEF_NO_COLOR} $(oc whoami --show-server 2>/dev/null)"
    echo -e "${CHIEF_COLOR_BLUE}Logged in as:${CHIEF_NO_COLOR} $(oc whoami 2>/dev/null)"
    echo ""
    read -p "Continue with ReplicaSet cleanup? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled${CHIEF_NO_COLOR}"
      return 0
    fi
    echo ""
  fi

  # Delete ReplicaSets
  if [[ "$dry_run" == true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}[DRY-RUN] Would delete the above ReplicaSets${CHIEF_NO_COLOR}"
  else
    local deleted_count=0
    local failed_count=0
    
    echo -e "${CHIEF_COLOR_CYAN}Deleting ReplicaSets...${CHIEF_NO_COLOR}"
    
    while read -r ns_name; do
      if [[ -n "$ns_name" ]]; then
        local namespace_part="${ns_name%% *}"
        local name_part="${ns_name#* }"
        
        # Build delete command
        local delete_cmd="oc delete rs"
        [[ "$all_namespaces" == true || -n "$namespace" ]] && delete_cmd+=" -n $namespace_part"
        delete_cmd+=" $name_part"
        [[ "$force_delete" == true ]] && delete_cmd+=" --force --grace-period=0"
        
        if eval "$delete_cmd" &>/dev/null; then
          echo -e "  ${CHIEF_SYMBOL_CHECK} $ns_name"
          ((deleted_count++))
        else
          echo -e "  ${CHIEF_SYMBOL_CROSS} $ns_name (failed)"
          ((failed_count++))
        fi
      fi
    done <<< "$replicasets_to_delete"
    
    echo ""
    if [[ $failed_count -eq 0 ]]; then
      echo -e "${CHIEF_COLOR_GREEN}✅ Successfully deleted $deleted_count ReplicaSets${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_YELLOW}⚠️  Deleted $deleted_count ReplicaSets, $failed_count failed${CHIEF_NO_COLOR}"
    fi
  fi
}


function chief.oc_approve-csrs() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Approve pending Certificate Signing Requests (CSRs) in OpenShift cluster.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -a, --all       Approve all pending CSRs without confirmation
  -l, --list      List pending CSRs without approving
  -f, --filter    PATTERN  Only approve CSRs matching pattern
  -n, --dry-run   Show what would be approved without making changes
  -?              Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Interactive approval by default (prompts for each CSR)
- Batch approval with --all flag
- Pattern filtering for selective approval
- Dry-run mode for safety
- Comprehensive error handling and validation

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- OpenShift CLI (oc) must be installed and available in PATH
- User must be logged into OpenShift cluster
- User must have cluster-admin or equivalent CSR approval permissions

${CHIEF_COLOR_RED}Security Warning:${CHIEF_NO_COLOR}
Approving CSRs grants certificates that provide cluster access. Only approve
CSRs from trusted sources. Review CSR details before approval in production.

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.oc_approve_csrs                          # Interactive approval of pending CSRs
  chief.oc_approve_csrs -l                       # List pending CSRs only
  chief.oc_approve_csrs -a                       # Approve all pending CSRs
  chief.oc_approve_csrs -n                       # Dry-run: show what would be approved
  chief.oc_approve_csrs -f \"node-\"               # Approve only node-related CSRs
  chief.oc_approve_csrs -f \"system:node\"         # Approve system node CSRs only
"

  # Check if OpenShift CLI is available
  if ! command -v oc &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenShift CLI (oc) is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
    echo "  Or use package manager (brew install openshift-cli, etc.)"
    return 1
  fi

  local approve_all=false
  local list_only=false
  local filter_pattern=""
  local dry_run=false

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      -a|--all)
        approve_all=true
        shift
        ;;
      -l|--list)
        list_only=true
        shift
        ;;
      -f|--filter)
        if [[ -n "$2" ]]; then
          filter_pattern="$2"
          shift 2
        else
          echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Filter pattern is required"
          echo -e "${USAGE}"
          return 1
        fi
        ;;
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
        echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} No positional arguments allowed"
        echo -e "${USAGE}"
        return 1
        ;;
    esac
  done

  # Check OpenShift login status and display cluster info
  if ! __chief_oc_check_login; then
    return 1
  fi

  echo -e "${CHIEF_COLOR_BLUE}Checking for pending CSRs...${CHIEF_NO_COLOR}"

  # Get pending CSRs
  local pending_csrs
  pending_csrs=$(oc get csr --no-headers 2>/dev/null | grep -i pending)

  if [[ -z "$pending_csrs" ]]; then
    echo -e "${CHIEF_COLOR_GREEN}✓ No pending CSRs found${CHIEF_NO_COLOR}"
    return 0
  fi

  # Apply filter if specified
  if [[ -n "$filter_pattern" ]]; then
    pending_csrs=$(echo "$pending_csrs" | grep "$filter_pattern")
    if [[ -z "$pending_csrs" ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}No pending CSRs match filter pattern: $filter_pattern${CHIEF_NO_COLOR}"
      return 0
    fi
  fi

  local csr_count
  csr_count=$(echo "$pending_csrs" | wc -l | tr -d ' ')
  
  echo -e "${CHIEF_COLOR_BLUE}Found $csr_count pending CSR(s)${CHIEF_NO_COLOR}"
  
  if [[ -n "$filter_pattern" ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Filter applied:${CHIEF_NO_COLOR} $filter_pattern"
  fi

  echo ""
  echo -e "${CHIEF_COLOR_CYAN}Pending CSRs:${CHIEF_NO_COLOR}"
  echo "$pending_csrs"
  echo ""

  # List only mode
  if [[ "$list_only" == true ]]; then
    echo -e "${CHIEF_COLOR_BLUE}Detailed CSR information:${CHIEF_NO_COLOR}"
    while read -r line; do
      local csr_name
      csr_name=$(echo "$line" | awk '{print $1}')
      echo -e "${CHIEF_COLOR_CYAN}CSR: $csr_name${CHIEF_NO_COLOR}"
      oc describe csr "$csr_name" | grep -E "(Name:|Requesting User:|Subject:|DNS Names:|IP Addresses:)" | sed 's/^/  /'
      echo ""
    done <<< "$pending_csrs"
    return 0
  fi

  # Dry-run mode
  if [[ "$dry_run" == true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}DRY RUN: Would approve the following CSRs:${CHIEF_NO_COLOR}"
    while read -r line; do
      local csr_name
      csr_name=$(echo "$line" | awk '{print $1}')
      echo -e "  ${CHIEF_COLOR_BLUE}oc adm certificate approve $csr_name${CHIEF_NO_COLOR}"
    done <<< "$pending_csrs"
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Use without -n/--dry-run to actually approve CSRs${CHIEF_NO_COLOR}"
    return 0
  fi

  # Batch approval mode
  if [[ "$approve_all" == true ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}WARNING: About to approve ALL pending CSRs${CHIEF_NO_COLOR}"
    echo -e "${CHIEF_COLOR_RED}This action cannot be undone!${CHIEF_NO_COLOR}"
    echo -n "Continue? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled${CHIEF_NO_COLOR}"
      return 0
    fi
    
    echo -e "${CHIEF_COLOR_BLUE}Approving all pending CSRs...${CHIEF_NO_COLOR}"
    local approved=0
    local failed=0
    
    while read -r line; do
      local csr_name
      csr_name=$(echo "$line" | awk '{print $1}')
      echo -n "  Approving $csr_name... "
      
      if oc adm certificate approve "$csr_name" &>/dev/null; then
        echo -e "${CHIEF_COLOR_GREEN}✓${CHIEF_NO_COLOR}"
        ((approved++))
      else
        echo -e "${CHIEF_COLOR_RED}✗${CHIEF_NO_COLOR}"
        ((failed++))
      fi
    done <<< "$pending_csrs"
    
    echo ""
    echo -e "${CHIEF_COLOR_GREEN}Summary: $approved approved, $failed failed${CHIEF_NO_COLOR}"
    return 0
  fi

  # Interactive approval mode (default)
  echo -e "${CHIEF_COLOR_BLUE}Interactive approval mode${CHIEF_NO_COLOR}"
  echo -e "${CHIEF_COLOR_YELLOW}For each CSR: [y]es, [n]o, [d]etails, [q]uit${CHIEF_NO_COLOR}"
  echo ""
  
  local approved=0
  local skipped=0
  
  while read -r line; do
    local csr_name
    csr_name=$(echo "$line" | awk '{print $1}')
    
    while true; do
      echo -n "Approve CSR '$csr_name'? [y/n/d/q]: "
      read -r choice
      
      case $choice in
        [Yy]|[Yy][Ee][Ss])
          echo -n "  Approving... "
          if oc adm certificate approve "$csr_name" &>/dev/null; then
            echo -e "${CHIEF_COLOR_GREEN}✓ Approved${CHIEF_NO_COLOR}"
            ((approved++))
          else
            echo -e "${CHIEF_COLOR_RED}✗ Failed${CHIEF_NO_COLOR}"
          fi
          break
          ;;
        [Nn]|[Nn][Oo])
          echo -e "  ${CHIEF_COLOR_YELLOW}Skipped${CHIEF_NO_COLOR}"
          ((skipped++))
          break
          ;;
        [Dd]|[Dd][Ee][Tt]*)
          echo -e "${CHIEF_COLOR_CYAN}CSR Details:${CHIEF_NO_COLOR}"
          oc describe csr "$csr_name"
          echo ""
          ;;
        [Qq]|[Qq][Uu][Ii][Tt])
          echo -e "${CHIEF_COLOR_YELLOW}Operation cancelled by user${CHIEF_NO_COLOR}"
          echo -e "${CHIEF_COLOR_BLUE}Summary: $approved approved, $skipped skipped${CHIEF_NO_COLOR}"
          return 0
          ;;
        *)
          echo -e "${CHIEF_COLOR_RED}Invalid choice. Use y/n/d/q${CHIEF_NO_COLOR}"
          ;;
      esac
    done
  done <<< "$pending_csrs"
  
  echo ""
  echo -e "${CHIEF_COLOR_GREEN}Summary: $approved approved, $skipped skipped${CHIEF_NO_COLOR}"
}

function chief.oc_show-stuck-resources() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <namespace> [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Shows all stuck or problematic resources in a specific OpenShift namespace.
Can optionally remove finalizers from terminating resources to fix stuck deletions.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  namespace       Name of the namespace to inspect for stuck resources

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --fix           Automatically remove finalizers from terminating resources
  -n, --dry-run   Show what would be fixed without making changes
  -y, --yes       Skip confirmation prompts (use with --fix for automation)
  -?              Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Iterates through all available API resources that can be listed in a namespace
- Displays their current state with detailed information
- Identifies terminating resources stuck due to finalizers
- Can automatically patch resources to remove finalizers (with --fix)
- Useful for debugging stuck deployments, pods, or other OpenShift resources

${CHIEF_COLOR_RED}⚠️  WARNING:${CHIEF_NO_COLOR}
Removing finalizers can bypass important cleanup operations and may lead to:
- Resource leaks (external resources not properly cleaned up)
- Orphaned dependencies
- Data loss or corruption
Only use --fix when you understand the implications!

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- OpenShift CLI (oc) must be installed and available in PATH
- User must be logged into the OpenShift cluster
- User must have permissions to list and patch resources in the target namespace

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.oc_show_stuck_resources my-namespace              # Show all resources in my-namespace
  chief.oc_show_stuck_resources production --dry-run      # Preview what stuck resources would be fixed
  chief.oc_show_stuck_resources dev-environment --fix     # Fix stuck terminating resources"

  local namespace="$1"
  local fix_mode=false
  local dry_run=false
  local auto_yes=false

  # Handle help option and validate required arguments
  if [[ -z "$namespace" || "$namespace" == "-?" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  # Parse options
  shift
  while [[ $# -gt 0 ]]; do
    case $1 in
      --fix) fix_mode=true; shift ;;
      -n|--dry-run) dry_run=true; shift ;;
      -y|--yes) auto_yes=true; shift ;;
      -?) echo -e "${USAGE}"; return 0 ;;
      *) __chief_print_error "Unknown option: $1"; return 1 ;;
    esac
  done

  # Validate prerequisites
  if ! command -v oc &>/dev/null; then
    __chief_print_error "OpenShift CLI (oc) is not installed or not in PATH."
    return 1
  fi

  # Check OpenShift login status and display cluster info
  if ! __chief_oc_check_login; then
    return 1
  fi

  # Validate namespace exists
  if ! oc get namespace "$namespace" &>/dev/null; then
    __chief_print_error "Namespace '$namespace' does not exist or is not accessible"
    return 1
  fi

  # Show safety warning if fix mode is enabled
  if [[ "$fix_mode" == true && "$auto_yes" != true ]]; then
    echo
    __chief_print_error "⚠️  DANGER: --fix mode will remove finalizers from terminating resources!"
    __chief_print_error "This can bypass important cleanup operations and cause resource leaks."
    echo
    echo -e "${CHIEF_COLOR_BLUE}Current cluster:${CHIEF_NO_COLOR} $(oc whoami --show-server 2>/dev/null)"
    echo -e "${CHIEF_COLOR_BLUE}Logged in as:${CHIEF_NO_COLOR} $(oc whoami 2>/dev/null)"
    echo ""
    read -p "Are you sure you want to proceed? Type 'yes' to continue: " confirmation
    if [[ "$confirmation" != "yes" ]]; then
      __chief_print_info "Operation cancelled by user"
      return 0
    fi
  fi

  if [[ "$dry_run" == true ]]; then
    __chief_print_info "DRY RUN: Showing what would be fixed without making changes"
  fi

  __chief_print_info "Scanning for stuck resources in namespace: $namespace"
  __chief_print_info "This may take a few moments depending on the number of resource types..."

  local resource_count=0
  local stuck_count=0
  local fixed_count=0
  local api_resources
  
  # Get list of namespaced API resources that support patching (for fixing)
  if [[ "$fix_mode" == true || "$dry_run" == true ]]; then
    api_resources=$(oc api-resources --verbs=list,patch --namespaced -o name 2>/dev/null)
  else
    api_resources=$(oc api-resources --verbs=list --namespaced -o name 2>/dev/null)
  fi
  
  if [[ -z "$api_resources" ]]; then
    __chief_print_error "Failed to retrieve API resources list"
    return 1
  fi

  # Iterate through each resource type
  for resource_type in $api_resources; do
    __chief_print_info "Checking resource type: $resource_type"
    
    local resources_output
    resources_output=$(oc get --show-kind --ignore-not-found -n "$namespace" "$resource_type" 2>/dev/null)
    
    if [[ -n "$resources_output" ]]; then
      echo
      __chief_print_success "Found resources of type: $resource_type"
      echo "$resources_output"
      ((resource_count++))
      
      # Check for terminating resources if in fix or dry-run mode
      if [[ "$fix_mode" == true || "$dry_run" == true ]]; then
        # Get individual resource names that are terminating
        local terminating_resources
        terminating_resources=$(echo "$resources_output" | awk 'NR>1 && $3=="Terminating" {print $1}' 2>/dev/null)
        
        if [[ -n "$terminating_resources" ]]; then
          while IFS= read -r resource_name; do
            if [[ -n "$resource_name" ]]; then
              ((stuck_count++))
              echo -e "${CHIEF_COLOR_YELLOW}Found terminating resource: $resource_type/$resource_name${CHIEF_NO_COLOR}"
              
              # Check if resource has finalizers
              local finalizers
              finalizers=$(oc get "$resource_type" "$resource_name" -n "$namespace" -o jsonpath='{.metadata.finalizers}' 2>/dev/null)
              
              if [[ -n "$finalizers" && "$finalizers" != "[]" ]]; then
                echo -e "  ${CHIEF_COLOR_RED}Has finalizers:${CHIEF_NO_COLOR} $finalizers"
                
                if [[ "$dry_run" == true ]]; then
                  echo -e "  ${CHIEF_COLOR_CYAN}DRY RUN: Would remove finalizers${CHIEF_NO_COLOR}"
                elif [[ "$fix_mode" == true ]]; then
                  echo -e "  ${CHIEF_COLOR_YELLOW}Removing finalizers...${CHIEF_NO_COLOR}"
                  
                  # Remove finalizers by patching the resource
                  if oc patch "$resource_type" "$resource_name" -n "$namespace" --type='merge' -p='{"metadata":{"finalizers":null}}' 2>/dev/null; then
                    echo -e "  ${CHIEF_COLOR_GREEN}✓ Successfully removed finalizers${CHIEF_NO_COLOR}"
                    ((fixed_count++))
                  else
                    echo -e "  ${CHIEF_COLOR_RED}✗ Failed to remove finalizers${CHIEF_NO_COLOR}"
                  fi
                fi
              else
                echo -e "  ${CHIEF_COLOR_BLUE}No finalizers found${CHIEF_NO_COLOR}"
              fi
            fi
          done <<< "$terminating_resources"
        fi
      fi
    fi
  done

  echo
  if [[ $resource_count -eq 0 ]]; then
    __chief_print_info "No resources found in namespace: $namespace"
  else
    __chief_print_success "Resource scan completed. Found $resource_count resource types with objects in namespace: $namespace"
    
    if [[ "$fix_mode" == true || "$dry_run" == true ]]; then
      if [[ $stuck_count -gt 0 ]]; then
        echo -e "${CHIEF_COLOR_YELLOW}Stuck terminating resources found: $stuck_count${CHIEF_NO_COLOR}"
        
        if [[ "$fix_mode" == true ]]; then
          echo -e "${CHIEF_COLOR_GREEN}Resources fixed: $fixed_count${CHIEF_NO_COLOR}"
        elif [[ "$dry_run" == true ]]; then
          echo -e "${CHIEF_COLOR_CYAN}Resources that would be fixed: $stuck_count${CHIEF_NO_COLOR}"
        fi
      else
        __chief_print_success "No stuck terminating resources found"
      fi
    fi
  fi
  
  return 0
}

function chief.oc_login() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <cluster_name> [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Login to an OpenShift cluster using Vault secrets (preferred) or local cluster definitions.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  cluster_name    Name of the cluster to connect to

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -kc             Use kubeconfig authentication
  -ka             Use kubeadmin authentication  
  -i              Skip TLS verification (insecure)
  -?              Show this help

${CHIEF_COLOR_MAGENTA}Authentication Methods (in order of preference):${CHIEF_NO_COLOR}
  ${CHIEF_COLOR_GREEN}1. Vault (Recommended)${CHIEF_NO_COLOR} - Requires:
     • VAULT_ADDR and VAULT_TOKEN environment variables
     • CHIEF_VAULT_OC_PATH (e.g., 'secrets/openshift')
     • Vault secret at: \${CHIEF_VAULT_OC_PATH}/\${cluster_name}
       - api: OpenShift API URL
       - kubeconfig: kubeconfig file content (for -kc)
       - kubeadmin: kubeadmin password (for -ka)
  
  ${CHIEF_COLOR_GREEN}2. Local Clusters${CHIEF_NO_COLOR} - CHIEF_OC_CLUSTERS array:
     declare -gA CHIEF_OC_CLUSTERS=(
       ['cluster1']='https://api.cluster1.com,username,password'
     )

  ${CHIEF_COLOR_GREEN}3. Environment Variables${CHIEF_NO_COLOR} (fallback):
     • CHIEF_OC_USERNAME and optionally CHIEF_OC_PASSWORD

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.oc_login hub -kc         # Login with kubeconfig
  chief.oc_login hub -ka         # Login as kubeadmin  
  chief.oc_login hub -i          # Login with TLS verification disabled
  chief.oc_login hub             # Login with user credentials"
  # Parse arguments
  local cluster="$1"
  local auth_method="user"
  local tls_option=""

  if [[ -z "$cluster" || "$cluster" == "-?" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  # Parse options
  shift
  while [[ $# -gt 0 ]]; do
    case $1 in
      -kc) auth_method="kubeconfig"; shift ;;
      -ka) auth_method="kubeadmin"; shift ;;
      -i) tls_option="--insecure-skip-tls-verify=true"; shift ;;
      *) __chief_print_error "Unknown option: $1"; return 1 ;;
    esac
  done

  # Validate prerequisites
  if ! command -v oc &>/dev/null; then
    __chief_print_error "OpenShift CLI (oc) is not installed or not in PATH."
    return 1
  fi

  # Handle specific authentication methods (don't fall back to others)
  if [[ "$auth_method" == "kubeconfig" ]]; then
    __chief_oc_try_vault_login "$cluster" "$auth_method" "$tls_option"
    return $?
  elif [[ "$auth_method" == "kubeadmin" ]]; then
    __chief_oc_try_vault_login "$cluster" "$auth_method" "$tls_option"
    return $?
  fi
  
  # Try authentication methods in order of preference (auto mode)
  if __chief_oc_try_vault_login "$cluster" "$auth_method" "$tls_option"; then
    return 0
  elif __chief_oc_try_local_clusters_login "$cluster" "$auth_method" "$tls_option"; then
    return 0
  elif __chief_oc_try_env_login "$cluster" "$auth_method" "$tls_option"; then
    return 0
  else
    __chief_print_error "All authentication methods failed for cluster: $cluster"
    return 1
  fi
}

# Helper function to attempt Vault-based login
function __chief_oc_try_vault_login() {
  # Usage: __chief_oc_try_vault_login <cluster> <auth_method> <tls_option>
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
    __chief_print_warn "Vault CLI not available, skipping Vault authentication"
    return 1
  fi

  if [[ -z "$VAULT_ADDR" || -z "$VAULT_TOKEN" ]]; then
    __chief_print_warn "VAULT_ADDR or VAULT_TOKEN not set, skipping Vault authentication"
    return 1
  fi

  if [[ -z "$CHIEF_VAULT_OC_PATH" ]]; then
    __chief_print_warn "CHIEF_VAULT_OC_PATH not set, skipping Vault authentication"
    return 1
  fi

  # Check if cluster secret exists
  if ! vault kv get "${CHIEF_VAULT_OC_PATH}/${cluster}" &>/dev/null; then
    __chief_print_warn "No Vault secret found at ${CHIEF_VAULT_OC_PATH}/${cluster}"
    return 1
  fi

  __chief_print_info "Using Vault authentication for cluster: $cluster"
  
  local api_url
  api_url=$(vault kv get -field=api "${CHIEF_VAULT_OC_PATH}/${cluster}" 2>/dev/null)
  if [[ -z "$api_url" ]]; then
    __chief_print_error "API URL not found in Vault secret"
    return 1
  fi

  case "$auth_method" in
    kubeconfig)
      __chief_oc_vault_kubeconfig_login "$cluster" "$api_url" "$tls_option"
      ;;
    kubeadmin)
      __chief_oc_vault_kubeadmin_login "$cluster" "$api_url" "$tls_option"
      ;;
    user)
      __chief_oc_vault_user_login "$cluster" "$api_url" "$tls_option"
      ;;
  esac
}

# Helper function for Vault kubeconfig login
function __chief_oc_vault_kubeconfig_login() {
  # Usage: __chief_oc_vault_kubeconfig_login <cluster> <api_url> <tls_option>
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
    __chief_print_error "Kubeconfig not found in Vault (try -ka for kubeadmin)"
    return 1
  fi

  __chief_print_info "Setting up kubeconfig from Vault..."
  
  # Remove existing kubeconfig if it exists to avoid overwrite protection
  [[ -f /tmp/kubeconfig ]] && rm -f /tmp/kubeconfig
  
  # Write kubeconfig to temp file
  echo "$kubeconfig" > /tmp/kubeconfig
  chmod 600 /tmp/kubeconfig  # Secure permissions
  
  export KUBECONFIG=/tmp/kubeconfig
  __chief_print_success "KUBECONFIG set to /tmp/kubeconfig"
  
  # Validate that the login actually works
  local current_user
  current_user=$(oc whoami 2>/dev/null)
  
  if [[ -n "$current_user" && "$current_user" != "Unknown" ]]; then
    __chief_print_success "Logged in as: $current_user"
    return 0
  else
    __chief_print_error "Login validation failed - kubeconfig may have invalid CA or expired credentials"
    __chief_print_error "Try refreshing the kubeconfig in Vault or use -ka for kubeadmin login"
    return 1
  fi
}

# Helper function for Vault kubeadmin login  
function __chief_oc_vault_kubeadmin_login() {
  # Usage: __chief_oc_vault_kubeadmin_login <cluster> <api_url> <tls_option>
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
    __chief_print_error "Kubeadmin password not found in Vault (try -kc for kubeconfig)"
    return 1
  fi

  __chief_print_info "Logging in as kubeadmin to $api_url..."
  if oc login -u "kubeadmin" -p "$kubepass" "$api_url" $tls_option; then
    __chief_print_success "Logged in as: $(oc whoami) - Console: $(oc whoami --show-console 2>/dev/null || echo 'N/A')"
    return 0
  else
    __chief_print_error "Kubeadmin login failed"
    return 1
  fi
}

# Helper function for Vault user login
function __chief_oc_vault_user_login() {
  # Usage: __chief_oc_vault_user_login <cluster> <api_url> <tls_option>
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
    __chief_print_error "CHIEF_OC_USERNAME not set for user authentication"
    return 1
  fi

  __chief_print_info "Logging in as $CHIEF_OC_USERNAME to $api_url..."
  if [[ -n "$CHIEF_OC_PASSWORD" ]]; then
    oc login -u "$CHIEF_OC_USERNAME" -p "$CHIEF_OC_PASSWORD" --server="$api_url" $tls_option
  else
    oc login -u "$CHIEF_OC_USERNAME" --server="$api_url" $tls_option
  fi
  
  if [[ $? -eq 0 ]]; then
    __chief_print_success "Logged in as: $(oc whoami) - Console: $(oc whoami --show-console 2>/dev/null || echo 'N/A')"
    return 0
  else
    __chief_print_error "User login failed"
    return 1
  fi
}

# Helper function to attempt local cluster login
function __chief_oc_try_local_clusters_login() {
  # Usage: __chief_oc_try_local_clusters_login <cluster> <auth_method> <tls_option>
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
    __chief_print_warn "No local cluster definition found for: $cluster"
    return 1
  fi

  if [[ "$auth_method" != "user" ]]; then
    __chief_print_error "Local clusters only support user authentication (not -kc or -ka)"
    return 1
  fi

  __chief_print_info "Using local cluster definition for: $cluster"
  
  local api_url username password
  IFS=',' read -r api_url username password <<< "${CHIEF_OC_CLUSTERS[$cluster]}"
  
  if [[ -z "$api_url" || -z "$username" ]]; then
    __chief_print_error "Incomplete cluster definition for: $cluster"
    return 1
  fi

  __chief_print_info "Logging in as $username to $api_url..."
  if [[ -n "$password" ]]; then
    oc login -u "$username" -p "$password" --server="$api_url" $tls_option
  else
    oc login -u "$username" --server="$api_url" $tls_option
  fi

  if [[ $? -eq 0 ]]; then
    __chief_print_success "Logged in as: $(oc whoami) - Console: $(oc whoami --show-console 2>/dev/null || echo 'N/A')"
    return 0
  else
    __chief_print_error "Local cluster login failed"
    return 1
  fi
}

# Helper function to attempt environment variable login
function __chief_oc_try_env_login() {
  # Usage: __chief_oc_try_env_login <cluster> <auth_method> <tls_option>
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
    __chief_print_error "Environment variable authentication only supports user mode"
    return 1
  fi

  if [[ -z "$CHIEF_OC_USERNAME" ]]; then
    __chief_print_error "CHIEF_OC_USERNAME not set for fallback authentication"
    __chief_print_info "Try using explicit Vault authentication instead:"
    __chief_print_info "  chief.oc.login $cluster -kc  (kubeconfig from Vault)"
    __chief_print_info "  chief.oc.login $cluster -ka  (kubeadmin from Vault)"
    return 1
  fi

  __chief_print_warn "Using fallback environment variable authentication"
  __chief_print_error "No API URL available for cluster: $cluster"
  return 1
}

function chief.oc_delete-stuck-ns() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <namespace> [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Force delete a namespace that is stuck in the 'Terminating' state by removing finalizers.
This function implements the process described in Red Hat's troubleshooting guide for 
terminating namespaces that refuse to delete due to finalizer constraints.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  namespace       Name of the namespace stuck in Terminating state

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -n, --dry-run   Show what would be done without making changes
  --no-confirm    Skip confirmation prompts (dangerous)
  -?              Show this help

${CHIEF_COLOR_GREEN}Process:${CHIEF_NO_COLOR}
1. Validates namespace is in Terminating state
2. Exports namespace definition to temporary JSON file
3. Removes finalizers from the JSON definition
4. Starts oc proxy in background
5. Uses Kubernetes API to finalize namespace deletion
6. Cleans up proxy and temporary files

${CHIEF_COLOR_RED}⚠️  CRITICAL WARNING:${CHIEF_NO_COLOR}
Removing finalizers bypasses important cleanup operations and may cause:
- Resource leaks (external resources not properly cleaned up)
- Orphaned dependencies in other systems
- Data loss or corruption
- Security policy violations
- Billing issues for cloud resources

Only use this when you understand the implications and have verified that:
- All resources in the namespace are properly cleaned up
- External dependencies have been manually addressed
- You accept responsibility for any orphaned resources

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- OpenShift CLI (oc) must be installed and available in PATH
- User must be logged into the OpenShift cluster
- User must have admin permissions to patch namespaces
- curl command must be available
- jq command must be available for JSON manipulation

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.oc_delete_stuck_ns stuck-namespace                    # Force delete with confirmation
  chief.oc_delete_stuck_ns test-env --dry-run                # Preview what would be done
  chief.oc_delete_stuck_ns broken-ns --no-confirm            # Force delete without prompts

${CHIEF_COLOR_BLUE}Reference:${CHIEF_NO_COLOR}
Based on Red Hat's troubleshooting guide:
https://www.redhat.com/en/blog/troubleshooting-terminating-namespaces"

  local namespace="$1"
  local dry_run=false
  local no_confirm=false

  # Handle help option and validate required arguments
  if [[ -z "$namespace" || "$namespace" == "-?" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  # Parse options
  shift
  while [[ $# -gt 0 ]]; do
    case $1 in
      -n|--dry-run) dry_run=true; shift ;;
      --no-confirm) no_confirm=true; shift ;;
      -?) echo -e "${USAGE}"; return 0 ;;
      *) __chief_print_error "Unknown option: $1"; return 1 ;;
    esac
  done

  # Validate prerequisites
  if ! command -v oc &>/dev/null; then
    __chief_print_error "OpenShift CLI (oc) is not installed or not in PATH."
    return 1
  fi

  if ! command -v curl &>/dev/null; then
    __chief_print_error "curl command is required but not found."
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    __chief_print_error "jq command is required for JSON manipulation but not found."
    return 1
  fi

  # Check OpenShift login status and display cluster info
  if ! __chief_oc_check_login; then
    return 1
  fi

  # Validate namespace exists and check its status
  local namespace_status
  namespace_status=$(oc get namespace "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
  
  if [[ $? -ne 0 ]]; then
    __chief_print_error "Namespace '$namespace' does not exist or is not accessible"
    return 1
  fi

  if [[ "$namespace_status" != "Terminating" ]]; then
    __chief_print_warn "Namespace '$namespace' is not in Terminating state (current: $namespace_status)"
    if [[ "$no_confirm" != true ]]; then
      echo
      echo -e "${CHIEF_COLOR_BLUE}Target cluster:${CHIEF_NO_COLOR} $(oc whoami --show-server 2>/dev/null)"
      echo -e "${CHIEF_COLOR_BLUE}Logged in as:${CHIEF_NO_COLOR} $(oc whoami 2>/dev/null)"
      echo ""
      read -p "Continue anyway? This may delete an active namespace! Type 'yes' to proceed: " confirmation
      if [[ "$confirmation" != "yes" ]]; then
        __chief_print_info "Operation cancelled by user"
        return 0
      fi
    fi
  fi

  # Show current namespace status
  echo
  __chief_print_info "Current namespace status:"
  oc get namespace "$namespace" -o yaml | grep -A 10 -B 5 -E "(finalizers|phase|conditions)" || true

  # Show safety warning and get confirmation
  if [[ "$no_confirm" != true ]]; then
    echo
    __chief_print_error "⚠️  DANGER: This will forcibly remove finalizers from namespace '$namespace'"
    __chief_print_error "This can bypass important cleanup operations and cause resource leaks!"
    echo
    echo "Make sure you have:"
    echo "  1. Manually cleaned up all external resources"
    echo "  2. Verified no important data will be lost"
    echo "  3. Checked for dependencies in other namespaces"
    echo ""
    echo -e "${CHIEF_COLOR_BLUE}Target cluster:${CHIEF_NO_COLOR} $(oc whoami --show-server 2>/dev/null)"
    echo -e "${CHIEF_COLOR_BLUE}Logged in as:${CHIEF_NO_COLOR} $(oc whoami 2>/dev/null)"
    echo
    read -p "I understand the risks and want to proceed. Type 'FORCE DELETE' to continue: " confirmation
    if [[ "$confirmation" != "FORCE DELETE" ]]; then
      __chief_print_info "Operation cancelled by user"
      return 0
    fi
  fi

  # Create temporary file for namespace JSON
  local temp_file
  temp_file=$(mktemp /tmp/namespace-force-delete.XXXXXX.json)
  
  if [[ $? -ne 0 ]]; then
    __chief_print_error "Failed to create temporary file"
    return 1
  fi

  # Cleanup function
  __chief_oc_cleanup() {
    local proxy_pid="$1"
    if [[ -n "$proxy_pid" ]] && kill -0 "$proxy_pid" 2>/dev/null; then
      __chief_print_info "Stopping oc proxy (PID: $proxy_pid)"
      kill "$proxy_pid" 2>/dev/null
      sleep 2
      # Force kill if still running
      if kill -0 "$proxy_pid" 2>/dev/null; then
        kill -9 "$proxy_pid" 2>/dev/null
      fi
    fi
    
    if [[ -f "$temp_file" ]]; then
      rm -f "$temp_file"
    fi
  }

  # Set up trap for cleanup
  local proxy_pid=""
  trap '__chief_oc_cleanup "$proxy_pid"' EXIT INT TERM

  if [[ "$dry_run" == true ]]; then
    __chief_print_info "DRY RUN: Would force delete namespace '$namespace'"
    
    # Show what would be done
    __chief_print_info "Step 1: Export namespace to JSON"
    echo "  Command: oc get namespace $namespace -o json > $temp_file"
    
    __chief_print_info "Step 2: Remove finalizers from JSON"
    echo "  Would edit: $temp_file to remove .spec.finalizers"
    
    __chief_print_info "Step 3: Start oc proxy"
    echo "  Command: oc proxy --port=8001 &"
    
    __chief_print_info "Step 4: Call finalize API"
    echo "  Command: curl -k -H 'Content-Type: application/json' -X PUT --data-binary @$temp_file http://127.0.0.1:8001/api/v1/namespaces/$namespace/finalize"
    
    __chief_print_info "Step 5: Cleanup proxy and temp files"
    
    __chief_oc_cleanup ""
    return 0
  fi

  # Step 1: Export namespace to JSON
  __chief_print_info "Step 1: Exporting namespace '$namespace' to JSON..."
  if ! oc get namespace "$namespace" -o json > "$temp_file"; then
    __chief_print_error "Failed to export namespace to JSON"
    __chief_oc_cleanup ""
    return 1
  fi

  # Step 2: Remove finalizers from JSON
  __chief_print_info "Step 2: Removing finalizers from JSON..."
  
  # Show current finalizers
  local current_finalizers
  current_finalizers=$(jq -r '.spec.finalizers // []' "$temp_file" 2>/dev/null)
  if [[ -n "$current_finalizers" && "$current_finalizers" != "null" && "$current_finalizers" != "[]" ]]; then
    __chief_print_warn "Current finalizers: $current_finalizers"
  else
    __chief_print_info "No finalizers found in namespace"
  fi

  # Remove finalizers using jq
  if ! jq 'del(.spec.finalizers)' "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"; then
    __chief_print_error "Failed to remove finalizers from JSON"
    __chief_oc_cleanup ""
    return 1
  fi

  __chief_print_success "Finalizers removed from JSON"

  # Step 3: Start oc proxy
  __chief_print_info "Step 3: Starting oc proxy..."
  
  # Check if port 8001 is already in use
  if netstat -an 2>/dev/null | grep -q ":8001.*LISTEN" || lsof -i :8001 >/dev/null 2>&1; then
    __chief_print_warn "Port 8001 is already in use. Trying to find available port..."
    local proxy_port
    for proxy_port in {8002..8010}; do
      if ! netstat -an 2>/dev/null | grep -q ":$proxy_port.*LISTEN" && ! lsof -i :$proxy_port >/dev/null 2>&1; then
        break
      fi
    done
    
    if [[ $proxy_port -gt 8010 ]]; then
      __chief_print_error "Could not find available port for oc proxy"
      cleanup ""
      return 1
    fi
    
    __chief_print_info "Using port $proxy_port for oc proxy"
  else
    proxy_port=8001
  fi

  # Start proxy in background
  oc proxy --port="$proxy_port" >/dev/null 2>&1 &
  proxy_pid=$!

  # Wait for proxy to start
  __chief_print_info "Waiting for proxy to start..."
  local retries=10
  while [[ $retries -gt 0 ]]; do
    if curl -s "http://127.0.0.1:$proxy_port/api" >/dev/null 2>&1; then
      break
    fi
    sleep 1
    ((retries--))
  done

  if [[ $retries -eq 0 ]]; then
    __chief_print_error "Proxy failed to start or is not responding"
    __chief_oc_cleanup "$proxy_pid"
    return 1
  fi

  __chief_print_success "Proxy started successfully on port $proxy_port (PID: $proxy_pid)"

  # Step 4: Call finalize API
  __chief_print_info "Step 4: Calling Kubernetes API to finalize namespace deletion..."
  
  local api_response
  api_response=$(curl -s -k -H "Content-Type: application/json" -X PUT \
    --data-binary "@$temp_file" \
    "http://127.0.0.1:$proxy_port/api/v1/namespaces/$namespace/finalize" 2>&1)
  
  local curl_exit_code=$?
  
  if [[ $curl_exit_code -eq 0 ]] && echo "$api_response" | jq -e '.kind == "Namespace"' >/dev/null 2>&1; then
    __chief_print_success "Namespace finalization API call successful"
    
    # Wait a moment and check if namespace is deleted
    sleep 3
    if ! oc get namespace "$namespace" >/dev/null 2>&1; then
      __chief_print_success "✓ Namespace '$namespace' has been successfully deleted!"
    else
      local new_status
      new_status=$(oc get namespace "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
      __chief_print_warn "Namespace still exists with status: $new_status"
      __chief_print_info "This may be normal - deletion can take a few more moments"
    fi
  else
    __chief_print_error "Failed to call finalize API"
    echo "API Response: $api_response"
    __chief_oc_cleanup "$proxy_pid"
    return 1
  fi

  # Step 5: Cleanup
  __chief_print_info "Step 5: Cleaning up..."
  __chief_oc_cleanup "$proxy_pid"
  proxy_pid=""  # Clear so trap doesn't try to clean up again

  __chief_print_success "Force delete operation completed for namespace '$namespace'"
  __chief_print_info "Please verify the namespace is deleted: oc get namespace $namespace"
  
  return 0
}