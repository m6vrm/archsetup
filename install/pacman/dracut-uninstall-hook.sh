#!/usr/bin/env bash
set -euf -o pipefail

while read -r line; do
    if [[ "$line" != "usr/lib/modules/"+([^/])"/pkgbase" ]]; then continue; fi

    read -r pkgbase < "/${line}"
    kver="${line#"usr/lib/modules/"}"
    kver="${kver%"/pkgbase"}"

    kernel-install -v remove "$kver"
done
