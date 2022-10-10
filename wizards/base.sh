#!/bin/bash
set -euf -o pipefail

pacman -Sy --noconfirm dialog

dialog_options="--stdout --clear"
dialog_size="10 40"

dialog_rootdevice() {
    options=$(lsblk -ndp -o NAME)
    cmd=(dialog $dialog_options \
        --no-items \
        --menu "Select root device (EFI/SWAP):" $dialog_size 0)
    rootdevice=$("${cmd[@]}" ${options})
}

dialog_pooldevices() {
    options=$(lsblk -ndp -o NAME | awk -v rootdevice="$rootdevice" '$1 != rootdevice {print $1, "off"}')
    cmd=(dialog $dialog_options \
        --separate-output \
        --no-items \
        --checklist "Select BTRFS pool devices:" $dialog_size 0)

    if [ -n "$options" ]
    then
        pooldevices=$("${cmd[@]}" ${options})
    else
        pooldevices=()
    fi
}

# Hostname

dialog_hostname() {
    cmd=(dialog $dialog_options \
        --inputbox "Enter hostname:" $dialog_size "arch")
    hostname=$("${cmd[@]}")

    [ -z "$hostname" ] && dialog_hostname
    return 0
}

# User

dialog_user() {
    cmd=(dialog $dialog_options \
        --insecure \
        --mixedform "Create user" $dialog_size 0 \
        "Username:" 1 1 "" 1 11 20 0 0 \
        "Password:" 2 1 "" 2 11 20 0 1)
    usercreds=$("${cmd[@]}")

    username=$(echo "${usercreds}" | sed -n 1p)
    userpass=$(echo "${usercreds}" | sed -n 2p)

    [ -z "$username" ] && dialog_user
    [ -z "$userpass" ] && dialog_user
    return 0
}

# Finish

dialog_confirm() {
    devices=$(echo "${rootdevice} ${pooldevices}" | tr '\n' ' ')
    dialog $dialog_options \
        --mixedform "Confirmation" 10 50 0 \
        "Root device:       " 1 1 "$rootdevice" 1 20 20 0 2 \
        "BTRFS pool devices:" 2 1 "$devices"    2 20 20 0 2 \
        "Hostname:          " 3 1 "$hostname"   3 20 20 0 2 \
        "User:              " 4 1 "$username"   4 20 20 0 2
}

dialog_rootdevice
dialog_pooldevices
dialog_hostname
dialog_user
dialog_confirm
