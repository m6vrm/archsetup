#!/bin/bash
set -uf -o pipefail

archsetup_dir=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

. "${archsetup_dir}/config.sh"

pacman -Sy --noconfirm dialog aria2 2> /dev/null

dialog_variant() {
    local variants command

    variants=()
    variants+=("base" "Base system almost as if installed according to the ArchWiki guide")
    variants+=("extras" "Extra configuration and packages on top of the base system")

    command=(dialog --stdout \
        --clear \
        --title "Variant" \
        --default-item "extras" \
        --menu "Select installation variant." 0 0 0)
    selected_variant=$("${command[@]}" "${variants[@]}")
    [ "$?" != "0" ] && exit || :
}

dialog_variant

case "$selected_variant" in
    "base") . "${archsetup_dir}/base/install.sh" ;;
    "extras") . "${archsetup_dir}/extras/install.sh" ;;
esac
