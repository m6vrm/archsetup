#!/bin/bash
set -euf -o pipefail

pacman -Sy
pacman -S dialog

dialog_options="--stdout --clear"
dialog_size="10 40"

dialog_rootdisk() {
    options=$(lsblk -nd -o NAME)
    cmd=(dialog $dialog_options \
        --no-items \
        --menu "Select root (EFI/SWAP) drive:" $dialog_size 0)
    rootdisk=$("${cmd[@]}" ${options})
}

dialog_pooldisks() {
    options=$(lsblk -nd -o NAME | awk -v rootdisk="$rootdisk" '$1 != rootdisk {print $1, "off"}')
    cmd=(dialog $dialog_options \
        --separate-output \
        --no-items \
        --checklist "Select BTRFS pool drives:" $dialog_size 0)

    if [ -n "$options" ]
    then
        pooldisks=$("${cmd[@]}" ${options})
    else
        pooldisks=()
    fi
}

dialog_ucode() {
    ucode=""
    options=(1 "AMD" 2 "Intel" 3 "Skip")
    cmd=(dialog $dialog_options \
        --menu "Select CPU microcode:" $dialog_size 0)
    result=$("${cmd[@]}" ${options[@]})
    case $result in
    1) ucode="amd-ucode";;
    2) ucode="intel-ucode";;
    esac
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

    username=$(echo "${usercreds} " | sed -n 1p)
    userpass=$(echo "${usercreds} " | sed -n 2p)

    [ -z "$username" ] && dialog_user
    [ -z "$userpass" ] && dialog_user
    return 0
}

# Finish

dialog_confirm() {
    alldisks=$(echo "${rootdisk} ${pooldisks}" | tr '\n' ' ')
    dialog $dialog_options \
        --mixedform "Confirmation" 10 50 0 \
        "Root drive:       " 1 1 "$rootdisk" 1 20 20 0 2 \
        "BTRFS pool drives:" 2 1 "$alldisks" 2 20 20 0 2 \
        "CPU microcode:    " 3 1 "$ucode"    20 20 0 2 \
        "Hostname:         " 4 1 "$hostname" 4 20 20 0 2 \
        "User:             " 5 1 "$username" 5 20 20 0 2
}

dialog_rootdisk
dialog_pooldisks
dialog_ucode
dialog_hostname
dialog_user
dialog_confirm
