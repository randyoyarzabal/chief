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

function chief.oc_whoami() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Display comprehensive information about the current OpenShift cluster login session,
including user identity, API server, console address, and cluster context.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -q, --quiet     Show minimal output (user and server only)
  -j, --json      Output information in JSON format
  -?, --help      Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Shows current authenticated user
- Displays API server URL
- Retrieves console web address (if available)
- Shows current OpenShift context
- Validates active login session
- Supports both detailed and minimal output modes

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- OpenShift CLI (oc) must be installed and available in PATH
- User must be logged into OpenShift cluster

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  $FUNCNAME                    # Full cluster information display
  $FUNCNAME -q                 # Minimal output (user and server)
  $FUNCNAME -j                 # JSON format output
  $FUNCNAME --quiet            # Minimal output (long form)

${CHIEF_COLOR_BLUE}Output Format:${CHIEF_NO_COLOR}
Default mode shows:
- Current user identity
- API server URL
- Console web address
- Current context name
- Login session status

${CHIEF_COLOR_BLUE}JSON Format:${CHIEF_NO_COLOR}
{
  \"user\": \"username\",
  \"server\": \"https://api.cluster.com:6443\",
  \"console\": \"https://console.cluster.com\",
  \"context\": \"context-name\"
}"

  # Check if OpenShift CLI is available
  if ! command -v oc &>/dev/null; then
    echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} OpenShift CLI (oc) is required but not found."
    echo -e "${CHIEF_COLOR_YELLOW}Install:${CHIEF_NO_COLOR}"
    echo "  Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
    echo "  Or use package manager (brew install openshift-cli, etc.)"
    return 1
  fi

  local quiet_mode=false
  local json_output=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -q|--quiet)
        quiet_mode=true
        shift
        ;;
      -j|--json)
        json_output=true
        shift
        ;;
      -\?|--help)
        echo -e "${USAGE}"
        return 0
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

  # Check if logged into OpenShift
  if ! oc whoami &>/dev/null; then
    if [[ "$json_output" == true ]]; then
      echo '{"error": "Not logged into OpenShift cluster", "logged_in": false}'
    else
      echo -e "${CHIEF_COLOR_RED}Error:${CHIEF_NO_COLOR} Not logged into OpenShift cluster"
      echo -e "${CHIEF_COLOR_YELLOW}Hint:${CHIEF_NO_COLOR} Run 'oc login' or 'chief.oc_login' to authenticate"
    fi
    return 1
  fi

  # Get cluster information
  local current_user current_server current_console current_context
  current_user=$(oc whoami 2>/dev/null)
  current_server=$(oc whoami --show-server 2>/dev/null)
  current_console=$(oc whoami --show-console 2>/dev/null)
  current_context=$(oc config current-context 2>/dev/null)

  # Handle missing console (some clusters may not have it configured)
  if [[ -z "$current_console" || "$current_console" == "null" ]]; then
    current_console="N/A"
  fi

  # Output based on format requested
  if [[ "$json_output" == true ]]; then
    # JSON output
    cat << EOF
{
  "logged_in": true,
  "user": "$current_user",
  "server": "$current_server",
  "console": "$current_console",
  "context": "$current_context"
}
EOF
  elif [[ "$quiet_mode" == true ]]; then
    # Quiet mode - minimal output
    echo "User: $current_user"
    echo "Server: $current_server"
  else
    # Full detailed output
    echo -e "${CHIEF_SYMBOL_CHECK} ${CHIEF_COLOR_GREEN}OpenShift Cluster Information${CHIEF_NO_COLOR}"
    echo ""
    echo -e "${CHIEF_COLOR_BLUE}User:${CHIEF_NO_COLOR} $current_user"
    echo -e "${CHIEF_COLOR_BLUE}API Server:${CHIEF_NO_COLOR} $current_server"
    echo -e "${CHIEF_COLOR_BLUE}Console:${CHIEF_NO_COLOR} $current_console"
    echo -e "${CHIEF_COLOR_BLUE}Context:${CHIEF_NO_COLOR} $current_context"
    echo ""
    echo -e "${CHIEF_COLOR_GREEN}✓ Successfully authenticated to cluster${CHIEF_NO_COLOR}"
  fi

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
  -q, --quiet            Suppress resource type headers
  -?, --help             Show this help

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
      -\?|--help)
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
  -?, --help      Show this help

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
      -\?|--help)
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
    echo -e "${CHIEF_COLOR_GREEN}✓ OLM cleanup completed${CHIEF_NO_COLOR}"
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
  -?, --help      Show this help

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
      -\?|--help)
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
      echo -e "${CHIEF_COLOR_GREEN}✓ Successfully deleted $deleted_count ReplicaSets${CHIEF_NO_COLOR}"
    else
      echo -e "${CHIEF_COLOR_YELLOW}⚠  Deleted $deleted_count ReplicaSets, $failed_count failed${CHIEF_NO_COLOR}"
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
  -?, --help      Show this help

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
  chief.oc_approve-csrs                          # Interactive approval of pending CSRs
  chief.oc_approve-csrs -l                       # List pending CSRs only
  chief.oc_approve-csrs -a                       # Approve all pending CSRs
  chief.oc_approve-csrs -n                       # Dry-run: show what would be approved
  chief.oc_approve-csrs -f \"node-\"               # Approve only node-related CSRs
  chief.oc_approve-csrs -f \"system:node\"         # Approve system node CSRs only
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
      -\?|--help)
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

# Helper function to force finalize a resource using proxy + direct API method
__chief_oc_force_finalize_resource() {
  local resource_type="$1"
  local resource_name="$2"  
  local namespace="$3"
  
  # Create temporary file for resource JSON
  local temp_file
  temp_file=$(mktemp /tmp/resource-force-finalize.XXXXXX.json)
  
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Cleanup function for this helper
  __chief_oc_force_cleanup() {
    local proxy_pid="$1"
    if [[ -n "$proxy_pid" ]] && kill -0 "$proxy_pid" 2>/dev/null; then
      kill "$proxy_pid" 2>/dev/null
      sleep 1
      if kill -0 "$proxy_pid" 2>/dev/null; then
        kill -9 "$proxy_pid" 2>/dev/null
      fi
    fi
    
    if [[ -f "$temp_file" ]]; then
      rm -f "$temp_file"
    fi
  }

  # Export resource to JSON
  if ! oc get "$resource_type" "$resource_name" -n "$namespace" -o json > "$temp_file" 2>/dev/null; then
    rm -f "$temp_file"
    return 1
  fi

  # Remove finalizers using jq
  if ! jq 'del(.metadata.finalizers)' "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"; then
    rm -f "$temp_file"
    return 1
  fi

  # Find available port for proxy
  local proxy_port=8001
  while netstat -an 2>/dev/null | grep -q ":$proxy_port.*LISTEN" || lsof -i :$proxy_port >/dev/null 2>&1; do
    ((proxy_port++))
    if [[ $proxy_port -gt 8010 ]]; then
      rm -f "$temp_file"
      return 1
    fi
  done

  # Start proxy in background
  oc proxy --port="$proxy_port" >/dev/null 2>&1 &
  local proxy_pid=$!

  # Wait for proxy to start
  local retries=10
  while [[ $retries -gt 0 ]]; do
    if curl -s "http://127.0.0.1:$proxy_port/api" >/dev/null 2>&1; then
      break
    fi
    sleep 1
    ((retries--))
  done

  if [[ $retries -eq 0 ]]; then
    __chief_oc_force_cleanup "$proxy_pid"
    return 1
  fi

  # Get API group and version for the resource type
  local api_info
  api_info=$(oc api-resources --no-headers 2>/dev/null | grep "^$resource_type " | head -1)
  local api_group=$(echo "$api_info" | awk '{print $3}')
  local api_version=$(echo "$api_info" | awk '{print $2}')
  
  # Build API path
  local api_path
  if [[ "$api_group" == "" || "$api_group" == "v1" ]]; then
    api_path="/api/v1/namespaces/$namespace/$resource_type/$resource_name/finalize"
  else
    api_path="/apis/$api_group/$api_version/namespaces/$namespace/$resource_type/$resource_name/finalize"
  fi

  # Call finalize API directly
  local api_response
  api_response=$(curl -s -k -H "Content-Type: application/json" -X PUT \
    --data-binary "@$temp_file" \
    "http://127.0.0.1:$proxy_port$api_path" 2>&1)
  
  local curl_exit_code=$?
  
  # Cleanup
  __chief_oc_force_cleanup "$proxy_pid"
  
  # Check if successful - verify both API response AND actual resource deletion
  if [[ $curl_exit_code -eq 0 ]] && echo "$api_response" | jq -e '.kind' >/dev/null 2>&1; then
    # API call succeeded, but verify the resource is actually gone
    sleep 2  # Give it a moment to process
    if ! oc get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
      return 0  # Resource is actually gone
    else
      return 1  # API succeeded but resource still exists
    fi
  else
    return 1
  fi
}

# Helper function for general stubborn resource cleanup (simplified)
__chief_oc_extreme_delete_resource() {
  local resource_type="$1"
  local resource_name="$2"  
  local namespace="$3"
  
  # Method 1: Force delete with grace period 0 and verify
  echo -e "      ${CHIEF_COLOR_CYAN}• Trying force delete (grace-period=0)...${CHIEF_NO_COLOR}"
  oc delete "$resource_type" "$resource_name" -n "$namespace" --grace-period=0 --force 2>/dev/null
  sleep 2
  if ! oc get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
    echo -e "      ${CHIEF_COLOR_GREEN}✓ Force delete succeeded - resource is gone${CHIEF_NO_COLOR}"
    return 0
  fi
  echo -e "      ${CHIEF_COLOR_YELLOW}Force delete failed - resource still exists${CHIEF_NO_COLOR}"
  
  # Method 2: Try JSON patch to remove all finalizers and verify
  echo -e "      ${CHIEF_COLOR_CYAN}• Trying JSON patch to remove all finalizers...${CHIEF_NO_COLOR}"
  oc patch "$resource_type" "$resource_name" -n "$namespace" --type='json' -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null
  sleep 2
  if ! oc get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
    echo -e "      ${CHIEF_COLOR_GREEN}✓ JSON patch succeeded - resource is gone${CHIEF_NO_COLOR}"
    return 0
  fi
  echo -e "      ${CHIEF_COLOR_YELLOW}JSON patch failed - resource still exists${CHIEF_NO_COLOR}"
  
  return 1
}

function chief.oc_show-stuck-resources() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME <namespace> [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Shows all resources in a specific OpenShift namespace and optionally cleans them up
intelligently to enable namespace deletion. With --fix, it deletes normal resources
and removes finalizers from resources already stuck in terminating state.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  namespace       Name of the namespace to inspect/clean up

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  --fix           Delete all resources and remove finalizers from stuck ones
  -n, --dry-run   Show what would be deleted/fixed without making changes
  -y, --yes       Skip confirmation prompts (use with --fix for automation)
  -t, --timeout SECONDS  Timeout for deletion attempts before removing finalizers [default: 3]
  -?, --help      Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Scans all available API resources that can be listed in a namespace
- Displays their current state with detailed information
- With --fix: Uses proven three-level approach for each resource
  • Level 1: Attempt normal deletion with timeout (configurable, default 3s)
  • Level 2: If stuck, remove finalizers (like manual oc edit)
  • Level 3: If finalizers fail, use proxy + direct API + force delete
- Perfect for cleaning up namespaces that refuse to delete due to stuck resources
- No manual intervention required - handles entire cleanup process automatically

${CHIEF_COLOR_RED}⚠  WARNING:${CHIEF_NO_COLOR}
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
  chief.oc_show-stuck-resources my-namespace              # Show all resources in my-namespace
  chief.oc_show-stuck-resources test-ns --dry-run         # Preview what would be deleted/fixed
  chief.oc_show-stuck-resources old-project --fix         # Complete cleanup with 3-level approach
  chief.oc_show-stuck-resources cleanup-ns --fix -y       # Non-interactive cleanup
  chief.oc_show-stuck-resources stuck-ns --fix -t 1       # Fast cleanup (1 second timeout)

${CHIEF_COLOR_BLUE}Three-Level Process:${CHIEF_NO_COLOR}
  1. Level 1: Attempt normal deletion for each resource
  2. Level 2: If stuck, remove finalizers (like manual oc edit)
  3. Level 3: If finalizers fail, use proxy + force delete (extreme measures)
  4. Each level verifies resource is actually gone (not just return codes)
  5. Namespace ready for deletion"

  local namespace="$1"
  local fix_mode=false
  local dry_run=false
  local auto_yes=false
  local timeout_seconds=3

  # Handle help option and validate required arguments
  if [[ -z "$namespace" || "$namespace" == "-?" || "$namespace" == "--help" ]]; then
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
      -t|--timeout) 
        if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
          timeout_seconds="$2"
          shift 2
        else
          __chief_print_error "Timeout value must be a positive integer"
          return 1
        fi
        ;;
      -\?|--help) echo -e "${USAGE}"; return 0 ;;
      *) __chief_print_error "Unknown option: $1"; return 1 ;;
    esac
  done

  # Validate prerequisites
  if ! command -v oc &>/dev/null; then
    __chief_print_error "OpenShift CLI (oc) is not installed or not in PATH."
    return 1
  fi
  
  # Check for jq (needed for advanced proxy method)
  if [[ "$fix_mode" == true ]] && ! command -v jq &>/dev/null; then
    __chief_print_error "jq is required for --fix mode but not found."
    __chief_print_info "Install: macOS: brew install jq, Linux: apt install jq / yum install jq"
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

  # Show safety warning if fix mode is enabled (but not in dry-run)
  if [[ "$fix_mode" == true && "$auto_yes" != true && "$dry_run" != true ]]; then
    echo
    __chief_print_warn "⚠  DANGER: --fix mode will perform COMPLETE NAMESPACE CLEANUP!"
    __chief_print_warn "This uses a proven three-level approach:"
    echo
    echo -e "${CHIEF_COLOR_YELLOW}1. Delete each resource${CHIEF_NO_COLOR} (attempt normal deletion)"
    echo -e "${CHIEF_COLOR_YELLOW}2. Wait ${timeout_seconds} seconds${CHIEF_NO_COLOR} for clean deletion (like your manual timing)"
    echo -e "${CHIEF_COLOR_YELLOW}3. If stuck: Kill delete${CHIEF_NO_COLOR} (like Ctrl-C) and remove finalizers"
    echo -e "${CHIEF_COLOR_YELLOW}4. If finalizers fail: Use proxy + direct API${CHIEF_NO_COLOR} (bypasses webhooks)"
    echo -e "${CHIEF_COLOR_YELLOW}5. If proxy fails: Force delete + JSON patch${CHIEF_NO_COLOR} (extreme measures)"
    echo -e "${CHIEF_COLOR_YELLOW}6. Result: Complete cleanup${CHIEF_NO_COLOR} ready for namespace deletion"
    echo
    __chief_print_warn "⚠  This can bypass important cleanup operations and cause resource leaks!"
    __chief_print_warn "⚠  All data and resources in this namespace will be permanently lost!"
    echo
    echo -e "${CHIEF_COLOR_BLUE}Target namespace:${CHIEF_NO_COLOR} $namespace"
    echo -e "${CHIEF_COLOR_BLUE}Current cluster:${CHIEF_NO_COLOR} $(oc whoami --show-server 2>/dev/null)"
    echo -e "${CHIEF_COLOR_BLUE}Logged in as:${CHIEF_NO_COLOR} $(oc whoami 2>/dev/null)"
    echo ""
    read -p "Are you sure you want to proceed with complete namespace cleanup? Type 'yes' to continue: " confirmation
    if [[ "$confirmation" != "yes" ]]; then
      __chief_print_info "Operation cancelled by user"
      return 0
    fi
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

  # Main scanning function - handles both show and delete modes
  __chief_scan_resources() {
    for resource_type in $api_resources; do
      echo -e "${CHIEF_COLOR_BLUE}Checking resource type:${CHIEF_NO_COLOR} ${CHIEF_COLOR_CYAN}$resource_type${CHIEF_NO_COLOR}"
      
      local resources_output
      resources_output=$(oc get --show-kind --ignore-not-found -n "$namespace" "$resource_type" 2>/dev/null)
      
      if [[ -n "$resources_output" ]]; then
        echo
        __chief_print_success "Found resources of type: $resource_type"
        echo "$resources_output"
        ((resource_count++))
        
        # If in fix mode or dry-run, process resources using proven manual workflow
        if [[ "$fix_mode" == true || "$dry_run" == true ]]; then
          echo
          if [[ "$dry_run" == true ]]; then
            __chief_print_info "DRY RUN: Would process these resources:"
          else
            __chief_print_info "Processing these resources (delete first, then fix stuck ones):"
          fi
          
          # Process each resource line - extract individual resources  
          while IFS= read -r line; do
            if [[ -n "$line" && ! "$line" =~ ^NAME ]]; then
              # Extract resource name (handle both "name" and "type/name" formats)
              local full_name=$(echo "$line" | awk '{print $1}')
              local resource_name
              if [[ "$full_name" == *"/"* ]]; then
                resource_name=$(echo "$full_name" | awk -F'/' '{print $2}')
              else
                resource_name="$full_name"
              fi
              
              if [[ -n "$resource_name" ]]; then
                if [[ "$dry_run" == true ]]; then
                  echo -e "  ${CHIEF_COLOR_CYAN}• $resource_type/$resource_name - would delete, then fix if stuck${CHIEF_NO_COLOR}"
                else
                  echo -e "  ${CHIEF_COLOR_YELLOW}• $resource_type/$resource_name - attempting deletion...${CHIEF_NO_COLOR}"
                  
                  # Step 1: Try to delete with timeout (like user's manual process)
                  oc delete "$resource_type" "$resource_name" -n "$namespace" --ignore-not-found 2>/dev/null &
                  local delete_pid=$!
                  local count=0
                  
                  # Wait up to timeout_seconds for deletion to complete
                  while [[ $count -lt $timeout_seconds ]]; do
                    if ! kill -0 $delete_pid 2>/dev/null; then
                      # Process finished, wait for it
                      wait $delete_pid
                      break
                    fi
                    sleep 1
                    ((count++))
                  done
                  
                  # Kill the process if it's still running (timed out)
                  if kill -0 $delete_pid 2>/dev/null; then
                    kill $delete_pid 2>/dev/null
                    wait $delete_pid 2>/dev/null
                  fi
                  
                  # Check if resource is actually gone (ignore return codes)
                  if ! oc get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
                    echo -e "    ${CHIEF_COLOR_GREEN}✓ Deleted successfully - resource is gone${CHIEF_NO_COLOR}"
                  else
                    # Step 2: Delete timed out (resource is stuck), remove finalizers (like manual oc edit)
                    echo -e "    ${CHIEF_COLOR_YELLOW}⏱ Deletion timed out - removing finalizers...${CHIEF_NO_COLOR}"
                    
                    # Check if resource still exists and has finalizers
                    local finalizers
                    finalizers=$(oc get "$resource_type" "$resource_name" -n "$namespace" -o jsonpath='{.metadata.finalizers}' 2>/dev/null)
                    
                    if [[ -n "$finalizers" && "$finalizers" != "[]" && "$finalizers" != "null" ]]; then
                      # Remove finalizers by patching the resource (like manual oc edit)
                      oc patch "$resource_type" "$resource_name" -n "$namespace" --type='merge' -p='{"metadata":{"finalizers":null}}' 2>/dev/null
                      sleep 2  # Give it time to process
                      
                      # Check if resource is actually gone (ignore return codes)
                      if ! oc get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
                        echo -e "    ${CHIEF_COLOR_GREEN}✓ Finalizers removed - resource is gone${CHIEF_NO_COLOR}"
                      else
                        echo -e "    ${CHIEF_COLOR_YELLOW}✗ Level 2 failed - resource still exists after finalizer removal${CHIEF_NO_COLOR}"
                        
                        # Third fallback: Use proxy + direct API (like chief.oc_delete-stuck-ns)
                        echo -e "    ${CHIEF_COLOR_BLUE}🔄 Level 3: Trying proxy + direct API method...${CHIEF_NO_COLOR}"
                        if __chief_oc_force_finalize_resource "$resource_type" "$resource_name" "$namespace"; then
                          echo -e "    ${CHIEF_COLOR_GREEN}✓ Level 3 succeeded - resource is gone${CHIEF_NO_COLOR}"
                        else
                          echo -e "    ${CHIEF_COLOR_YELLOW}✗ Level 3 failed - trying extreme measures...${CHIEF_NO_COLOR}"
                          
                          # Fourth fallback: Extreme measures for stubborn resources
                          echo -e "    ${CHIEF_COLOR_MAGENTA}Level 3 extreme: Deploying force delete + JSON patch...${CHIEF_NO_COLOR}"
                          if __chief_oc_extreme_delete_resource "$resource_type" "$resource_name" "$namespace"; then
                            echo -e "    ${CHIEF_COLOR_GREEN}✓ Level 3 extreme succeeded - resource destroyed${CHIEF_NO_COLOR}"
                          else
                            echo -e "    ${CHIEF_COLOR_RED}✗ All methods failed - resource needs manual intervention${CHIEF_NO_COLOR}"
                          fi
                        fi
                      fi
                    else
                      echo -e "    ${CHIEF_COLOR_BLUE}No finalizers found, resource may be gone${CHIEF_NO_COLOR}"
                    fi
                  fi
                fi
              fi
            fi
          done <<< "$resources_output"
        fi
      fi
    done
  }
  
  # Helper function to clean up stuck resources
  __chief_cleanup_stuck_resources() {
    echo
    __chief_print_info "Checking for resources stuck in terminating state..."
    
    for resource_type in $api_resources; do
      local stuck_resources
      stuck_resources=$(oc get "$resource_type" -n "$namespace" --no-headers 2>/dev/null | awk '/Terminating/ {print $1}')
      
      if [[ -n "$stuck_resources" ]]; then
        while IFS= read -r resource_name; do
          if [[ -n "$resource_name" ]]; then
            ((stuck_count++))
            echo -e "${CHIEF_COLOR_YELLOW}Found stuck resource: $resource_type/$resource_name${CHIEF_NO_COLOR}"
            
            # Check if resource has finalizers
            local finalizers
            finalizers=$(oc get "$resource_type" "$resource_name" -n "$namespace" -o jsonpath='{.metadata.finalizers}' 2>/dev/null)
            
            if [[ -n "$finalizers" && "$finalizers" != "[]" && "$finalizers" != "null" ]]; then
              echo -e "  ${CHIEF_COLOR_RED}Has finalizers:${CHIEF_NO_COLOR} $finalizers"
              
              if [[ "$dry_run" == true ]]; then
                echo -e "  ${CHIEF_COLOR_CYAN}DRY RUN: Would remove finalizers${CHIEF_NO_COLOR}"
              else
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
              echo -e "  ${CHIEF_COLOR_BLUE}No finalizers found - should delete naturally${CHIEF_NO_COLOR}"
            fi
          fi
        done <<< "$stuck_resources"
      fi
    done
  }

  # Show what mode we're in
  if [[ "$dry_run" == true ]]; then
    __chief_print_info "DRY RUN MODE: Showing what would be processed (no actual changes)"
  elif [[ "$fix_mode" == true ]]; then
    __chief_print_info "FIX MODE: Delete each resource, if stuck remove finalizers (proven manual workflow)"
  else
    __chief_print_info "SCAN MODE: Showing resources only (use --fix to process them)"
  fi
  echo

  # Scan resources (and delete if in fix mode)
  __chief_scan_resources

  # Handle stuck resources only in non-fix modes (fix mode handles them inline)
  if [[ "$fix_mode" != true ]]; then
    # Only check for stuck resources if we're not in fix mode 
    __chief_cleanup_stuck_resources
  elif [[ "$dry_run" == true ]]; then
    # In dry-run mode, we already showed what would be done inline
    echo
    __chief_print_info "DRY RUN: Terminating resources would have finalizers removed, normal resources would be deleted"
  else
    # In fix mode, resources were processed using proven manual workflow
    echo
    __chief_print_info "✓ MANUAL WORKFLOW COMPLETED:"
    __chief_print_info "• Each resource: Attempted deletion first"
    __chief_print_info "• Stuck resources: Finalizers removed after timeout"
    
    # Final verification - check if namespace is actually clean
    echo
    __chief_print_info "FINAL VERIFICATION: Checking if namespace is actually clean..."
    
    local remaining_resources=0
    for resource_type in $api_resources; do
      local resources_output
      resources_output=$(oc get --show-kind --ignore-not-found -n "$namespace" "$resource_type" 2>/dev/null)
      
      if [[ -n "$resources_output" ]]; then
        local resource_count_for_type
        resource_count_for_type=$(echo "$resources_output" | wc -l)
        resource_count_for_type=$((resource_count_for_type - 1))  # Subtract header line
        
        if [[ $resource_count_for_type -gt 0 ]]; then
          ((remaining_resources += resource_count_for_type))
          echo -e "  ${CHIEF_COLOR_YELLOW}⚠  Still found: $resource_count_for_type $resource_type${CHIEF_NO_COLOR}"
        fi
      fi
    done
    
    echo
        if [[ $remaining_resources -eq 0 ]]; then
          __chief_print_success "✓ NAMESPACE IS CLEAN: No resources remaining in '$namespace'"
          __chief_print_success "Namespace is ready for deletion: oc delete namespace $namespace"
        else
          __chief_print_warn "⚠  NAMESPACE NOT FULLY CLEAN: $remaining_resources resources still remain"
          __chief_print_warn "Some resources may need manual intervention"
        fi
  fi

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

# Helper function to list available clusters from Vault (non-interactive)
function __chief_oc_list_vault_clusters_only() {
  # Usage: __chief_oc_list_vault_clusters_only [filter_pattern]
  # 
  # Lists available OpenShift clusters from Vault without any prompting.
  # Useful for scripting or quick reference.
  #
  # Arguments:
  #   filter_pattern - Optional pattern to filter cluster names (supports wildcards)
  #
  # Returns 0 on success, 1 on failure
  
  local filter_pattern="$1"
  
  # Check Vault prerequisites
  if ! command -v vault &>/dev/null; then
    __chief_print_error "Vault CLI not available - cannot list clusters from Vault"
    __chief_print_info "Install Vault CLI to use this feature"
    return 1
  fi

  if [[ -z "$VAULT_ADDR" || -z "$VAULT_TOKEN" ]]; then
    __chief_print_error "VAULT_ADDR or VAULT_TOKEN not set - cannot access Vault"
    __chief_print_info "Set Vault environment variables to use this feature"
    return 1
  fi

  if [[ -z "$CHIEF_VAULT_OC_PATH" ]]; then
    __chief_print_error "CHIEF_VAULT_OC_PATH not set - cannot determine Vault path for OpenShift clusters"
    __chief_print_info "Set CHIEF_VAULT_OC_PATH environment variable (e.g., 'secrets/openshift')"
    return 1
  fi

  __chief_print_info "Available OpenShift clusters from Vault:"
  __chief_print_info "Vault path: ${CHIEF_VAULT_OC_PATH}"
  [[ -n "$filter_pattern" ]] && __chief_print_info "Filter: $filter_pattern"
  echo
  
  # List secrets under the OpenShift path
  local clusters_list
  clusters_list=$(vault kv list -format=json "${CHIEF_VAULT_OC_PATH}" 2>/dev/null)
  
  if [[ $? -ne 0 ]] || [[ -z "$clusters_list" ]]; then
    __chief_print_error "Failed to list secrets from Vault path: ${CHIEF_VAULT_OC_PATH}"
    __chief_print_info "Verify the path exists and you have read permissions"
    return 1
  fi

  # Parse cluster names from JSON response
  local clusters
  clusters=$(echo "$clusters_list" | jq -r '.[]' 2>/dev/null | sort)
  
  if [[ -z "$clusters" ]]; then
    __chief_print_warn "No OpenShift clusters found in Vault path: ${CHIEF_VAULT_OC_PATH}"
    return 1
  fi

  # Display clusters as a simple list (with optional filtering)
  local cluster_count=0
  local filtered_count=0
  while IFS= read -r cluster; do
    if [[ -n "$cluster" ]]; then
      ((cluster_count++))
      # Apply filter if specified (support glob patterns)
      if [[ -z "$filter_pattern" ]] || [[ "$cluster" == $filter_pattern ]]; then
        echo "  $cluster"
        ((filtered_count++))
      fi
    fi
  done <<< "$clusters"

  echo
  if [[ -n "$filter_pattern" ]]; then
    __chief_print_info "Clusters displayed: $filtered_count (of $cluster_count total)"
    if [[ $filtered_count -eq 0 ]]; then
      __chief_print_warn "No clusters match filter pattern: $filter_pattern"
    fi
  else
    __chief_print_info "Total clusters found: $cluster_count"
  fi
  echo
  __chief_print_info "To connect to a cluster, use:"
  echo "  chief.oc_login <cluster_name>     # User authentication"
  echo "  chief.oc_login <cluster_name> -kc # Kubeconfig authentication"
  echo "  chief.oc_login <cluster_name> -ka # Kubeadmin authentication"
  echo ""
  echo "Note: Add -i to any command to skip TLS verification (insecure)"
  echo
  __chief_print_info "To interactively select a cluster, use:"
  echo "  chief.oc_login -l"
  
  return 0
}

# Helper function to select cluster interactively and execute callback
function __chief_oc_select_vault_cluster() {
  # Usage: __chief_oc_select_vault_cluster <callback_function> [filter_pattern] [callback_arg1] [callback_arg2] ...
  # 
  # Lists available OpenShift clusters from Vault and prompts user to select one.
  # After selection, calls the provided callback function with the selected cluster and additional arguments.
  #
  # Arguments:
  #   callback_function - Function to call with selected cluster (e.g., "__chief_oc_login_with_cluster")
  #   filter_pattern - Optional pattern to filter cluster names (supports wildcards)
  #   callback_arg1, callback_arg2, ... - Additional arguments to pass to callback function
  
  local callback_function="$1"
  local filter_pattern="$2"
  shift 2
  local callback_args=("$@")
  
  # Check Vault prerequisites
  if ! command -v vault &>/dev/null; then
    __chief_print_error "Vault CLI not available - cannot list clusters from Vault"
    __chief_print_info "Install Vault CLI or specify cluster name directly"
    return 1
  fi

  if [[ -z "$VAULT_ADDR" || -z "$VAULT_TOKEN" ]]; then
    __chief_print_error "VAULT_ADDR or VAULT_TOKEN not set - cannot access Vault"
    __chief_print_info "Set Vault environment variables or specify cluster name directly"
    return 1
  fi

  if [[ -z "$CHIEF_VAULT_OC_PATH" ]]; then
    __chief_print_error "CHIEF_VAULT_OC_PATH not set - cannot determine Vault path for OpenShift clusters"
    __chief_print_info "Set CHIEF_VAULT_OC_PATH environment variable (e.g., 'secrets/openshift')"
    return 1
  fi

  __chief_print_info "Discovering available OpenShift clusters from Vault..."
  __chief_print_info "Vault path: ${CHIEF_VAULT_OC_PATH}"
  
  # List secrets under the OpenShift path
  local clusters_list
  clusters_list=$(vault kv list -format=json "${CHIEF_VAULT_OC_PATH}" 2>/dev/null)
  
  if [[ $? -ne 0 ]] || [[ -z "$clusters_list" ]]; then
    __chief_print_error "Failed to list secrets from Vault path: ${CHIEF_VAULT_OC_PATH}"
    __chief_print_info "Verify the path exists and you have read permissions"
    return 1
  fi

  # Parse cluster names from JSON response
  local clusters
  clusters=$(echo "$clusters_list" | jq -r '.[]' 2>/dev/null | sort)
  
  if [[ -z "$clusters" ]]; then
    __chief_print_warn "No OpenShift clusters found in Vault path: ${CHIEF_VAULT_OC_PATH}"
    return 1
  fi

  echo
  echo -e "${CHIEF_COLOR_CYAN}Available OpenShift clusters:${CHIEF_NO_COLOR}"
  [[ -n "$filter_pattern" ]] && echo -e "${CHIEF_COLOR_YELLOW}Filter: $filter_pattern${CHIEF_NO_COLOR}"
  echo

  # Display numbered list of clusters (with optional filtering)
  local cluster_array=()
  local i=1
  local total_clusters=0
  
  while IFS= read -r cluster; do
    if [[ -n "$cluster" ]]; then
      ((total_clusters++))
      # Apply filter if specified (support glob patterns)
      if [[ -z "$filter_pattern" ]] || [[ "$cluster" == $filter_pattern ]]; then
        cluster_array+=("$cluster")
        echo -e "  ${CHIEF_COLOR_BLUE}$i)${CHIEF_NO_COLOR} $cluster"
        ((i++))
      fi
    fi
  done <<< "$clusters"

  if [[ ${#cluster_array[@]} -eq 0 ]]; then
    if [[ -n "$filter_pattern" ]]; then
      __chief_print_warn "No clusters match filter pattern: $filter_pattern"
      __chief_print_info "Total clusters available: $total_clusters"
    else
      __chief_print_warn "No valid cluster names found"
    fi
    return 1
  fi

  echo
  if [[ -n "$filter_pattern" ]]; then
    echo -e "${CHIEF_COLOR_YELLOW}Clusters shown:${CHIEF_NO_COLOR} ${#cluster_array[@]} (of $total_clusters total, filtered by '$filter_pattern')"
  fi
  echo

  # Prompt for selection
  while true; do
    echo -n "Select cluster [1-${#cluster_array[@]}] or 'q' to quit: "
    read -r choice
    
    case "$choice" in
      [Qq]|[Qq][Uu][Ii][Tt])
        __chief_print_info "Operation cancelled by user"
        return 0
        ;;
      ''|*[!0-9]*)
        __chief_print_error "Invalid selection. Please enter a number between 1 and ${#cluster_array[@]}"
        continue
        ;;
      *)
        if [[ "$choice" -ge 1 && "$choice" -le ${#cluster_array[@]} ]]; then
          local selected_cluster="${cluster_array[$((choice-1))]}"
          echo
          __chief_print_info "Selected cluster: $selected_cluster"
          echo
          
          # Call the callback function with selected cluster and additional arguments
          "$callback_function" "$selected_cluster" "${callback_args[@]}"
          return $?
        else
          __chief_print_error "Invalid selection. Please enter a number between 1 and ${#cluster_array[@]}"
          continue
        fi
        ;;
    esac
  done
}

# Helper function to list available clusters from Vault and prompt for selection (legacy compatibility)
function __chief_oc_list_vault_clusters() {
  # Usage: __chief_oc_list_vault_clusters <auth_method> <tls_option> [filter_pattern]
  # 
  # Lists available OpenShift clusters from Vault and prompts user to select one.
  # After selection, automatically proceeds with login using the specified auth method.
  #
  # Arguments:
  #   auth_method - Authentication method: "kubeconfig", "kubeadmin", or "user"
  #   tls_option - TLS option string for oc login command
  #   filter_pattern - Optional pattern to filter cluster names (supports wildcards)
  
  local auth_method="$1"
  local tls_option="$2"
  local filter_pattern="$3"
  
  echo -e "${CHIEF_COLOR_YELLOW}Authentication method:${CHIEF_NO_COLOR} $auth_method"
  [[ -n "$tls_option" ]] && echo -e "${CHIEF_COLOR_YELLOW}TLS option:${CHIEF_NO_COLOR} $tls_option"
  echo
  
  # Use the reusable menu function
  __chief_oc_select_vault_cluster "__chief_oc_login_with_cluster" "$filter_pattern" "$auth_method" "$tls_option"
}

# Helper function to perform login with specified cluster (extracted from main function)
function __chief_oc_login_with_cluster() {
  # Usage: __chief_oc_login_with_cluster <cluster> <auth_method> <tls_option>
  # 
  # Performs the actual OpenShift login with the specified cluster and auth method.
  # This is the core login logic extracted from chief.oc_login for reuse.
  #
  # Arguments:
  #   cluster - Name of the cluster to connect to
  #   auth_method - Authentication method: "kubeconfig", "kubeadmin", or "user"
  #   tls_option - TLS option string for oc login command
  
  local cluster="$1"
  local auth_method="$2"
  local tls_option="$3"

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

function chief.oc_login() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [cluster_name] [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Login to an OpenShift cluster using Vault secrets (preferred) or local cluster definitions.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  cluster_name    Name of the cluster to connect to (optional if using -l or --list-only)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -l, --list      List available clusters from Vault and prompt for selection
  --list-only     List available clusters from Vault without prompting (non-interactive)
  -f, --filter PATTERN  Filter clusters by pattern (supports wildcards like 'ocp*' or 'prod*')
  -kc             Use kubeconfig authentication
  -ka             Use kubeadmin authentication  
  -i              Skip TLS verification (insecure)
  -?, --help      Show this help

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
  chief.oc_login -l              # List available clusters and choose one
  chief.oc_login --list-only     # Just list clusters (non-interactive)
  chief.oc_login -l -f 'ocp*'    # List only clusters starting with 'ocp'
  chief.oc_login --list-only -f 'prod*'  # List only production clusters
  chief.oc_login hub -kc         # Login with kubeconfig
  chief.oc_login hub -ka         # Login as kubeadmin  
  chief.oc_login hub -i          # Login with TLS verification disabled
  chief.oc_login hub             # Login with user credentials"
  # Parse arguments and options
  local cluster=""
  local auth_method="user"
  local tls_option=""
  local list_clusters=false
  local list_only=false
  local filter_pattern=""

  # Check for help first
  if [[ "$1" == "-?" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  # Parse all arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -l|--list)
        list_clusters=true
        shift
        ;;
      --list-only)
        list_only=true
        shift
        ;;
      -f|--filter)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          filter_pattern="$2"
          shift 2
        else
          __chief_print_error "Filter pattern is required"
          echo -e "${USAGE}"
          return 1
        fi
        ;;
      -kc) 
        auth_method="kubeconfig"
        shift
        ;;
      -ka) 
        auth_method="kubeadmin"
        shift
        ;;
      -i) 
        tls_option="--insecure-skip-tls-verify=true"
        shift
        ;;
      -\?|--help)
        echo -e "${USAGE}"
        return 0
        ;;
      -*)
        __chief_print_error "Unknown option: $1"
        return 1
        ;;
      *)
        if [[ -z "$cluster" ]]; then
          cluster="$1"
        else
          __chief_print_error "Multiple cluster names specified. Only one cluster allowed."
          return 1
        fi
        shift
        ;;
    esac
  done

  # Handle list clusters option
  if [[ "$list_clusters" == true ]]; then
    if ! __chief_oc_list_vault_clusters "$auth_method" "$tls_option" "$filter_pattern"; then
      return 1
    fi
    return 0
  fi

  # Handle list-only option (non-interactive)
  if [[ "$list_only" == true ]]; then
    if ! __chief_oc_list_vault_clusters_only "$filter_pattern"; then
      return 1
    fi
    return 0
  fi

  # Validate cluster name is provided for non-list mode
  if [[ -z "$cluster" ]]; then
    __chief_print_error "Cluster name is required (or use -l/--list-only to list available clusters)"
    echo -e "${USAGE}"
    return 1
  fi

  # Validate prerequisites
  if ! command -v oc &>/dev/null; then
    __chief_print_error "OpenShift CLI (oc) is not installed or not in PATH."
    return 1
  fi

  # Use the extracted login helper function
  __chief_oc_login_with_cluster "$cluster" "$auth_method" "$tls_option"
  return $?
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
  # - Writes kubeconfig to ~/.tmp/kubeconfig and sets KUBECONFIG environment variable
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
  
  # Create user-specific temp directory if it doesn't exist
  local user_tmp_dir="${HOME}/.tmp"
  mkdir -p "$user_tmp_dir"
  chmod 700 "$user_tmp_dir"  # Secure directory permissions
  
  local kubeconfig_path="${user_tmp_dir}/kubeconfig"
  
  # Remove existing kubeconfig if it exists to avoid overwrite protection
  [[ -f "$kubeconfig_path" ]] && rm -f "$kubeconfig_path"
  
  # Write kubeconfig to temp file
  echo "$kubeconfig" > "$kubeconfig_path"
  chmod 600 "$kubeconfig_path"  # Secure file permissions
  
  export KUBECONFIG="$kubeconfig_path"
  __chief_print_success "KUBECONFIG set to $kubeconfig_path"
  
  # Validate that the login actually works
  local current_user
  current_user=$(oc whoami 2>/dev/null)
  
  if [[ -n "$current_user" && "$current_user" != "Unknown" ]]; then
    __chief_print_success "Logged in as: $current_user"
    return 0
  else
    __chief_print_error "Login validation failed - kubeconfig may have invalid CA or expired credentials"
    __chief_print_error "Try refreshing the kubeconfig in Vault or use -ka for kubeadmin login"
    __chief_print_info "Kubeconfig saved to: $kubeconfig_path"
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

# Helper function to display kubeadmin credentials for a specific cluster
function __chief_oc_display_kubeadmin_credentials() {
  # Usage: __chief_oc_display_kubeadmin_credentials <cluster>
  # 
  # Displays kubeadmin password and console address for the specified cluster
  # from Vault secrets. This is a callback function used by the interactive menu.
  #
  # Arguments:
  #   cluster - Name of the cluster to display credentials for
  
  local cluster="$1"
  
  # Check Vault prerequisites
  if ! command -v vault &>/dev/null; then
    __chief_print_error "Vault CLI not available - cannot retrieve credentials from Vault"
    return 1
  fi

  if [[ -z "$VAULT_ADDR" || -z "$VAULT_TOKEN" ]]; then
    __chief_print_error "VAULT_ADDR or VAULT_TOKEN not set - cannot access Vault"
    return 1
  fi

  if [[ -z "$CHIEF_VAULT_OC_PATH" ]]; then
    __chief_print_error "CHIEF_VAULT_OC_PATH not set - cannot determine Vault path for OpenShift clusters"
    return 1
  fi

  # Check if cluster secret exists
  if ! vault kv get "${CHIEF_VAULT_OC_PATH}/${cluster}" &>/dev/null; then
    __chief_print_error "No Vault secret found at ${CHIEF_VAULT_OC_PATH}/${cluster}"
    return 1
  fi

  __chief_print_info "Retrieving kubeadmin credentials for cluster: $cluster"
  echo
  
  # Get cluster information from Vault
  local api_url kubeadmin_password console_url
  api_url=$(vault kv get -field=api "${CHIEF_VAULT_OC_PATH}/${cluster}" 2>/dev/null)
  kubeadmin_password=$(vault kv get -field=kubeadmin "${CHIEF_VAULT_OC_PATH}/${cluster}" 2>/dev/null)
  
  # Try to get console URL from Vault first, fallback to deriving from API URL
  console_url=$(vault kv get -field=console "${CHIEF_VAULT_OC_PATH}/${cluster}" 2>/dev/null)
  if [[ -z "$console_url" || "$console_url" == "null" ]]; then
    # Derive console URL from API URL if not explicitly stored
    if [[ -n "$api_url" ]]; then
      console_url=$(echo "$api_url" | sed 's/api\./console-openshift-console.apps./' | sed 's/:6443//')
    fi
  fi
  
  # Validate required fields
  if [[ -z "$api_url" ]]; then
    __chief_print_error "API URL not found in Vault secret for cluster: $cluster"
    return 1
  fi

  if [[ -z "$kubeadmin_password" ]]; then
    __chief_print_error "Kubeadmin password not found in Vault secret for cluster: $cluster"
    __chief_print_info "This cluster may not have kubeadmin credentials stored"
    return 1
  fi

  # Check for clipboard functionality first
  local clipboard_cmd=""
  local clipboard_available=false
  
  if command -v pbcopy &>/dev/null; then
    # macOS - pbcopy always works locally
    clipboard_cmd="pbcopy"
    clipboard_available=true
  elif [[ -n "$DISPLAY" ]] && (command -v xclip &>/dev/null || command -v xsel &>/dev/null); then
    # Linux with X11 display available (local session or X11 forwarding)
    if command -v xclip &>/dev/null; then
      clipboard_cmd="xclip -selection clipboard"
      clipboard_available=true
    elif command -v xsel &>/dev/null; then
      clipboard_cmd="xsel --clipboard --input"
      clipboard_available=true
    fi
  fi
  
  # Display cluster information
  echo -e "${CHIEF_COLOR_GREEN}✓ OpenShift Cluster Kubeadmin Credentials${CHIEF_NO_COLOR}"
  echo ""
  echo -e "${CHIEF_COLOR_BLUE}Cluster:${CHIEF_NO_COLOR} $cluster"
  echo -e "${CHIEF_COLOR_BLUE}API Server:${CHIEF_NO_COLOR} $api_url"
  echo -e "${CHIEF_COLOR_BLUE}Console:${CHIEF_NO_COLOR} ${console_url:-N/A}"
  echo ""
  echo -e "${CHIEF_COLOR_BLUE}Username:${CHIEF_NO_COLOR} kubeadmin"
  
  if [[ "$clipboard_available" == true ]]; then
    # Clipboard available: Copy password to clipboard, don't display on screen
    echo -e "${CHIEF_COLOR_BLUE}Password:${CHIEF_NO_COLOR} [copied to clipboard]"
    echo ""
    echo "$kubeadmin_password" | $clipboard_cmd
    echo -e "${CHIEF_COLOR_YELLOW}🔐 Password copied to clipboard - remember to clear after use${CHIEF_NO_COLOR}"
  else
    # No clipboard available: Display password on screen
    echo -e "${CHIEF_COLOR_BLUE}Password:${CHIEF_NO_COLOR} $kubeadmin_password"
  fi
  
  echo ""
  echo -e "${CHIEF_COLOR_GREEN}Login Command:${CHIEF_NO_COLOR}"
  if [[ "$clipboard_available" == true ]]; then
    echo "  oc login -u kubeadmin -p '<paste-from-clipboard>' '$api_url'"
  else
    echo "  oc login -u kubeadmin -p '$kubeadmin_password' '$api_url'"
  fi
  echo ""
  echo -e "${CHIEF_COLOR_GREEN}Or use Chief login:${CHIEF_NO_COLOR}"
  echo "  chief.oc_login $cluster -ka"
  
  if [[ "$clipboard_available" == true ]]; then
    echo ""
    echo -e "${CHIEF_COLOR_CYAN}Paste:${CHIEF_NO_COLOR} Cmd+V (macOS), Ctrl+V (Linux), Right-click (PuTTY/SSH)"
  fi
  
  return 0
}

function chief.oc_vault-kubeadmin() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [cluster_name] [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Display kubeadmin password and console address for OpenShift clusters stored in Vault.
Provides interactive cluster selection with filtering capability or direct cluster specification.

${CHIEF_COLOR_BLUE}Arguments:${CHIEF_NO_COLOR}
  cluster_name    Name of the cluster to display credentials for (optional if using -l)

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -l, --list      List available clusters from Vault and prompt for selection
  -f, --filter PATTERN  Filter clusters by pattern (supports wildcards like 'ocp*' or 'prod*')
  -?, --help      Show this help

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
  ${CHIEF_COLOR_GREEN}Vault Configuration:${CHIEF_NO_COLOR} - Requires:
     • VAULT_ADDR and VAULT_TOKEN environment variables
     • CHIEF_VAULT_OC_PATH (e.g., 'secrets/openshift')
     • Vault secret at: \${CHIEF_VAULT_OC_PATH}/\${cluster_name}
       - api: OpenShift API URL
       - kubeadmin: kubeadmin password
       - console: Console URL (optional, derived from API if not present)

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Interactive cluster selection with filtering
- Displays kubeadmin username and password
- Shows API server and console URLs
- Provides ready-to-use oc login command
- Integrates with Chief authentication system
- Automatic clipboard integration (macOS: pbcopy, Linux: xclip/xsel with X11)
- Security-conscious password handling with clipboard warnings
- Cross-platform paste support (clipboard when available, display otherwise)

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.oc_vault-kubeadmin -l                # List all clusters and choose one
  chief.oc_vault-kubeadmin -l -f 'ocp*'      # List only clusters starting with 'ocp'
  chief.oc_vault-kubeadmin hub               # Display kubeadmin credentials for 'hub' cluster
  chief.oc_vault-kubeadmin prod-cluster      # Display kubeadmin credentials for 'prod-cluster'

${CHIEF_COLOR_BLUE}Security Note:${CHIEF_NO_COLOR}
Kubeadmin credentials provide cluster-admin privileges. Handle with care and ensure
your terminal session is secure when displaying these credentials."

  # Parse arguments and options
  local cluster=""
  local list_clusters=false
  local filter_pattern=""

  # Check for help first
  if [[ "$1" == "-?" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  # Parse all arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -l|--list)
        list_clusters=true
        shift
        ;;
      -f|--filter)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          filter_pattern="$2"
          shift 2
        else
          __chief_print_error "Filter pattern is required"
          echo -e "${USAGE}"
          return 1
        fi
        ;;
      -\?|--help)
        echo -e "${USAGE}"
        return 0
        ;;
      -*)
        __chief_print_error "Unknown option: $1"
        return 1
        ;;
      *)
        if [[ -z "$cluster" ]]; then
          cluster="$1"
        else
          __chief_print_error "Multiple cluster names specified. Only one cluster allowed."
          return 1
        fi
        shift
        ;;
    esac
  done

  # Handle list clusters option
  if [[ "$list_clusters" == true ]]; then
    if ! __chief_oc_select_vault_cluster "__chief_oc_display_kubeadmin_credentials" "$filter_pattern"; then
      return 1
    fi
    return 0
  fi

  # Validate cluster name is provided for non-list mode
  if [[ -z "$cluster" ]]; then
    __chief_print_error "Cluster name is required (or use -l to list available clusters)"
    echo -e "${USAGE}"
    return 1
  fi

  # Display credentials for the specified cluster
  __chief_oc_display_kubeadmin_credentials "$cluster"
  return $?
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
  -?, --help      Show this help

${CHIEF_COLOR_GREEN}Process:${CHIEF_NO_COLOR}
1. Validates namespace is in Terminating state
2. Exports namespace definition to temporary JSON file
3. Removes finalizers from the JSON definition
4. Starts oc proxy in background
5. Uses Kubernetes API to finalize namespace deletion
6. Cleans up proxy and temporary files

${CHIEF_COLOR_RED}⚠  CRITICAL WARNING:${CHIEF_NO_COLOR}
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
  chief.oc_delete-stuck-ns stuck-namespace                    # Force delete with confirmation
  chief.oc_delete-stuck-ns test-env --dry-run                # Preview what would be done
  chief.oc_delete-stuck-ns broken-ns --no-confirm            # Force delete without prompts

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
      -\?|--help) echo -e "${USAGE}"; return 0 ;;
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
    __chief_print_error "⚠  DANGER: This will forcibly remove finalizers from namespace '$namespace'"
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

# Helper function to detect ACM cluster type dynamically
__chief_detect_acm_cluster_type() {
  local cluster_name="$1"
  local api_url="$2"
  local current_user="$3"
  
  # Initialize variables
  local cluster_type="Standalone"
  local hub_name=""
  local is_acm_hub=false
  local is_acm_spoke=false
  
  # Only proceed if we have authentication
  if [[ "$current_user" == "Unknown" ]]; then
    echo "Standalone|"
    return 0
  fi
  
  # Method 1: Check for ACM Hub - look for MCH (Multicluster Hub) operator
  if oc get crd multiclusterhubs.operator.open-cluster-management.io &>/dev/null 2>&1; then
    if oc get multiclusterhub -A &>/dev/null 2>&1; then
      cluster_type="Hub"
      is_acm_hub=true
      echo "Hub|"
      return 0
    fi
  fi
  
  # Method 2: Check for ACM Spoke - look for klusterlet
  if oc get crd klusterlets.operator.open-cluster-management.io &>/dev/null 2>&1; then
    if oc get klusterlet klusterlet &>/dev/null 2>&1; then
      is_acm_spoke=true
      
      # Try to detect the hub name from various sources
      
      # Method 2a: From klusterlet status conditions
      hub_name=$(oc get klusterlet klusterlet -o jsonpath='{.status.conditions[?(@.type=="HubConnectionDegraded")].message}' 2>/dev/null | grep -o 'https://api\.[^:]*' | sed 's|https://api\.||' | cut -d. -f1 | head -1 || echo "")
      
      # Method 2b: From klusterlet spec bootstrap kubeconfig secret name
      if [[ -z "$hub_name" ]]; then
        hub_name=$(oc get klusterlet klusterlet -o jsonpath='{.spec.registrationConfiguration.bootstrapKubeConfigs.hub-kubeconfig-secret}' 2>/dev/null | grep -o 'hub-[^-]*' | sed 's|hub-||' || echo "")
      fi
      
      # Method 2c: From klusterlet spec external server URL
      if [[ -z "$hub_name" ]]; then
        hub_name=$(oc get klusterlet klusterlet -o jsonpath='{.spec.registrationConfiguration.externalServerURLs[0]}' 2>/dev/null | grep -o 'https://api\.[^:]*' | sed 's|https://api\.||' | cut -d. -f1 | head -1 || echo "")
      fi
      
      # Method 2d: From managed cluster annotations
      if [[ -z "$hub_name" ]]; then
        hub_name=$(oc get managedcluster -o jsonpath='{.items[0].metadata.annotations.open-cluster-management\.io/managed-by}' 2>/dev/null || echo "")
      fi
      
      # Method 2e: From klusterlet deployment environment variables
      if [[ -z "$hub_name" ]]; then
        hub_name=$(oc get deployment klusterlet -n open-cluster-management-agent -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="HUB_KUBEAPISERVER")].value}' 2>/dev/null | grep -o 'https://api\.[^:]*' | sed 's|https://api\.||' | cut -d. -f1 | head -1 || echo "")
      fi
      
      # Method 2f: From cluster management addon configuration
      if [[ -z "$hub_name" ]]; then
        hub_name=$(oc get configmap cluster-info -n kube-public -o jsonpath='{.data.kubeconfig}' 2>/dev/null | grep -o 'server: https://api\.[^:]*' | sed 's|server: https://api\.||' | cut -d. -f1 | head -1 || echo "")
      fi
      
      if [[ -n "$hub_name" ]]; then
        cluster_type="Managed by $hub_name"
      else
        cluster_type="Managed"
      fi
      
      echo "${cluster_type}|${hub_name}"
      return 0
    fi
  fi
  
  # If neither ACM Hub nor Spoke detected, it's standalone
  echo "Standalone|"
  return 0
}
function chief.oc_status() {
  local USAGE="${CHIEF_COLOR_CYAN}Usage:${CHIEF_NO_COLOR} $FUNCNAME [options]

${CHIEF_COLOR_YELLOW}Description:${CHIEF_NO_COLOR}
Comprehensive status report for all OpenShift clusters. Discovers clusters from Vault secrets,
checks connectivity, and reports cluster state including API/console URLs and GitOps status.

${CHIEF_COLOR_BLUE}Options:${CHIEF_NO_COLOR}
  -f, --filter PATTERN  Filter clusters by pattern (supports wildcards like 'ocp*' or 'prod*')
  -o, --output FORMAT  Output format: table, json, yaml [default: table]
  -q, --quiet          Show only essential information (online/offline status)
  -t, --timeout SEC    Timeout for connectivity checks in seconds [default: 10]
  --quick              Quick mode: faster checks with reduced details (timeout: 3s)
  -?, --help           Show this help

${CHIEF_COLOR_GREEN}Features:${CHIEF_NO_COLOR}
- Discovers clusters from Vault secrets only
- Tests connectivity to determine online/offline status
- Reports API server and console URLs when available
- Detects GitOps status: empty, gitopsified, or managed cluster
- Supports multiple output formats for automation
- Comprehensive error handling and validation

${CHIEF_COLOR_MAGENTA}GitOps Status Detection:${CHIEF_NO_COLOR}
- ${CHIEF_COLOR_GREEN}Empty:${CHIEF_NO_COLOR} No GitOps operator or ACM management detected
- ${CHIEF_COLOR_BLUE}GitOpsified:${CHIEF_NO_COLOR} OpenShift GitOps operator present (self-managed)
- ${CHIEF_COLOR_CYAN}Managed:${CHIEF_NO_COLOR} ACM/Spoke cluster (managed by external hub)

${CHIEF_COLOR_MAGENTA}Requirements:${CHIEF_NO_COLOR}
- OpenShift CLI (oc) must be installed and available in PATH
- Vault CLI must be installed and configured
- VAULT_ADDR, VAULT_TOKEN, and CHIEF_VAULT_OC_PATH environment variables
- Network access to cluster API servers for connectivity testing

${CHIEF_COLOR_YELLOW}Examples:${CHIEF_NO_COLOR}
  chief.oc_status                           # Full status report for all clusters
  chief.oc_status -f 'ocp*'                 # Status for clusters starting with 'ocp'
  chief.oc_status -o json                   # JSON output for automation
  chief.oc_status -q                        # Quick status (online/offline only)
  chief.oc_status -t 5                      # 5-second timeout for connectivity checks

${CHIEF_COLOR_BLUE}Output Format:${CHIEF_NO_COLOR}
Default table format shows:
- Cluster name and source (Vault/Local)
- Connectivity status (Online/Offline)
- API server URL
- Console URL (when available)
- GitOps status (Empty/GitOpsified/Managed)
- Additional notes and warnings"

  # Parse arguments and options
  local filter_pattern=""
  local output_format="table"
  local quiet_mode=false
  local timeout_seconds=10
  local quick_mode=false

  # Check for help first
  if [[ "$1" == "-?" ]]; then
    echo -e "${USAGE}"
    return 0
  fi

  # Parse all arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -f|--filter)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          filter_pattern="$2"
          shift 2
        else
          __chief_print_error "Filter pattern is required"
          echo -e "${USAGE}"
          return 1
        fi
        ;;
      -o|--output)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          case "$2" in
            table|json|yaml)
              output_format="$2"
              shift 2
              ;;
            *)
              __chief_print_error "Invalid output format: $2"
              echo -e "${CHIEF_COLOR_YELLOW}Valid formats:${CHIEF_NO_COLOR} table, json, yaml"
              return 1
              ;;
          esac
        else
          __chief_print_error "Output format is required"
          echo -e "${USAGE}"
          return 1
        fi
        ;;
      -q|--quiet)
        quiet_mode=true
        shift
        ;;
      -t|--timeout)
        if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
          timeout_seconds="$2"
          shift 2
        else
          __chief_print_error "Timeout must be a positive integer"
          echo -e "${USAGE}"
          return 1
        fi
        ;;
      --quick)
        quick_mode=true
        timeout_seconds=3
        shift
        ;;
      -\?|--help)
        echo -e "${USAGE}"
        return 0
        ;;
      -*)
        __chief_print_error "Unknown option: $1"
        echo -e "${USAGE}"
        return 1
        ;;
      *)
        __chief_print_error "Unexpected argument: $1"
        echo -e "${USAGE}"
        return 1
        ;;
    esac
  done

  # Validate prerequisites
  if ! command -v oc &>/dev/null; then
    __chief_print_error "OpenShift CLI (oc) is not installed or not in PATH."
    return 1
  fi

  # Check for jq if JSON/YAML output is requested
  if [[ "$output_format" == "json" || "$output_format" == "yaml" ]]; then
    if ! command -v jq &>/dev/null; then
      __chief_print_error "jq is required for $output_format output but not found."
      __chief_print_info "Install: macOS: brew install jq, Linux: apt install jq / yum install jq"
      return 1
    fi
  fi

  __chief_print_info "Discovering OpenShift clusters and checking status..."
  [[ -n "$filter_pattern" ]] && __chief_print_info "Filter: $filter_pattern"
  [[ "$quiet_mode" == true ]] && __chief_print_info "Quiet mode: showing essential information only"
  echo ""


  # Initialize results array
  local -a cluster_results=()
  local total_clusters=0
  local online_clusters=0
  local offline_clusters=0

  # Function to check cluster connectivity and get status
  __chief_check_cluster_status() {
    local cluster_name="${1:-}"
    local api_url="${2:-}"
    local source="${3:-}"
    local console_url="${4:-}"
    
    # Validate required parameters
    if [[ -z "$cluster_name" || -z "$api_url" ]]; then
      echo "ERROR: Missing required parameters" >&2
      return 1
    fi
    
    # Test connectivity using curl to check if API server is reachable
    local connectivity_test
    local api_response
    local cluster_version="-"
    
    # Use shorter timeout for quick mode
    local check_timeout="$timeout_seconds"
    if [[ "$quick_mode" == true ]]; then
      check_timeout=2
    fi
    
    api_response=$(timeout "$check_timeout" curl -s -k "$api_url/version" 2>/dev/null)
    
    if [[ $? -eq 0 && -n "$api_response" ]] && echo "$api_response" | jq -e '.major' >/dev/null 2>&1; then
      connectivity_test="online"
      
      # Skip console check in quick mode for faster processing
      if [[ "$quick_mode" == true ]]; then
        # Just use Kubernetes version in quick mode
        cluster_version=$(echo "$api_response" | jq -r '.gitVersion // "Unknown"' 2>/dev/null || echo "Unknown")
      else
        # Try to get OpenShift version from console
        local console_url_derived
        console_url_derived=$(echo "$api_url" | sed 's/api\./console-openshift-console.apps./' | sed 's/:6443//' || echo "")
        
        if [[ -n "$console_url_derived" ]]; then
          local console_response
          console_response=$(timeout "$check_timeout" curl -s -k "$console_url_derived/" 2>/dev/null)
          if [[ $? -eq 0 && -n "$console_response" ]]; then
            # Extract releaseVersion from SERVER_FLAGS in the console HTML
            local ocp_version
            ocp_version=$(echo "$console_response" | grep -o '"releaseVersion":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
            if [[ -n "$ocp_version" ]]; then
              cluster_version="$ocp_version"
            else
              # Fallback to Kubernetes version if OpenShift version not found
              cluster_version=$(echo "$api_response" | jq -r '.gitVersion // "Unknown"' 2>/dev/null || echo "Unknown")
            fi
          else
            # Fallback to Kubernetes version if console not accessible
            cluster_version=$(echo "$api_response" | jq -r '.gitVersion // "Unknown"' 2>/dev/null || echo "Unknown")
          fi
        else
          # Fallback to Kubernetes version if console URL can't be derived
          cluster_version=$(echo "$api_response" | jq -r '.gitVersion // "Unknown"' 2>/dev/null || echo "Unknown")
        fi
      fi
    else
      connectivity_test="offline"
    fi

    # If online, get detailed information
    local gitops_status="No"
    local cluster_type="Unknown"
    local current_user="N/A"
    local additional_info=""

    if [[ "$connectivity_test" == "online" ]]; then
      # Skip detailed authentication checks in quick mode
      if [[ "$quick_mode" == true ]]; then
        gitops_status="-"
        cluster_type="Quick Mode"
        current_user="N/A"
        additional_info="Quick mode - limited details"
      else
        # Get console URL if not provided
        if [[ -z "$console_url" || "$console_url" == "null" ]]; then
        # Derive console URL from API URL (standard OpenShift pattern)
        console_url=$(echo "$api_url" | sed 's/api\./console-openshift-console.apps./' | sed 's/:6443//' || echo "N/A")
      fi
      
      # Try to detect ACM/GitOps status if we have authentication
      local original_kubeconfig="${KUBECONFIG:-}"
      local temp_kubeconfig=""
      
      # Check if we're already logged into this cluster
      local current_server
      current_server=$(oc whoami --show-server 2>/dev/null || echo "")
      
      if [[ "$current_server" == "$api_url" ]]; then
        # We're already logged into this cluster, use current authentication
        current_user=$(oc whoami 2>/dev/null || echo "Unknown")
      else
        # Try to authenticate using Vault credentials (prefer kubeadmin due to cert issues)
        local kubeadmin_password
        kubeadmin_password=$(vault kv get -field=kubeadmin "${CHIEF_VAULT_OC_PATH}/${cluster_name}" 2>/dev/null)
        
        if [[ -n "$kubeadmin_password" ]]; then
          # Try to login with kubeadmin credentials (skip TLS verify due to cert issues)
          oc login --username=kubeadmin --password="$kubeadmin_password" "$api_url" --insecure-skip-tls-verify &>/dev/null
          if [[ $? -eq 0 ]]; then
            current_user=$(oc whoami 2>/dev/null || echo "Unknown")
          else
            current_user="Unknown"
          fi
        else
          # No kubeadmin password available, try with temporary kubeconfig
          temp_kubeconfig=$(mktemp /tmp/oc-status-check.XXXXXX)
          
          # Set up temporary kubeconfig with just the server URL
          cat > "$temp_kubeconfig" << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: $api_url
    insecure-skip-tls-verify: true
  name: temp-cluster
contexts:
- context:
    cluster: temp-cluster
    user: temp-user
  name: temp-context
current-context: temp-context
users:
- name: temp-user
  user: {}
EOF
          
          export KUBECONFIG="$temp_kubeconfig"
          current_user=$(oc whoami 2>/dev/null || echo "Unknown")
        fi
      fi
      
      # Restore original KUBECONFIG
      export KUBECONFIG="$original_kubeconfig"
      [[ -n "$temp_kubeconfig" ]] && rm -f "$temp_kubeconfig"
      
      # Check if we can authenticate (if current user is not "Unknown")
      if [[ "$current_user" != "Unknown" ]]; then
        # DYNAMIC ACM DETECTION - Use actual cluster resources
        local acm_detection_result
        acm_detection_result=$(__chief_detect_acm_cluster_type "$cluster_name" "$api_url" "$current_user")
        IFS='|' read -r cluster_type hub_name <<< "$acm_detection_result"
        
        # Set flags based on detected type
        local is_acm_hub=false
        local is_acm_spoke=false
        
        if [[ "$cluster_type" == "Hub" ]]; then
          is_acm_hub=true
        elif [[ "$cluster_type" == "Managed"* ]]; then
          is_acm_spoke=true
        fi
        
        # SIMPLE GitOps Detection: Check if openshift-gitops namespace exists
        local has_gitops=false
        if oc get namespace openshift-gitops &>/dev/null 2>&1; then
          has_gitops=true
          gitops_status="Yes"
        else
          gitops_status="No"
        fi
        
        # Determine the cluster type and additional info
        if [[ "$is_acm_hub" == true ]]; then
          cluster_type="Hub"
          if [[ "$has_gitops" == true ]]; then
            additional_info="ACM/MCH Hub cluster with OpenShift GitOps"
          else
            additional_info="ACM/MCH Hub cluster"
          fi
        elif [[ "$is_acm_spoke" == true ]]; then
          if [[ -n "$hub_name" ]]; then
            cluster_type="Managed by $hub_name"
          else
            cluster_type="Managed"
          fi
          if [[ "$has_gitops" == true ]]; then
            additional_info="ACM/Spoke cluster with OpenShift GitOps"
          else
            additional_info="ACM/Spoke cluster"
          fi
        else
          cluster_type="Standalone"
          if [[ "$has_gitops" == true ]]; then
            additional_info="OpenShift GitOps operator installed"
          else
            additional_info="No GitOps operator or ACM management detected"
          fi
        fi
      fi
      fi
    else
      # No authentication available, use basic detection
      gitops_status="Unknown"
      additional_info="Authentication required for detailed status"
      
      # Restore original KUBECONFIG
      export KUBECONFIG="$original_kubeconfig"
      rm -f "$temp_kubeconfig"
    fi

    # Return the result as a single line
    echo "$cluster_name|$source|$connectivity_test|$api_url|$console_url|$gitops_status|$cluster_type|$current_user|$cluster_version|$additional_info"
  }

  # Discover clusters from Vault only
  if command -v vault &>/dev/null && [[ -n "$VAULT_ADDR" && -n "$VAULT_TOKEN" && -n "$CHIEF_VAULT_OC_PATH" ]]; then
    __chief_print_info "Discovering clusters from Vault..."
    local vault_clusters
    vault_clusters=$(vault kv list -format=json "${CHIEF_VAULT_OC_PATH}" 2>/dev/null | jq -r '.[]' 2>/dev/null | sort)
    
    if [[ -n "$vault_clusters" ]]; then
      # Collect cluster information first
      local -a cluster_info=()
      while IFS= read -r cluster; do
        if [[ -n "$cluster" ]]; then
          # Apply filter first if specified (use case pattern matching for wildcards)
          if [[ -z "$filter_pattern" ]] || [[ "$cluster" == $filter_pattern ]]; then
            # Get cluster info from Vault
            local api_url console_url
            api_url=$(vault kv get -field=api "${CHIEF_VAULT_OC_PATH}/${cluster}" 2>/dev/null)
            console_url=$(vault kv get -field=console "${CHIEF_VAULT_OC_PATH}/${cluster}" 2>/dev/null)
            
            # Only process if it has an API URL
            if [[ -n "$api_url" ]]; then
              cluster_info+=("$cluster|$api_url|$console_url")
            else
              __chief_print_warn "No API URL found for Vault cluster: $cluster (skipping)"
            fi
          fi
        fi
      done <<< "$vault_clusters"
      
      # Process clusters sequentially
      for cluster_data in "${cluster_info[@]}"; do
        IFS='|' read -r cluster api_url console_url <<< "$cluster_data"
        ((total_clusters++))
        printf "Checking cluster: %s " "$cluster"
        local cluster_result
        cluster_result=$(__chief_check_cluster_status "$cluster" "$api_url" "Vault" "$console_url")
        # Extract status from result (3rd field)
        local cluster_status
        cluster_status=$(echo "$cluster_result" | cut -d'|' -f3)
        if [[ "$cluster_status" == "online" ]]; then
          ((online_clusters++))
        else
          ((offline_clusters++))
        fi
        # Store the result
        cluster_results+=("$cluster_result")
        echo "✓"
      done
    else
      __chief_print_warn "No clusters found in Vault at path: ${CHIEF_VAULT_OC_PATH}"
    fi
  else
    __chief_print_error "Vault not available or not configured - cannot discover clusters"
    __chief_print_info "Required: VAULT_ADDR, VAULT_TOKEN, and CHIEF_VAULT_OC_PATH environment variables"
    return 1
  fi

  # Display results
  if [[ $total_clusters -eq 0 ]]; then
    __chief_print_warn "No clusters found matching criteria"
    if [[ -n "$filter_pattern" ]]; then
      __chief_print_info "Filter applied: $filter_pattern"
    fi
    return 0
  fi

  echo ""
  __chief_print_success "Cluster Status Summary:"
  echo -e "${CHIEF_COLOR_BLUE}Total clusters:${CHIEF_NO_COLOR} $total_clusters"
  echo -e "${CHIEF_COLOR_GREEN}Online:${CHIEF_NO_COLOR} $online_clusters"
  echo -e "${CHIEF_COLOR_RED}Offline:${CHIEF_NO_COLOR} $offline_clusters"
  echo -e "${CHIEF_COLOR_CYAN}Source:${CHIEF_NO_COLOR} Vault"
  
  # Show quick mode notice if applicable
  if [[ "$quick_mode" == true ]]; then
    echo ""
    echo -e "${CHIEF_COLOR_YELLOW}Note:${CHIEF_NO_COLOR} Quick mode active - Hub/Spoke detection and detailed authentication skipped for faster results"
  fi
  
  echo ""

  # Output based on format
  case "$output_format" in
    json)
      __chief_output_status_json
      ;;
    yaml)
      __chief_output_status_yaml
      ;;
    table)
      __chief_output_status_table
      ;;
  esac

  return 0
}

# Helper function to output status in JSON format
__chief_output_status_json() {
  local json_start='{"clusters":['
  local json_end='],"summary":{"total":'$total_clusters',"online":'$online_clusters',"offline":'$offline_clusters'}}'
  local json_clusters=""
  local first=true

  for result in "${cluster_results[@]}"; do
    IFS='|' read -r name source status api_url console_url gitops_status cluster_type current_user cluster_version additional_info <<< "$result"
    
    if [[ "$first" == true ]]; then
      first=false
    else
      json_clusters+=","
    fi
    
    json_clusters+='{"name":"'$name'","source":"'$source'","status":"'$status'","api_url":"'$api_url'","console_url":"'$console_url'","gitops_status":"'$gitops_status'","cluster_type":"'$cluster_type'","current_user":"'$current_user'","cluster_version":"'$cluster_version'","additional_info":"'$additional_info'"}'
  done

  echo "$json_start$json_clusters$json_end" | jq '.' 2>/dev/null || echo "$json_start$json_clusters$json_end"
}

# Helper function to output status in YAML format
__chief_output_status_yaml() {
  echo "clusters:"
  for result in "${cluster_results[@]}"; do
    IFS='|' read -r name source status api_url console_url gitops_status current_user cluster_version additional_info <<< "$result"
    
    echo "  - name: $name"
    echo "    source: $source"
    echo "    status: $status"
    echo "    api_url: $api_url"
    echo "    console_url: $console_url"
    echo "    gitops_status: $gitops_status"
    echo "    current_user: $current_user"
    echo "    cluster_version: $cluster_version"
    echo "    additional_info: $additional_info"
  done
  
  echo ""
  echo "summary:"
  echo "  total: $total_clusters"
  echo "  online: $online_clusters"
  echo "  offline: $offline_clusters"
}

# Helper function to output status in table format
__chief_output_status_table() {
  if [[ "$quiet_mode" == true ]]; then
    # Quiet mode - minimal table
    printf "%-18s %-10s %-10s %-10s %-10s\n" "CLUSTER" "HUB" "SPOKE" "STATUS" "GITOPS"
    printf "%-18s %-10s %-10s %-10s %-10s\n" "--------" "---" "-----" "------" "------"
    
    for result in "${cluster_results[@]}"; do
      IFS='|' read -r name source status api_url console_url gitops_status cluster_type current_user cluster_version additional_info <<< "$result"
      
      # Determine Hub and Spoke values
      local hub_value="No"
      local spoke_value="-"
      
      if [[ "$cluster_type" == "Hub" ]]; then
        hub_value="Yes"
        spoke_value="-"
      elif [[ "$cluster_type" == "Managed by "* ]]; then
        hub_value="No"
        # Extract hub shortname from "Managed by hubname" format
        spoke_value="${cluster_type#Managed by }"
      elif [[ "$cluster_type" == "Managed" ]]; then
        hub_value="No"
        spoke_value="-"
      elif [[ "$cluster_type" == "Quick Mode" ]]; then
        hub_value="?"
        spoke_value="?"
      else
        # Unknown or other types
        hub_value="No"
        spoke_value="-"
      fi
      
      local status_icon=""
      local status_text=""
      case "$status" in
        online) 
          status_icon="\033[32m✓\033[0m"
          status_text="Online"
          ;;
        offline) 
          status_icon="\033[31m✗\033[0m"
          status_text="Offline"
          ;;
        *) 
          status_icon=""
          status_text="$status"
          ;;
      esac
      
      # Convert "Unknown" to "-" for better readability
      [[ "$gitops_status" == "Unknown" ]] && gitops_status="-"
      
      echo -e "$(printf "%-18s %-10s %-10s %s %-9s %-10s" "$name" "$hub_value" "$spoke_value" "$status_icon" "$status_text" "$gitops_status")"
    done
  else
    # Full table
    printf "%-18s %-10s %-10s %-10s %-10s %-10s\n" "CLUSTER" "HUB" "SPOKE" "STATUS" "GITOPS" "VERSION"
    printf "%-18s %-10s %-10s %-10s %-10s %-10s\n" "--------" "---" "-----" "------" "------" "-------"
    
    for result in "${cluster_results[@]}"; do
      IFS='|' read -r name source status api_url console_url gitops_status cluster_type current_user cluster_version additional_info <<< "$result"
      
      # Determine Hub and Spoke values
      local hub_value="No"
      local spoke_value="-"
      
      if [[ "$cluster_type" == "Hub" ]]; then
        hub_value="Yes"
        spoke_value="-"
      elif [[ "$cluster_type" == "Managed by "* ]]; then
        hub_value="No"
        # Extract hub shortname from "Managed by hubname" format
        spoke_value="${cluster_type#Managed by }"
      elif [[ "$cluster_type" == "Managed" ]]; then
        hub_value="No"
        spoke_value="-"
      elif [[ "$cluster_type" == "Quick Mode" ]]; then
        hub_value="?"
        spoke_value="?"
      else
        # Unknown or other types
        hub_value="No"
        spoke_value="-"
      fi
      
      local status_icon=""
      local status_text=""
      case "$status" in
        online) 
          status_icon="\033[32m✓\033[0m"
          status_text="Online"
          ;;
        offline) 
          status_icon="\033[31m✗\033[0m"
          status_text="Offline"
          ;;
        *) 
          status_icon=""
          status_text="$status"
          ;;
      esac
      
      # Convert "Unknown" to "-" for better readability
      [[ "$gitops_status" == "Unknown" ]] && gitops_status="-"
      [[ "$cluster_version" == "Unknown" ]] && cluster_version="-"
      
      echo -e "$(printf "%-18s %-10s %-10s %s %-9s %-10s %-10s" "$name" "$hub_value" "$spoke_value" "$status_icon" "$status_text" "$gitops_status" "$cluster_version")"
    done
    
  fi
}