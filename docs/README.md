## Installation

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/install.sh)"
```

Running the above command will:

- Install Chief by cloning the git repo to `$HOME/.chief`
- Configure using a copy of default configuration template to `$HOME/.chief_config.sh`
- Add the following `$HOME/.bashrc` (file will be created if it doesn't exist)
- To start Chief, restert your terminal or `source ~/.bashrc`.

Type `chief.config` to edit the configuration to do things such as turn off the banner, hints, enable prompt customizations etc.

To un-install:

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/main/tools/uninstall.sh)"
```

## What is Chief?

Chief is BASH library system with extra features such as prompt and RSA keys management.  It allows you to quickly create, manage, and share environment variables, aliases and functions to be used personally or a in team environment.

## What can Chief do for you?

TODO

- Function namespaces

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

    ```
    git clone --depth=1 https://github.com/randyoyarzabal/chief.git $HOME/.chief
    ```

2. Make a copy a config template from the 'templates' directory. Note that it need to be placed outside the root of Chief.

    ```
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
