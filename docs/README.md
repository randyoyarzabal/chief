## Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

Running the `install` command will:

- Install Chief by cloning the git repo to `$HOME/.chief`
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

## What is Chief?

Chief is BASH library system to help organize functions, aliases, and environment variables with extra features such as prompt customization and SSH keys management.  It also installs  with various function utilities relating to git, SSL, openshift, vault, etc. Once installed, checkout `chief.[tab]` to explore what's available.

## What can Chief do for you?

TODO

## Configuration Options

TODO: Table of config options

## Built-in Plug-ins

TODO: Table of core plugins

## Configurable Features

- Management of BASH variables, aliases and functions
- Automated reload of edited files
- RSA Key Management
- Prompt Management
  - Git prompt
  - Colored prompt
  - Working directory

## Manual Installation

1. Clone the repo to your desired location, for example: `$HOME/.chief`

    ```bash
    git clone --depth=1 https://github.com/randyoyarzabal/chief.git $HOME/.chief
    ```

2. Make a copy a config template from the 'templates' directory. Note that it need to be placed outside the root of Chief.

    ```bash
    cp templates/chief_config_template.sh ~/.chief_config.sh
    ```

    Change the configuration to suit.

3. Define the following variables and source call in your start-up script (.bash_profile for example).

    For example:

    ```bash
    # Chief Environment
    CHIEF_CONFIG="$HOME/.chief_config.sh"                                                                                                          
    CHIEF_PATH="$HOME/.chief"
    source ${CHIEF_PATH}/chief.sh
    ```

4. That's it. You're ready to use Chief! Restart your terminal.

## Post Installation

Experiment and try the following commands:

- `chief.[tab]` to see available built-in commands.
- `chief.config` to edit your config.
- `chief.bash_profile` to edit your bash start-up file.
- `chief.plugin` to edit the default user plugin.
- `chief.plugin [user plug-in name]` to edit a user plugin.

## Contribute

All contributions are welcome. Feel free to create your own branch and pull-request against main.

Helpful Reference Sites:

- [BASH Reference Page](https://www.gnu.org/software/bash/manual/bash.html)
