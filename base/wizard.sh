#!/bin/bash
set -uf -o pipefail

i=0
recovery_entry=$(( 1 << ++i ))
recovery_snapshot=$(( 1 << ++i ))

# Defaults

timezone="$config_timezone"
locale="$config_locale"
keymap="$config_keymap"

cpu_vendor=$(grep -F "vendor_id" /proc/cpuinfo)
echo "$cpu_vendor" | grep -qF "AuthenticAMD" && microcode="amd-ucode" || microcode="intel-ucode"

# Devices

valid_device() { grep -P "/dev/(sd|nvme|vd)" | grep -vF "iso9660"; }

device_names=($(lsblk -dpn -o NAME,FSTYPE | valid_device | awk '{print $1}'; ))
device_table=$(lsblk -dpn -o NAME,MODEL,SIZE,FSTYPE | valid_device | awk -F '\t' '{printf "%s %-10s %s\n", $1, $2, $3}')
readarray -t device_table < <(echo "$device_table")

# Dialogs

dialog_error() {
    dialog  \
        --clear \
        --title "Error" \
        --msgbox "$1" 0 0
}

dialog_root_device() {
    local device_menu command message

    device_menu=()
    for i in ${!device_table[@]}; do
        device_menu+=("$(( i + 1 ))" "${device_table[$i]}")
    done

    message="An EFI partition will be created on the root device "
    message+="and the remaining space will be added to the BTRFS pool.\n"
    message+="All data on the root device will be destroyed during installation."

    command=(dialog --stdout \
        --clear \
        --title "Select root device" \
        --menu "$message" 0 0 0)
    selected_device=$("${command[@]}" "${device_menu[@]}")
    [ "$?" != "0" ] && exit

    root_device="${device_names[$((selected_device-1))]}"
}

dialog_pool_devices() {
    local device_checklist filtered_device_names j command selected_devices message

    device_checklist=()
    filtered_device_names=()
    j=0
    for i in "${!device_table[@]}"; do
        [ $selected_device = "$(( i + 1 ))" ] && continue

        device_checklist+=("$(( ++j ))" "${device_table[$i]}" "off")
        filtered_device_names+=("${device_names[$i]}")
    done

    pool_devices=()

    if [ "$j" = "0" ]; then
        return 0
    fi

    message="Single root volume will be created from all selected devices (including the root device).\n"
    message+="All data on the selected devices will be destroyed during installation."

    command=(dialog --stdout \
        --clear \
        --no-collapse \
        --title "Select BTRFS pool devices" \
        --checklist "$message" 0 0 0)
    selected_devices=$("${command[@]}" "${device_checklist[@]}")
    [ "$?" != "0" ] && exit

    for selected_device in ${selected_devices[@]}; do
        pool_devices+=("${filtered_device_names[$((selected_device-1))]}")
    done
}

dialog_encryption() {
    local command confirmation

    command=(dialog --stdout \
        --clear \
        --insecure \
        --title "Disk encryption" \
        --passwordbox "Enter encryption passphrase (or leave empty to skip encryption):" 0 0 "")
    passphrase=$("${command[@]}")
    [ "$?" != "0" ] && exit

    if [ -z "$passphrase" ]; then
        return 0
    fi

    command=(dialog --stdout \
        --clear \
        --insecure \
        --title "Disk encryption" \
        --passwordbox "Confirm encryption passphrase:" 0 0 "")
    confirmation=$("${command[@]}")
    [ "$?" != "0" ] && exit

    if [ "$passphrase" != "$confirmation" ]; then
        dialog_error "Passphrases don't match."
        dialog_encryption
        return 0
    fi
}

dialog_kernels() {
    local i kernel_list command selected_kernels

    i=0
    kernel_list=()
    kernel_list+=("$(( ++i ))" "Linux Stable" "off")
    kernel_list+=("$(( ++i ))" "Linux LTS" "on")
    kernel_list+=("$(( ++i ))" "Linux Zen" "on")
    kernel_list+=("$(( ++i ))" "Linux Hardened" "off")

    command=(dialog --stdout \
        --clear \
        --title "Kernels" \
        --checklist "Select Linux kernels to install." 0 0 0)
    selected_kernels=$("${command[@]}" "${kernel_list[@]}")
    [ "$?" != "0" ] && exit

    kernels=()
    kernel_headers=()
    for selected_kernel in ${selected_kernels[@]}; do
        i=0
        kernel="linux"
        case "$selected_kernel" in
            "$(( ++i ))") kernel="linux" ;;
            "$(( ++i ))") kernel="linux-lts" ;;
            "$(( ++i ))") kernel="linux-zen" ;;
            "$(( ++i ))") kernel="linux-hardened" ;;
        esac

        kernels+=("$kernel")
        kernel_headers+=("${kernel}-headers")
    done

    if [ -z "${kernels[@]}" ]; then
        dialog_error "Please select at least one kernel."
        dialog_kernels
        return 0
    fi
}

dialog_hostname() {
    local command

    command=(dialog --stdout \
        --clear \
        --title "Machine" \
        --inputbox "Enter hostname:" 0 0 "arch")
    hostname=$("${command[@]}")
    [ "$?" != "0" ] && exit

    if [ -z "$hostname" ]; then
        dialog_error "Hostname can't be empty."
        dialog_hostname
        return 0
    fi
}

dialog_username() {
    local command

    command=(dialog --stdout \
        --clear \
        --title "User" \
        --inputbox "Enter user name:" 0 0 "")
    username=$("${command[@]}")
    [ "$?" != "0" ] && exit

    if [ -z "$username" ]; then
        dialog_error "User name can't be empty."
        dialog_username
        return 0
    fi
}

dialog_password() {
    local command confirmation

    command=(dialog --stdout \
        --clear \
        --insecure \
        --title "User" \
        --passwordbox "Enter user password:" 0 0 "")
    password=$("${command[@]}")
    [ "$?" != "0" ] && exit

    if [ -z "$password" ]; then
        dialog_error "Password can't be empty."
        dialog_password
        return 0
    fi

    command=(dialog --stdout \
        --clear \
        --insecure \
        --title "User" \
        --passwordbox "Confirm user password:" 0 0 "")
    confirmation=$("${command[@]}")
    [ "$?" != "0" ] && exit

    if [ "$password" != "$confirmation" ]; then
        dialog_error "Passwords don't match."
        dialog_password
        return 0
    fi
}

dialog_recovery() {
    local i option_list command selected_options

    i=0
    option_list=()
    option_list+=("$(( ++i ))" "Recovery bootloader entry" "on")
    option_list+=("$(( ++i ))" "BTRFS snapshot after installation" "on")

    command=(dialog --stdout \
        --clear \
        --title "Recovery" \
        --checklist "Select available recovery options." 0 0 0)
    selected_options=$("${command[@]}" "${option_list[@]}")
    [ "$?" != "0" ] && exit

    recovery=0
    for option in ${selected_options[@]}; do
        recovery=$(( recovery + (1 << option) ))
    done
}

dialog_confirm() {
    local i fields message width encryption_status recovery_status

    [ -n "$passphrase" ] && encryption_status="Enabled" || encryption_status="Disabled"
    (( recovery & recovery_entry )) && recovery_status="Enabled" || recovery_status="Disabled"

    width=40

    i=0
    fields=()
    fields+=("User:               " "$(( ++i ))" 1 "$username"              "$i" 22 "$width" 0 2)
    fields+=("Encryption:         " "$(( ++i ))" 1 "$encryption_status"     "$i" 22 "$width" 0 2)
    fields+=("Recovery boot entry:" "$(( ++i ))" 1 "$recovery_status"       "$i" 22 "$width" 0 2)
    fields+=("Hostname:           " "$(( ++i ))" 1 "$hostname"              "$i" 22 "$width" 0 2)
    fields+=("CPU microcode:      " "$(( ++i ))" 1 "$microcode"             "$i" 22 "$width" 0 2)
    fields+=("Time zone:          " "$(( ++i ))" 1 "$timezone"              "$i" 22 "$width" 0 2)
    fields+=("Locale:             " "$(( ++i ))" 1 "$locale"                "$i" 22 "$width" 0 2)
    fields+=("Kernels:            " "$(( ++i ))" 1 "${kernels[*]}"          "$i" 22 "$width" 0 2)
    fields+=("BTRFS pool devices: " "$(( ++i ))" 1 "${root_device} (root)"  "$i" 22 "$width" 0 2)

    for device in ${pool_devices[@]}; do
        fields+=("                    " "$(( ++i ))" 1 "$device" "$i" 22 "$width" 0 2)
    done

    [ -z "$passphrase" ] && formatted="formatted" || formatted="encrypted and formatted"

    message="Please review installation options.\n"
    message+="The BTRFS pool devices will be ${formatted} right away."

    dialog \
        --clear \
        --title "Confirmation" \
        --mixedform "$message" 0 0 0 \
        "${fields[@]}" 2> /dev/null
}

dialog_root_device
dialog_pool_devices
dialog_encryption
dialog_kernels
dialog_hostname
dialog_username
dialog_password
dialog_recovery
dialog_confirm
