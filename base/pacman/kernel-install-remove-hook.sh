#!/bin/bash
set -euf -o pipefail

while read -r vmlinuz; do
    kernel-install remove "$(basename "$(dirname "$vmlinuz")")"
done
