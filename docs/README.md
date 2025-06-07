[![GitHub release](https://img.shields.io/badge/Download-Release%20v2.0-lightgrey.svg?style=social)](https://github.com/randyoyarzabal/chief/releases/latest) [![GitHub commits (since latest release)](https://img.shields.io/github/commits-since/randyoyarzabal/chief/latest.svg?style=social)](https://github.com/randyoyarzabal/chief/commits/master)

## What is Chief?

Chief is a Bash library system designed to help organize functions, aliases, and environment variables through "plug-ins."  It has additional features, including prompt customization and private SSH key management. It also installs various utility functions related to Git, SSL, OpenShift, Vault, etc. Once installed, checkout `chief.[tab]` to explore what's available.

## Getting Started

Simply run this command on your terminal to install:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

Running the `install` command will:

- Install latest version of Chief by cloning the git repo to `$HOME/.chief`
- Configure using a copy of default configuration template to `$HOME/.chief_config.sh`
- Add the library loading lines to `$HOME/.bashrc` (file will be created if it doesn't exist)
- To start Chief, restart your terminal or `source ~/.bashrc`.

Type `chief.config` to edit the configuration to do things such as turn off the banner, hints, enable prompt customizations etc.

To uninstall:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/uninstall.sh)"
```

Or

`chief.uninstall` within the tool.

Running the `uninstall` command will:

- Remove the installation from `$HOME/.chief`
- Backup `$HOME/.chief_config.sh` to `$HOME/.chief_config.sh.backup`
- Remove `$HOME/.chief_config.sh`
- Remove the library loading lines from `$HOME/.bashrc`
- Restart your terminal to complete uninstallation.

## What's next?

Explore the following commands:

- `chief.[tab]` to see available built-in commands.
- `chief.config` to edit the configuration and explore features.
- `chief.update` to pull the latest version or set `CHIEF_CFG_AUTOCHECK_UPDATES=true`
- `chief.bash_profile` to edit your .bash_profile file.
- `chief.bashrc` to edit your .bashrc file.
- `chief.* -?` to display the help-text for any chief command.
- `type chief.*` on any command if you're curious or want to reuse the internal functions.

Plugin-related:

- `chief.plugin` to edit the default plugin.
- `chief.plugin [plug-in name]` to create/edit a plugin. Don't worry, if the plugin doesn't it can automatically create it.
- `chief.plugins` to cd into your plugins directory.
- `chief.plugins_update` to update/load from git repository when `CHIEF_CFG_PLUGINS_TYPE='remote'`.
- `chief.plugin -?` to find your plugin name.

**Notes:** 

- `chief.plugin`, `chief.bash_profile`, and `chief.bashrc` will automatically load (source) if changes are detected.  There's no need to restart your terminal!
- You can enable the above text in Chief by setting `CHIEF_CFG_HINTS=true`

**Don't have a git-aware prompt?** Try Chief's custom prompt, set `CHIEF_CFG_PROMPT=true`.

**Want to load and manage plugins from a git repo?** Enable remote repo by setting `CHIEF_CFG_PLUGINS_TYPE='remote'` and set other git options in the configuration.

**Tired of passing SSH keys when logging to remote hosts?**  Try Chief's SSH key auto-loader, set `CHIEF_CFG_RSA_KEYS_PATH=<ssh keys path>`.  Just ensure that your private keys end with `*.rsa`; you can also use symbolic links.  This allows you to select and choose what you want to load.

**Don't want to keep typing `chief.`?**  Try setting the Chief alias. For example, `CHIEF_CFG_ALIAS=cf`.

## Configurable Features

- Management of Bash variables, aliases, and functions
  - Support for local and remote git plugins
  - Auto creation of plugin
- Automated reload of edited files
- Private SSH key auto-loading
- Custom prompt if you're not already using one (i.e., Oh-My-Bash)
  - Git prompt
  - Colored prompt
  - Working directory

## Manual Installation

1. Clone the repo to your desired location, for example: `$HOME/.chief`

    ```bash
    git clone --depth=1 https://github.com/randyoyarzabal/chief.git $HOME/.chief
    ```

2. Make a copy a config template from the 'templates' directory. Note that it needs to be placed outside the root of Chief.

    ```bash
    cp templates/chief_config_template.sh ~/.chief_config.sh
    ```

    Modify the configuration with `chief.config` to suit your needs.

3. Define the following variables and source call in your start-up script (.bash_profile, for example).

    For example:

    ```bash
    # Chief Environment
    CHIEF_CONFIG="$HOME/.chief_config.sh"                                                                                                          
    CHIEF_PATH="$HOME/.chief"
    source ${CHIEF_PATH}/chief.sh
    ```

4. That's it. You're ready to use Chief! Restart your terminal.

## Configuration Options

TODO: Table of config options

## Built-in Plug-ins

TODO: Table of core plugins

## Contribute

All contributions are welcome. Feel free to create your own branch and pull-request against main.

Helpful Reference Sites:

- [Bash Reference Page](https://www.gnu.org/software/bash/manual/bash.html)
