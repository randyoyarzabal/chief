---
layout: default
title: Plugin Development
description: "Complete guide to creating, managing, and sharing Chief plugins"
---

[← Back to Documentation](index.html)

# Plugin Development

Complete guide to creating custom plugins, best practices, and advanced plugin features.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## 🔧 Built-in Plugins

Chief comes with several useful plugins ready to use:

| Plugin | Commands Available | Purpose |
|--------|-------------------|---------|
| **Git** | `chief.git_*` | Enhanced git operations, branch management |
| **SSH** | `chief.ssh_*` | SSH key management, connection helpers |
| **AWS** | `chief.aws_*` | AWS credential management, S3 operations |
| **OpenShift** | `chief.oc_*` | Container platform operations (requires `oc` CLI) |
| **Vault** | `chief.vault_*` | Ansible-vault secret management |
| **Python** | `chief.python_*` | Python environment and tool helpers |
| **ETC** | `chief.etc_*` | Miscellaneous system utilities |

### Example Built-in Commands

```bash
# Git operations
chief.git_branch_cleanup    # Remove merged branches
chief.git_commit_stats     # Show commit statistics

# SSH management
chief.ssh_load_keys        # Load SSH keys
chief.ssh_test_connection  # Test SSH connections

# AWS helpers  
chief.aws_profile_switch   # Switch AWS profiles
chief.aws_s3_sync         # S3 synchronization

# Vault operations (improved UX in v3.0.2)
chief.vault_file-edit         # Create/edit encrypted vault (no auto-load)
chief.vault_file-edit --load  # Create/edit and auto-load vault
chief.vault_file-load         # Load vault into environment

# System utilities
chief.etc_spinner         # Show progress spinner
chief.etc_confirm         # Interactive confirmation prompts
```

---

## 📚 Creating Your First Plugin

### Basic Plugin Creation

```bash
# Create a new plugin
chief.plugin myproject

# This creates ~/chief_plugins/myproject_chief-plugin.sh
# Opens the file in your configured editor
```

### Plugin Template

When you create a new plugin, Chief provides this template:

```bash
#!/usr/bin/env bash
# Your custom plugin

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: $(basename "${BASH_SOURCE[0]}") must be sourced, not executed."
  exit 1
fi

echo "Chief plugin: myproject loaded."

# Your functions
function myproject.deploy() {
    echo "Deploying project..."
    # Your deployment logic
}

function myproject.backup() {
    echo "Backing up project..."
    # Your backup logic
}

# Your aliases
alias myproject.status='git status && docker ps'
alias myproject.logs='tail -f /var/log/myproject.log'
```

---

## 🎯 Plugin Best Practices

### Naming Convention

- **File name**: `{plugin-name}_chief-plugin.sh`
- **Functions**: `{plugin-name}.function_name`
- **Location**: `~/chief_plugins/` directory

### Function Naming

```bash
# ✅ Good - Namespaced with plugin name
function myproject.deploy() { ... }
function myproject.test() { ... }
function myproject.status() { ... }

# ❌ Avoid - Global namespace pollution
function deploy() { ... }
function test() { ... }
function status() { ... }
```

### Error Handling

```bash
function myproject.deploy() {
    local environment="${1:-staging}"
    
    # Validate parameters
    if [[ -z "$environment" ]]; then
        echo "Error: Environment required"
        echo "Usage: myproject.deploy <environment>"
        return 1
    fi
    
    # Check prerequisites
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker not found"
        return 1
    fi
    
    echo "Deploying to ${environment}..."
    # Your deployment logic
}
```

### Help Documentation

Add help support to your functions:

```bash
function myproject.deploy() {
    # Handle help flag
    if [[ "$1" == "-?" || "$1" == "--help" ]]; then
        cat << 'EOF'
Deploy application to specified environment

Usage: myproject.deploy <environment> [options]

Arguments:
  environment    Target environment (staging, production)

Options:
  -f, --force    Force deployment without confirmation
  -v, --verbose  Enable verbose output
  -?, --help     Show this help

Examples:
  myproject.deploy staging
  myproject.deploy production --force
EOF
        return 0
    fi
    
    # Your function logic
    local environment="${1:-staging}"
    echo "Deploying to ${environment}..."
}
```

---

## 🌟 Advanced Plugin Features

### Configuration Variables

Use plugin-specific configuration variables:

```bash
# In your plugin
function myproject.setup() {
    # Define default configuration
    export MYPROJECT_DOCKER_IMAGE="${MYPROJECT_DOCKER_IMAGE:-myapp:latest}"
    export MYPROJECT_DEPLOY_DIR="${MYPROJECT_DEPLOY_DIR:-/opt/myproject}"
    
    echo "Configuration:"
    echo "  Docker Image: $MYPROJECT_DOCKER_IMAGE"
    echo "  Deploy Directory: $MYPROJECT_DEPLOY_DIR"
}

# Users can override in their chief config
# MYPROJECT_DOCKER_IMAGE="myapp:v2.0"
# MYPROJECT_DEPLOY_DIR="/custom/path"
```

### Interactive Features

Create interactive functions using Chief's built-in utilities:

```bash
function myproject.interactive_deploy() {
    # Use Chief's confirmation utility
    if chief.etc_confirm "Deploy to production?"; then
        echo "Deploying..."
        myproject.deploy production
    else
        echo "Deployment cancelled"
    fi
}

function myproject.select_environment() {
    echo "Select environment:"
    select env in staging production development; do
        case $env in
            staging|production|development)
                myproject.deploy "$env"
                break
                ;;
            *)
                echo "Invalid selection"
                ;;
        esac
    done
}
```

### Progress Indicators

Use Chief's spinner utility for long-running operations:

```bash
function myproject.long_task() {
    echo "Starting long task..."
    
    # Start background task
    (
        sleep 10  # Simulate long task
        echo "Task completed" > /tmp/myproject_result
    ) &
    
    local task_pid=$!
    
    # Show spinner while task runs
    chief.etc_spinner "Processing..." "$task_pid"
    
    # Check result
    if [[ -f /tmp/myproject_result ]]; then
        cat /tmp/myproject_result
        rm /tmp/myproject_result
    fi
}
```

---

## 🌐 Team Plugin Development

### Plugin Repository Structure

For team collaboration, organize plugins in a Git repository:

```
my-team-plugins/
├── README.md
├── devops_chief-plugin.sh      # DevOps tools
├── frontend_chief-plugin.sh    # Frontend workflows
├── backend_chief-plugin.sh     # Backend utilities
├── testing_chief-plugin.sh     # Testing helpers
└── shared/
    ├── .chief_shared-vault     # Team secrets (encrypted)
    └── common.sh               # Shared utilities
```

### Team Plugin Example

```bash
#!/usr/bin/env bash
# DevOps Team Plugin

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: $(basename "${BASH_SOURCE[0]}") must be sourced, not executed."
  exit 1
fi

echo "Team DevOps plugin loaded"

# Load shared utilities if available
if [[ -f "${CHIEF_CFG_PLUGINS_PATH}/shared/common.sh" ]]; then
    source "${CHIEF_CFG_PLUGINS_PATH}/shared/common.sh"
fi

function devops.deploy() {
    local environment="${1:-staging}"
    local app_name="${2:-main-app}"
    
    echo "🚀 Deploying ${app_name} to ${environment}..."
    
    # Use team-specific deployment logic
    case "$environment" in
        staging)
            kubectl apply -f "k8s/staging/${app_name}.yaml"
            ;;
        production)
            if chief.etc_confirm "Deploy ${app_name} to PRODUCTION?"; then
                kubectl apply -f "k8s/production/${app_name}.yaml"
            fi
            ;;
        *)
            echo "Unknown environment: $environment"
            return 1
            ;;
    esac
}

function devops.logs() {
    local app_name="${1:-main-app}"
    local environment="${2:-staging}"
    
    echo "📋 Fetching logs for ${app_name} in ${environment}..."
    kubectl logs -f "deployment/${app_name}" -n "${environment}"
}

function devops.status() {
    echo "📊 Team infrastructure status:"
    echo "Staging:"
    kubectl get pods -n staging
    echo "Production:"
    kubectl get pods -n production
}
```

### Shared Vault Integration

Include encrypted team secrets:

```bash
function devops.load_secrets() {
    local vault_file="${CHIEF_CFG_PLUGINS_PATH}/.chief_shared-vault"
    
    if [[ -f "$vault_file" ]]; then
        echo "Loading team secrets..."
        chief.vault_file-load "$vault_file"
    else
        echo "Team vault not found: $vault_file"
    fi
}

# Auto-load secrets when plugin loads
devops.load_secrets
```

---

## 📋 Plugin Development Examples

### Example 1: Docker Workflow Plugin

```bash
#!/usr/bin/env bash
# Docker workflow plugin

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: $(basename "${BASH_SOURCE[0]}") must be sourced, not executed."
  exit 1
fi

echo "Docker workflow plugin loaded"

function docker.build() {
    local tag="${1:-latest}"
    local dockerfile="${2:-Dockerfile}"
    
    if [[ ! -f "$dockerfile" ]]; then
        echo "Error: Dockerfile not found: $dockerfile"
        return 1
    fi
    
    echo "Building Docker image with tag: $tag"
    docker build -t "$tag" -f "$dockerfile" .
}

function docker.cleanup() {
    echo "Cleaning up Docker resources..."
    docker system prune -f
    docker volume prune -f
    docker image prune -a -f
}

function docker.logs() {
    local container="${1}"
    
    if [[ -z "$container" ]]; then
        echo "Available containers:"
        docker ps --format "table {% raw %}{{.Names}}\t{{.Image}}\t{{.Status}}{% endraw %}"
        return 1
    fi
    
    docker logs -f "$container"
}

function docker.shell() {
    local container="${1}"
    local shell="${2:-bash}"
    
    if [[ -z "$container" ]]; then
        echo "Available containers:"
        docker ps --format "table {% raw %}{{.Names}}\t{{.Image}}\t{{.Status}}{% endraw %}"
        return 1
    fi
    
    docker exec -it "$container" "$shell"
}
```

### Example 2: Project Management Plugin

```bash
#!/usr/bin/env bash
# Project management plugin

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: $(basename "${BASH_SOURCE[0]}") must be sourced, not executed."
  exit 1
fi

echo "Project management plugin loaded"

# Configuration
PROJECT_BASE_DIR="${PROJECT_BASE_DIR:-$HOME/projects}"

function project.new() {
    local name="${1}"
    
    if [[ -z "$name" ]]; then
        echo "Usage: project.new <project-name>"
        return 1
    fi
    
    local project_dir="${PROJECT_BASE_DIR}/${name}"
    
    if [[ -d "$project_dir" ]]; then
        echo "Project already exists: $project_dir"
        return 1
    fi
    
    echo "Creating new project: $name"
    mkdir -p "$project_dir"
    cd "$project_dir"
    
    # Initialize git
    git init
    
    # Create basic structure
    mkdir -p {src,tests,docs}
    echo "# $name" > README.md
    echo "node_modules/" > .gitignore
    
    echo "Project created: $project_dir"
}

function project.list() {
    echo "Available projects:"
    if [[ -d "$PROJECT_BASE_DIR" ]]; then
        find "$PROJECT_BASE_DIR" -maxdepth 1 -type d -not -path "$PROJECT_BASE_DIR" | sort
    else
        echo "No projects directory found: $PROJECT_BASE_DIR"
    fi
}

function project.go() {
    local name="${1}"
    
    if [[ -z "$name" ]]; then
        project.list
        return 1
    fi
    
    local project_dir="${PROJECT_BASE_DIR}/${name}"
    
    if [[ ! -d "$project_dir" ]]; then
        echo "Project not found: $name"
        project.list
        return 1
    fi
    
    cd "$project_dir"
    echo "Switched to project: $name"
}
```

---

## 🔄 Plugin Management Commands

### Development Workflow

```bash
# Create/edit plugin
chief.plugin myproject

# Reload plugins after changes
chief.reload

# Test your plugin
myproject.deploy staging

# Find where functions are defined
chief.whereis myproject.deploy

# List all plugins
chief.plugin list
```

### Remote Plugin Sync

For team development, set up remote plugin synchronization:

```bash
# Configure remote plugins in chief.config
chief.config_set PLUGINS_TYPE "remote"
chief.config_set PLUGINS_GIT_REPO "git@github.com:yourteam/bash-plugins.git"
chief.config_set PLUGINS_PATH "$HOME/team_plugins"

# Update plugins from remote repository
chief.plugins_update
```

---

## 🧪 Testing Your Plugins

### Basic Testing

```bash
# Test plugin syntax
bash -n ~/chief_plugins/myproject_chief-plugin.sh

# Test plugin loading
source ~/chief_plugins/myproject_chief-plugin.sh
```

### Function Testing

```bash
function test_myproject_deploy() {
    echo "Testing myproject.deploy..."
    
    # Test with valid input
    if myproject.deploy staging; then
        echo "✅ Deploy test passed"
    else
        echo "❌ Deploy test failed"
    fi
    
    # Test with invalid input
    if ! myproject.deploy invalid_env; then
        echo "✅ Error handling test passed"
    else
        echo "❌ Error handling test failed"
    fi
}

# Run tests
test_myproject_deploy
```

---

## 🎯 Next Steps

- **[Configuration](configuration.html)** - Advanced setup and team collaboration
- **[User Guide](user-guide.html)** - Learn core Chief features
- **[Reference](reference.html)** - Complete command reference

### Resources

- Study built-in plugins for examples: `~/.chief/libs/core/plugins/`
- Use `chief.whereis` to understand how existing functions work
- Check the [plugin template](https://github.com/randyoyarzabal/chief/blob/main/templates/chief_plugin_template.sh) for best practices
