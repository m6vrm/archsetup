#!/bin/bash
set -uf -o pipefail

i=-1 # de_none should be == 0
de_none=$(( ++i ))
de_plasma=$(( ++i ))
de_xfce=$(( ++i ))

dialog_features() {
    local i feature_list command selected_features gpu dmi nvidia vbox

    gpu=$(lspci | grep -P "(VGA|3D)")
    dmi=$(dmidecode -t 1)

    $(echo "$gpu" | grep -qiF "NVIDIA") && nvidia="on" || nvidia="off"
    $(echo "$dmi" | grep -qiF "VirtualBox") && vbox="on" || vbox="off"

    i=0
    feature_list=()
    feature_list+=("$(( ++i ))" "Disable PC speaker (beep)" "on")
    feature_list+=("$(( ++i ))" "Zsh as default login shell" "on")
    feature_list+=("$(( ++i ))" "Zram for swap" "on")
    feature_list+=("$(( ++i ))" "Multilib repository with 32-bit software (wine, steam)" "on")
    feature_list+=("$(( ++i ))" "Autologin if root filesystem is encrypted" "on")
    feature_list+=("$(( ++i ))" "Reflector to retrieve fastest pacman mirrors" "on")
    feature_list+=("$(( ++i ))" "Paccache to automatically clean pacman cache" "on")
    feature_list+=("$(( ++i ))" "Firewalld with home zone as default" "on")
    feature_list+=("$(( ++i ))" "Man pages and TLDR" "on")
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
    de_list+=("$(( ++i ))" "Xfce")

    command=(dialog --stdout \
        --clear \
        --default-item "1" \
        --title "Desktop environment" \
        --menu "Select desktop environment." 0 0 0)
    de=$("${command[@]}" "${de_list[@]}")
    [ "$?" != "0" ] && exit

    let --de || :
}

dialog_apps() {
    local i app_list command selected_apps

    i=0
    app_list=()
    app_list+=("$(( ++i ))" "Unix Devtools (git, ssh, rsync, etc)" "on")
    app_list+=("$(( ++i ))" "C++ Devtools (cmake, clang, ninja, etc)" "on")
    app_list+=("$(( ++i ))" "Pass" "on")
    app_list+=("$(( ++i ))" "Neovim" "on")
    app_list+=("$(( ++i ))" "Tmux" "on")
    app_list+=("$(( ++i ))" "Htop" "on")
    app_list+=("$(( ++i ))" "Midnight Commander" "on")
    app_list+=("$(( ++i ))" "Fzf" "on")
    app_list+=("$(( ++i ))" "Ripgrep" "on")
    app_list+=("$(( ++i ))" "Ffmpeg" "on")

    # DE apps
    [ "$de" != "$de_none" ] && app_list+=("$(( ++i ))" "Firefox" "on") || let ++i
    [ "$de" != "$de_none" ] && app_list+=("$(( ++i ))" "Kitty" "on") || let ++i
    [ "$de" != "$de_none" ] && app_list+=("$(( ++i ))" "VS Code - OSS" "on") || let ++i
    [ "$de" != "$de_none" ] && app_list+=("$(( ++i ))" "Steam" "on") || let ++i
    [ "$de" != "$de_none" ] && app_list+=("$(( ++i ))" "Lutris" "on") || let ++i
    [ "$de" != "$de_none" ] && app_list+=("$(( ++i ))" "LibreOffice" "on") || let ++i
    [ "$de" != "$de_none" ] && app_list+=("$(( ++i ))" "Qt Creator" "on") || let ++i
    [ "$de" != "$de_none" ] && app_list+=("$(( ++i ))" "qBittorrent" "on") || let ++i

    # KDE apps
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "Dolphin (file manager)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "Konsole (terminal emulator)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "Kate (text editor)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "Krunner (launcher)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "KCalc (calculator)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "KDE Connect (wireless file sharing)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "Gwenview (image viewer)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "Okular (document viewer)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "Ark (file archiver)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "Spectacle (screenshot capture)" "on") || let ++i
    [ "$de" = "$de_plasma" ] && app_list+=("$(( ++i ))" "KDiff3 (diff tool)" "on") || let ++i

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
