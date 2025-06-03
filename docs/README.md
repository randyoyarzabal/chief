# Introduction

Chief is BASH library system with extra features such as prompt and RSA keys management.  It allows you to quickly create, manage, and share environment variables, aliases and functions to be used personally or a in team environment.

## Automated Installation

Running this command will install Chief by cloning this repo, configure using default configuration template, and add .bashrc entries to auto-load when you start your terminal.

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/randyoyarzabal/chief/refs/heads/master/install.sh)"
```

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

All contributions are welcome. Please use the [git-flow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) method when contributing.

Helpful Reference Sites:

- [BASH Reference Page](https://www.gnu.org/software/bash/manual/bash.html)
- [Git-Flow Branching](https://nvie.com/posts/a-successful-git-branching-model/)
- [Git-Flow Cheat Sheet](https://danielkummer.github.io/git-flow-cheatsheet/)
- [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
