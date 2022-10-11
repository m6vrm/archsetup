#!/usr/bin/env bash
set -euf -o pipefail

kernel_options="root=LABEL=ROOT rootflags=subvol=@ rw"

timezone=$(curl -s http://ip-api.com/line?fields=timezone)

if [[ "$(grep vendor_id /proc/cpuinfo)" == *"AuthenticAMD"* ]]; then
    microcode="amd-ucode"
else
    microcode="intel-ucode"
fi
