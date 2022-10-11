#!/usr/bin/env bash
set -euf -o pipefail

while read -r line; do
    if [[ "$line" != "usr/lib/modules/"+([^/])"/pkgbase" ]]; then continue; fi

    read -r pkgbase < "/${line}"
    kver="${line#"usr/lib/modules/"}"
    kver="${kver%"/pkgbase"}"

    install -Dm0644 "/${line%"/pkgbase"}/vmlinuz" "/boot/vmlinuz-${pkgbase}"

    depmod "$kver"
    dracut -f "/boot/initramfs-${pkgbase}.img" --kver "$kver"
done
