#!/bin/bash
set -euf -o pipefail

device() { grep -P "/dev/(sd|nvme|vd)"; }

device_names=($(lsblk -dpn -o NAME | device ))
readarray -t device_table < <(lsblk -dpn -o NAME,MODEL,SIZE | device | awk -F '\t' '{printf "%s %-10s %s\n", $1, $2, $3}')

dialog_error() {
    dialog  \
        --no-collapse \
        --title "Error" \
        --msgbox "$1" 0 0
}

dialog_root_device() {
    local device_menu command

    device_menu=()
    for i in "${!device_table[@]}"; do
        device_menu+=("$((i+1))" "${device_table[$i]}")
    done

    command=(dialog --stdout \
        --no-collapse \
        --menu "Select root device (EFI/SWAP):" 0 0 0)
    selected_device=$("${command[@]}" "${device_menu[@]}")
    root_device="${device_names[$((selected_device-1))]}"
}

dialog_pool_devices() {
    local device_checklist filtered_device_names j command selected_devices

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
        command=(dialog --stdout \
            --no-collapse \
            --checklist "Select BTRFS pool devices:" 0 0 0)
        selected_devices=$("${command[@]}" "${device_checklist[@]}")

        for selected_device in ${selected_devices[@]}; do
            pool_devices+=("${filtered_device_names[$((selected_device-1))]}")
        done
    fi
}

dialog_hostname() {
    local command

    command=(dialog --stdout \
        --no-collapse \
        --inputbox "Enter hostname:" 0 0 "arch")
    hostname=$("${command[@]}")

    if [[ -z "$hostname" ]]; then
        dialog_error "Hostname can't be empty."
        dialog_hostname
    fi
}

dialog_user() {
    local command user confirmation

    command=(dialog --stdout \
        --no-collapse \
        --insecure \
        --mixedform "Create user" 0 0 0 \
        "Username:    " 1 1 "" 1 15 30 0 0 \
        "Password:    " 2 1 "" 2 15 30 0 1 \
        "Confirmation:" 3 1 "" 3 15 30 0 1)
    user=$("${command[@]}")

    username=$(echo "${user}" | sed -n 1p)
    password=$(echo "${user}" | sed -n 2p)
    confirmation=$(echo "${user}" | sed -n 3p)

    if [[ -z "$username" || -z "$password" ]]; then
        dialog_error "Username and password can't be empty."
        dialog_user
    elif [[ "$password" != "$confirmation" ]]; then
        dialog_error "Passwords don't match."
        dialog_user
    fi
}

dialog_confirm() {
    local i fields

    i=1
    fields=()
    fields+=("Time zone:         " "$i" 1 "$timezone"    "$i" 21 30 0 2); let ++i
    fields+=("Hostname:          " "$i" 1 "$hostname"    "$i" 21 30 0 2); let ++i
    fields+=("User:              " "$i" 1 "$username"    "$i" 21 30 0 2); let ++i
    fields+=("CPU microcode:     " "$i" 1 "$microcode"   "$i" 21 30 0 2); let ++i
    fields+=("Root device:       " "$i" 1 "$root_device" "$i" 21 30 0 2); let ++i
    fields+=("BTRFS pool devices:" "$i" 1 "$root_device" "$i" 21 30 0 2); let ++i

    for device in ${pool_devices[@]}; do
        fields+=("                   " "$i" 1 "$device" "$i" 21 30 0 2); let ++i
    done

    dialog \
        --no-collapse \
        --mixedform "Continue with these parameters? The mentioned devices will be formatted." 0 0 0 \
        "${fields[@]}" 2> /dev/null
}

dialog_root_device
dialog_pool_devices
dialog_hostname
dialog_user
dialog_confirm
