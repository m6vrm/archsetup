#!/bin/bash
set -eu -o pipefail

kernel_versions=()
while read -r line; do
    if [[ "$line" = usr/lib/modules/+([^/])/vmlinuz ]]; then
        kernel_versions+=("$(basename "$(dirname "$line")")")
    else
        for kernel in /usr/lib/modules/*/vmlinuz; do
            kernel_versions+=("$(basename "$(dirname "$kernel")")")
        done

        break
    fi
done

for version in ${kernel_versions[@]}; do
    kernel-install add "$version" "/usr/lib/modules/${version}/vmlinuz"
done
