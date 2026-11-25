# Chief (Development Version)

**Bash Plugin Manager & Terminal Enhancement Tool**


> ⚠️ **Warning**: This is the development branch. Features may be unstable. For stable releases, use the [main branch](https://github.com/randyoyarzabal/chief/tree/main).

[![GitHub release](https://img.shields.io/badge/Download%20Release-v3.2.0-blue.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![Dev Branch](https://img.shields.io/badge/Dev%20Branch-v3.2.1--dev-orange.svg?style=social)](https://github.com/randyoyarzabal/chief/tree/dev) [![Main Branch](https://img.shields.io/badge/Stable-v3.2.0-green.svg?style=social)](https://github.com/randyoyarzabal/chief) [![Documentation](https://img.shields.io/badge/Documentation-blue)](https://chief.randyo.dev)

Chief is a lightweight, powerful Bash library system that helps you organize your shell environment through a plugin-based architecture. Think of it as a package manager for your bash functions, aliases, and tools.

## Quick Install

```bash
# Install stable version
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

**For development version**, use:

```bash
# Install development version (may be unstable)  
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/dev/tools/install.sh)"
```

**That's it!** Restart your terminal and start using Chief.

**Already have a shared plugins repo** (your plugins, settings, profile and secrets)? Install and adopt it in one step, even when the plugins live deep inside the repo:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/dev/tools/install.sh)" -- \
  --repo ssh://git@git.example.com:2222/team/common.git \
  --repo-path path/to/plugins
```

Add `--user <name>` for a team repo (one with `users/` folders). On a host that already has Chief: `chief.plugins-repo <git-url> --path <folder>`. See [Shared repo](https://chief.randyo.dev/configuration.html#shared-repo-the-same-chief-everywhere). (`--repo` is new in v3.2.1; until that's released, use the `dev` install URL as above.)

**Switching an existing install** between stable and development is just a checkout; Chief follows the branch it's on (`auto`, the default) and the banner's `tracking:` line shows it:

```bash
git -C ~/.chief switch dev    # or: main
chief.reload                  # load the switched files into this shell
chief.update                  # optional: pull the latest of that branch
```

If you forget to reload, the banner (start-up, `chief.help`, `chief.status`) points it out.

### Disconnected Installation

For environments without git connectivity:

```bash
# Download Chief, transfer to target system, then:
./tools/install.sh --local
```

## Quick Start: Portable Setup

**Real-world example**: keep your plugins, settings, start-up profile and encrypted secrets in one git repo, and get the same Chief on every host: laptop, servers, CI.

### New host: one command

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/dev/tools/install.sh)" -- \
  --repo git@github.com:yourusername/my-plugins.git \
  --repo-path bash/plugins        # where the plugins live in the repo; leave out for the repo root
```

This installs Chief, clones the repo, points the new config at it and reports what it found. Open a new terminal and it's all there. Other options: `--repo-branch <b>`, `--repo-dir <clone-dir>` (default `~/chief_plugins`), and `--user <name>` for a team repo (below). `--repo` is new in v3.2.1; until that's released, use the `dev` install URL as above.

### Host that already has Chief

```bash
chief.plugins-repo git@github.com:yourusername/my-plugins.git --path bash/plugins
```

### Then, once per host (optional)

```bash
chief.secrets_password-save   # save the secrets password once, so new shells don't prompt
chief.secrets_file-load       # load every secrets file that exists (shared and this host's)
```

### What goes in the repo

| In the plugins folder | What it is |
|---|---|
| `*_chief-plugin.sh` | your plugins (functions, aliases) |
| `.chief_shared-config.sh` | Chief settings for every host (`chief.shared-config`) |
| `.chief_shared-profile.sh` | start-up code, like a shared `~/.bash_profile` (`chief.shared-profile`) |
| `.chief_shared-secrets` | encrypted secrets (`chief.secrets_file-edit --team`) |

Host- or login-specific lines go inside those files with `chief.host_is`, for example `if chief.host_is my-laptop; then ...; fi` or `if chief.host_is 'deploy@*'; then ...; fi`.

**Sharing the repo with a team?** Each person gets a `users/<name>/` folder for their own settings, profile and secrets (the `--personal` commands create it), and sets `CHIEF_CFG_USER` to that name on each host they use (`--user <name>` when onboarding). A repo only you use doesn't need either.

See [Shared repo](https://chief.randyo.dev/configuration.html#shared-repo-the-same-chief-everywhere) for the details, and [Secrets and Vault Configuration](https://chief.randyo.dev/configuration.html#secrets-and-vault-configuration) for secrets.

### Result

- **Same plugins everywhere**: Functions, aliases, and tools sync across laptop, server, CI/CD
- **Encrypted secrets**: Secrets files travel with your setup (team + personal)
- **Zero reconfiguration**: New systems work identically after this setup
- **Version controlled**: Track changes to your shell environment

## 30-Second Demo

```bash
# See what's available
chief.help

# See available user and core plugin tools
chief.help plugins

# Find any function, alias or environment variable
chief.whereis git_status

# Create a custom function
chief.plugin mytools
```

## Key Features

- **Vault System** - Encrypt sensitive environment variables
- **Enterprise-Ready Tools** - Built-in OpenShift, SSL/TLS, SSH, AWS, Git, and Python utilities
- **Remote Plugin Sync** - Share plugins across teams via Git 
- **Git-Aware Prompts** - Beautiful, intelligent terminal prompts
- **Instant Discovery** - Find any function with `chief.whereis`
- **Zero Disruption** - Only affects Bash, won't interfere with existing setups
- **Plugin Architecture** - Organize tools into reusable, shareable plugins

## Available Plugins

Chief comes with **8 powerful plugins** providing **58+ functions** for your daily workflow:

### Discovery & Help

- `chief.help` - Interactive help system with plugin browsing
- `chief.whereis <function>` - Find any function across all plugins
- `chief.plugins-*` - Plugin management and discovery tools
- `chief.plugin enable|disable [core.|contrib.]<name>` - Enable or disable core, contrib or user plugins; `chief.plugin status` shows state

### Secrets Plugin (5 functions)

- `chief.secrets_file-edit` - Edit encrypted secrets file (Ansible Vault or GPG)
- `chief.secrets_file-load` - Load encrypted environment variables into shell
- `chief.secrets_password-save` - Save a file's password in the macOS Keychain / Linux keyring (or an obfuscated file) so loading doesn't prompt
- `chief.secrets_password-status` / `chief.secrets_password-remove` - See where the password comes from; forget a saved one

### Vault Plugin (HashiCorp) (3 functions) — opt-in

Off by default; enable with `chief.plugin enable core.vault`.

- `chief.vault_read-secret` - Read secret from HashiCorp Vault KV
- `chief.vault_write-secret` - Write secret to HashiCorp Vault KV
- `chief.vault_list-secrets` - List keys or paths in HashiCorp Vault KV

### OpenShift/Kubernetes Plugin (9 functions) — opt-in

Off by default; enable with `chief.plugin enable core.openshift`.

- `chief.oc_get-all-objects` - Comprehensive resource discovery with filtering
- `chief.oc_clean-olm` - OLM cleanup with selective targeting
- `chief.oc_clean-replicasets` - Clean up old replica sets with safety checks
- `chief.oc_show-stuck-resources` - Troubleshoot stuck resources with auto-fix
- `chief.oc_delete-stuck-ns` - Force delete terminating namespaces
- `chief.oc_approve-csrs` - Batch CSR approval with interactive mode
- `chief.oc_login` - Enhanced login with context management
- `chief.oc_vault-kubeadmin` - Display kubeadmin credentials from Vault
- `chief.oc_whoami` - Show current user, API server, and console information

### SSL/TLS Plugin (4 functions)

- `chief.ssl_create-ca` - Create certificate authorities with minimal setup
- `chief.ssl_create-tls-cert` - Generate TLS certificates signed by your CA
- `chief.ssl_renew-tls-cert` - Renew existing certificates with smart parameter extraction
- `chief.ssl_view-cert` - Analyze certificates with multiple display options
- `chief.ssl_get-cert` - Download certificates from remote servers

### SSH Plugin (3 functions)

- `chief.ssh_create-keypair` - Generate SSH key pairs with best practices
- `chief.ssh_get-publickey` - Extract and display public keys
- `chief.ssh_rm-host` - Clean known_hosts entries safely

Core SSH helpers (always available):

- `chief.ssh_load-keys` - Load your keys into ssh-agent
- `chief.ssh_status` - Show agent keys; with 3 or more keys loaded, lists hosts that don't pin a key
- `chief.ssh_host-key <host> <key>` - Pin one key to a host in `~/.ssh/config` (`IdentityFile` + `IdentitiesOnly yes`), so many loaded keys don't trigger "Too many authentication failures"

### System Utilities Plugin (17 functions)

- `chief.etc_create-bootusb` - Create bootable USB drives safely
- `chief.etc_folder-sync` - Professional rsync-based directory synchronization  
- `chief.etc_copy-dotfiles` - Copy configuration files with backup support
- `chief.etc_shared-term-create` / `-connect` - Create and join shared tmux sessions
- `chief.etc_chmod-f` / `-d` - Enhanced file permission management
- `chief.etc_mount-share` - Network share mounting utilities
- File comparison, IP validation, system prompts, and more...

### Git Plugin (17 functions)

- `chief.git_init` - Initially commit current directory to a repository
- `chief.git_clone` - Enhanced git cloning with safety checks
- `chief.git_commit` - Streamlined pull, commit, and push workflow (large-file warning; pull failures warn and continue)
- `chief.git_reset-soft` / `-hard` - Safe reset operations with dry-run support
- `chief.git_branch` - Advanced branch management
- `chief.git_config-user` - Quick user configuration setup
- Complete workflow support: tagging, amending, credential caching, URL management

### Chainguard Plugin `cg` (contrib, off by default)

Enable with `chief.plugin enable contrib.cg`. Chief ships only the wrapper: it sources your local copy of the Chainguard customer-success helper functions (set the path with `chief.config-set cg_helper_functions "<path>"`) and exposes them as `cg.*` commands, each with `-?`/`--help`:

- `cg.help` - List the cg commands
- `cg.setup_customer_org`, `cg.create_customer_yaml`, `cg.get_customer_id`, `cg.cli`, `cg.console`, `cg.tag_history`, and more
- `cg.reload` - Re-source the helper functions after pulling updates

### Python Plugin (4 functions)

- `chief.python_create-ve` - Virtual environment creation and setup
- `chief.python_start-ve` - Activate virtual environments
- `chief.python_stop-ve` - Deactivate environments
- `chief.python_ve-dep` - Install dependencies from requirements.txt

### AWS Plugin (2 functions) — opt-in

Off by default; enable with `chief.plugin enable core.aws`.

- `chief.aws_set-role` - Switch between AWS IAM roles
- `chief.aws_export-creds` - Export AWS credentials to environment

## Safe for Everyone

- **Zsh/Oh My Zsh Users**: Chief won't touch your existing setup
- **Custom Prompts**: Prompt features disabled by default
- **Easy Removal**: Clean uninstall available anytime
- **Dry-Run Safety**: Critical operations support `--dry-run` to preview changes safely

## Bug Reports & Support

Found a bug or need help? We're here to help! Please create an issue on GitHub:

**[Report an Issue](https://github.com/randyoyarzabal/chief/issues)**

When reporting issues, please include:

- **OS version**: Run `uname -a` to get your system details
- **Chief version**: Run `chief.help` to see the current version
- **Steps to reproduce**: Clear, step-by-step instructions
- **Error messages**: Copy the exact error output
- **Expected vs actual behavior**: What you expected vs what happened

This helps us quickly identify and fix issues!

## Learn More

**[Complete Documentation](https://chief.randyo.dev)** - Installation, tutorials, examples, and advanced features

**[Quick Start Guide](https://chief.randyo.dev/getting-started)** - Get productive in 5 minutes

**[Plugin Development](https://chief.randyo.dev/plugin-development)** - Create and share your own plugins

## Contributing

Contributions welcome! See our [documentation](https://chief.randyo.dev/reference#contributing) for guidelines.

## Acknowledgments

Chief is designed, written, and maintained by [Randy E. Oyarzabal](https://github.com/randyoyarzabal).

**AI-assisted development.** Portions of this project were developed and maintained with the help of AI coding assistants, specifically [Cursor](https://cursor.com) and [Claude](https://claude.com) (Anthropic). AI assistance was used for tasks such as refactoring, test authoring, bug-fixing, and documentation. All AI-generated changes are reviewed, tested, and approved by the maintainer before release, and the maintainer remains responsible for the code. Where an AI tool contributed to a commit, it is credited with a `Co-authored-by` trailer in the commit message.

## License

GNU General Public License v3.0 - see [LICENSE](LICENSE) file for details.
