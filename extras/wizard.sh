#!/bin/bash
set -uf -o pipefail

dialog_features() {
    local i feature_list command selected_features gpu dmi nvidia vbox

    gpu=$(lspci | grep -P "(VGA|3D)")
    dmi=$(dmidecode -t 1)

    $(echo "$gpu" | grep -qiF "NVIDIA") && nvidia="on" || nvidia="off"
    $(echo "$dmi" | grep -qiF "VirtualBox") && vbox="on" || vbox="off"

    i=0
    feature_list=()
    feature_list+=("$(( ++i ))" "Reflector to retrieve fastest pacman mirrors" "on")
    feature_list+=("$(( ++i ))" "Paccache to automatically clean pacman cache" "on")
    feature_list+=("$(( ++i ))" "Multilib repository with 32-bit software (wine, steam)" "on")
    feature_list+=("$(( ++i ))" "Zram for swap" "on")
    feature_list+=("$(( ++i ))" "Firewalld with home zone as default" "on")
    feature_list+=("$(( ++i ))" "Autologin if root filesystem is encrypted" "on")
    feature_list+=("$(( ++i ))" "Disable PC speaker (beep)" "on")
    feature_list+=("$(( ++i ))" "Man pages" "on")
    feature_list+=("$(( ++i ))" "Paru AUR helper" "on")
    [ "$nvidia" = "on" ] && feature_list+=("$(( ++i ))" "NVIDIA drivers" "$nvidia") || let ++i
    [ "$vbox" = "on" ] && feature_list+=("$(( ++i ))" "VirtualBox guest additions" "$vbox") || let ++i

    command=(dialog --stdout \
        --clear \
        --title "Extras" \
        --checklist "Select additional features." 0 0 0)
    selected_features=$("${command[@]}" "${feature_list[@]}")
    [ "$?" != "0" ] && exit

    features=0
    for feature in ${selected_features[@]}; do
        features=$(( features + ( 1<<feature ) ))
    done
}

dialog_de() {
    local i de_list command

    i=0
    de_list=()
    de_list+=("$(( ++i ))" "None")
    de_list+=("$(( ++i ))" "Plasma")

    command=(dialog --stdout \
        --clear \
        --default-item "2" \
        --title "Desktop environment" \
        --menu "Select desktop environment." 0 0 0)
    de=$("${command[@]}" "${de_list[@]}")
    [ "$?" != "0" ] && exit
    :
}

dialog_apps() {
    local i app_list command selected_apps

    i=0
    app_list=()
    [ "$de" != "0" ] && app_list+=("$(( ++i ))" "Flatpak" "on") || let ++i
    [ "$de" != "0" ] && app_list+=("$(( ++i ))" "Steam" "on") || let ++i
    [ "$de" != "0" ] && app_list+=("$(( ++i ))" "Kitty" "on") || let ++i
    app_list+=("$(( ++i ))" "Neovim" "on")
    app_list+=("$(( ++i ))" "Tmux" "on")
    app_list+=("$(( ++i ))" "Htop" "on")
    app_list+=("$(( ++i ))" "Midnight Commander" "on")
    app_list+=("$(( ++i ))" "Ripgrep" "on")

    command=(dialog --stdout \
        --clear \
        --title "Applications" \
        --checklist "Select additional applications." 0 0 0)
    selected_apps=$("${command[@]}" "${app_list[@]}")
    [ "$?" != "0" ] && exit

    apps=0
    for app in ${selected_apps[@]}; do
        apps=$(( apps + ( 1<<app ) ))
    done
}

dialog_features
dialog_de
dialog_apps