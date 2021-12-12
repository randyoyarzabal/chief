#!/usr/bin/env bash
# Chief Plugin File: etc_chief.plugin
# Author: Randy E. Oyarzabal
# ver. 1.0
# Functions and aliases that don't belong on any other category.

function chief.etc_create_cipher() {
    local USAGE="Usage: $FUNCNAME [file path] [--force]

Generate random 32-character cipher key for password obfuscation.
Optionally pass file path to save key and --force to overwrite if already exists.
"
    if [[ $1 == "-?" ]] || ( [[ ! -z $2 ]] && [[ $2 != '--force' ]] ); then
        echo "${USAGE}"
        return;
    fi

    local key_str
    if [[ ${PLATFORM} == "MacOS" ]]; then
        key_str=`cat /dev/random | LC_CTYPE=C tr -dc "[:alpha:]" | fold -w 32 | head -n 1`
    else
        key_str=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    fi

    if [[ -z $1 ]]; then
        echo "$key_str"
    else
        # If the file doesn't exist Or (file exists, and --force is passed).
        if [[ ! -f $1 ]] || ( [[ -f $1 ]] && [[ $2 == '--force' ]] ); then
            echo "Writing '$key_str' to $1."
            echo "$key_str" > $1
        elif [[ -f $1 ]]; then
            echo "Key file: $1 already exists."
        fi
    fi
}

function chief.etc_shared-term_create() {
    local USAGE="Usage: $FUNCNAME <screen name>

Create a named shared terminal for collaborated tasks."

    if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
        echo "${USAGE}"
        return;
    fi

    screen -d -m -S $1;
    screen -x $1;
}

function chief.etc_shared-term_connect() {
    local USAGE="Usage: $FUNCNAME <screen name>

Connect to a pre-existing shared terminal."

    if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
        echo "${USAGE}"
        return;
    fi

   screen -x $1;
}

function chief.etc_mount_share() {
    local USAGE="Usage: $FUNCNAME <share path> <mount path> <user>

Connect to a samba (SMB) share as user."

    if [[ -z $3 ]] || [[ $1 == "-?" ]]; then
        echo "${USAGE}"
        return;
    fi

    local SHARE=$1
    local MOUNT=$2

    if mount | grep "$MOUNT" > /dev/null; then
        echo "Share: ${SHARE} is already mounted at: ${MOUNT}"
    else
        mount -t cifs -o user="$3" ${SHARE} ${MOUNT}
    fi
}

function chief.etc_folder_diff() {
    local USAGE="Usage: $FUNCNAME <folder 1> <folder 2>

Find differences between 2 folders."

    if [[ -z $3 ]] || [[ $1 == "-?" ]]; then
        echo "${USAGE}"
        return;
    fi

    # Test the command then transpose parameters if needed.
    local cmd_out=`comm -23 <(ls "$1"|sort) <(ls "$2"|sort)`
    if [[ -z ${cmd_out} ]]; then
        cmd_out=`comm -23 <(ls "$2"|sort) <(ls "$1"|sort)`
    fi

    if [[ -z ${cmd_out} ]]; then
        echo "There are no differences.";
    else
        echo "${cmd_out}";
    fi
}

function chief.etc_at_run() {
    local USAGE="Usage: $FUNCNAME <time> <command to run>
see https://www.computerhope.com/unix/uat.htm for time format examples.

Run a command at a specified time.
Use the 'atq' command to see the job queue and 'atrm' to remove a job from the queue."

    if [[ -z $2 ]] || [[ $1 == "-?" ]]; then
        echo "${USAGE}"
        return;
    fi

    echo "source ${CHIEF_PATH}/chief.sh; $2" | at "$1"
}

function chief.etc_broadcast() {
    local USAGE="Usage: $FUNCNAME <message>

Send a broadcast message to all users' (currently logged-on) shell."

    if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
        echo "${USAGE}"
        return;
    fi

    wall $1
}

function chief.etc_isvalid_ip() {
    local USAGE="Usage: $FUNCNAME <IP address>

Check if an IP address is valid."

    if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
        echo "${USAGE}"
        return;
    fi

    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
           && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function chief.etc_show_spinner() {
    local USAGE="Usage: $FUNCNAME <msg> <command> <output_variable>

Display a spinner progress indicator that an operation is currently in progress."

    if [[ -z $3 ]] || [[ $1 == "-?" ]]; then
        echo "${USAGE}"
        return;
    fi

    MSG_LENGTH=$(echo -n $1 | wc -m)
    # Create a random file to hold output

    if [[ ${PLATFORM} == "MacOS" ]]; then
        tmp_file="/tmp/._`cat /dev/random | LC_CTYPE=C tr -dc "[:alpha:]" | fold -w 8 | head -n 1`"
    else
        tmp_file="/tmp/._`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`"
    fi

    # Process the command in the background until it returns (saving the output to the temp file.
    #   In the meantime, keep printing the spinner chars.
    read < <( eval "$2" > $tmp_file & echo $! ); printf "$1"; __spinner $REPLY;

    # Clear the message in-place
    start=1
    end=$MSG_LENGTH

    # Move the cursor to the left
    for ((i=$start; i<=$end; i++)); do printf "$KEYS_LEFT"; done

    # Blank the message
    for ((i=$start; i<=$end; i++)); do printf " "; done

    # Reposition the cursor to the beginning before any other writes to the screen
    for ((i=$start; i<=$end; i++)); do printf "$KEYS_LEFT"; done

    # Save output to 3rd parameter variable
    eval "$3='`cat $tmp_file`'"

    # Display the command output to the screen
    # cat $tmp_file

    # Destroy / delete the temp file
    rm -rf $tmp_file
}

function chief.etc_ask_yes_or_no() {
    local USAGE="Usage: $FUNCNAME <msg/question>

Display a yes/no user prompt and echo the response.
Returns 'yes' or 'no' string.

Use example:
   response=\$($FUNCNAME 'Do you want to continue?')
"


    if [[ -z $1 ]] || [[ $1 == "-?" ]]; then
        echo "${USAGE}"
        return;
    fi

    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

function chief.etc_prompt() {
    local USAGE="Usage: $FUNCNAME <msg/prompt>

Display a user prompt and echo response back.

Use example:
   user_name=\$($FUNCNAME 'What is your LAN ID?')"

    read -p "$1: "
    echo $REPLY
}

# HELPER FUNCTIONS
##################################################

function __timer () {
   # Usage: __timer <start | end>
   if [[ ${PLATFORM} != "MacOS" ]]; then  # Need to figure out the Mac equivalent of below
      if [[ $1 = "start" ]]; then SECONDS=0; return; fi
      if [[ $1 = "end" ]]; then echo "Task took: "`date +%T -d "1/1 + $SECONDS sec"`; fi
   fi
}

function __proper() {
    # Usage: __proper <string>
    sed 's/.*/\L&/; s/[a-z]*/\u&/g' <<<"$1"
}

function __trim() {
    # Usage: __trim <string>
    awk '{$1=$1};1'
}

function __spinner() {
    # Usage: __spinner <pid>
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [[ "$(ps a | awk '{print $1}' | grep $pid)" ]]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

function __begin {
    # Linux implementation of Cisco's "begin"
    cat | sed -n "/$1/,\$p"
}
alias be='__begin'
alias begin='__begin'

