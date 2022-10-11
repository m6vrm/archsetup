#!/usr/bin/env bash
set -euf -o pipefail

device() { grep -P "/dev/(sd|nvme|vd)"; }

timezone=${timezone:-"Europe/Moscow"}
microcode=${microcode:-"intel-ucode"}

device_names=($(lsblk -dpn -o NAME | device ))
readarray -t device_table < <(lsblk -dpn -o NAME,MODEL,SIZE | device | awk -F '\t' '{printf "%s %-10s %s\n", $1, $2, $3}')

dialog_error() {
    dialog  \
        --clear \
        --no-collapse \
        --title "Error" \
        --msgbox "$1" 0 0
}

dialog_root_device() {
    local device_menu command message

    device_menu=()
    for i in "${!device_table[@]}"; do
        device_menu+=("$((i+1))" "${device_table[$i]}")
    done

    message="An EFI partition will be created on the root device "
    message+="and the remaining space will be added to the BTRFS pool.\n"
    message+="All data on the root device will be destroyed during installation."

    command=(dialog --stdout \
        --clear \
        --no-collapse \
        --title "Select root device" \
        --menu "$message" 0 0 0)
    selected_device=$("${command[@]}" "${device_menu[@]}")
    root_device="${device_names[$((selected_device-1))]}"
}

dialog_pool_devices() {
    local device_checklist filtered_device_names j command selected_devices message

    device_checklist=()
    filtered_device_names=()
    j=0
    for i in "${!device_table[@]}"; do
        if [[ $selected_device == $((i+1)) ]]; then
            continue
        fi
        device_checklist+=("$(( ++j ))" "${device_table[$i]}" "off")
        filtered_device_names+=("${device_names[$i]}")
    done

    pool_devices=()
    if [[ "$j" -gt 0 ]]; then
        message="One root volume will be created from all selected devices (including the root device).\n"
        message+="All data on the selected devices will be destroyed during installation."

        command=(dialog --stdout \
            --clear \
            --no-collapse \
            --title "Select BTRFS pool devices" \
            --checklist "$message" 0 0 0)
        selected_devices=$("${command[@]}" "${device_checklist[@]}")

        for selected_device in ${selected_devices[@]}; do
            pool_devices+=("${filtered_device_names[$((selected_device-1))]}")
        done
    fi
}

dialog_hostname() {
    local command

    command=(dialog --stdout \
        --clear \
        --no-collapse \
        --inputbox "Enter hostname:" 0 0 "arch")
    hostname=$("${command[@]}")

    if [[ -z "$hostname" ]]; then
        dialog_error "Hostname can't be empty."
        dialog_hostname
        return 0
    fi
}

dialog_username() {
    local command

    command=(dialog --stdout \
        --clear \
        --no-collapse \
        --inputbox "Enter username:" 0 0 "")
    username=$("${command[@]}")

    if [[ -z "$username" ]]; then
        dialog_error "Username can't be empty."
        dialog_username
        return 0
    fi
}

dialog_password() {
    local command confirmation

    command=(dialog --stdout \
        --clear \
        --no-collapse \
        --passwordbox "Enter password:" 0 0 "")
    password=$("${command[@]}")

    if [[ -z "$password" ]]; then
        dialog_error "Password can't be empty."
        dialog_password
        return 0
    fi

    command=(dialog --stdout \
        --clear \
        --no-collapse \
        --passwordbox "Confirm password:" 0 0 "")
    confirmation=$("${command[@]}")

    if [[ "$password" != "$confirmation" ]]; then
        dialog_error "Passwords don't match."
        dialog_password
        return 0
    fi
}

dialog_confirm() {
    local i fields message

    i=1
    fields=()
    fields+=("Hostname:          " "$i" 1 "$hostname"       "$i" 21 30 0 2); let ++i
    fields+=("User:              " "$i" 1 "$username"       "$i" 21 30 0 2); let ++i
    fields+=("CPU microcode:     " "$i" 1 "$microcode"      "$i" 21 30 0 2); let ++i
    fields+=("Time zone:         " "$i" 1 "$timezone"       "$i" 21 30 0 2); let ++i
    fields+=("Kernel options:    " "$i" 1 "$kernel_options" "$i" 21 30 0 2); let ++i
    fields+=("Root device:       " "$i" 1 "$root_device"    "$i" 21 30 0 2); let ++i
    fields+=("BTRFS pool devices:" "$i" 1 "$root_device"    "$i" 21 30 0 2); let ++i

    for device in ${pool_devices[@]}; do
        fields+=("                   " "$i" 1 "$device" "$i" 21 30 0 2); let ++i
    done

    message="Please review installation options.\n"
    message+="The root device and the BTRFS pool devices will be formatted right away."

    dialog \
        --clear \
        --no-collapse \
        --title "Confirmation" \
        --mixedform "$message" 0 0 0 \
        "${fields[@]}" 2> /dev/null
}

dialog_root_device
dialog_pool_devices
dialog_hostname
dialog_username
dialog_password
dialog_confirm

clear
