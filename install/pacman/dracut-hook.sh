#!/usr/bin/env bash
set -euf -o pipefail

command="$1"

while read -r line; do
    if [[ "$line" != "usr/lib/modules/"+([^/])"/pkgbase" ]]; then continue; fi

    read -r pkgbase < "/${line}"
    kver="${line#"usr/lib/modules/"}"
    kver="${kver%"/pkgbase"}"

    case "$command" in
        install)
            kernel-install -v add "$kver" "/${line%"/pkgbase"}/vmlinuz" ;;
        uninstall)
            kernel-install -v remove "$kver" ;;
    esac
done
