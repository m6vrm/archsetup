#!/bin/bash
set -x
set -euf -o pipefail

# Timezone

timezone=$(curl -s http://ip-api.com/line?fields=timezone)
timedatectl set-timezone $timezone

# Microcode

cpuinfo=$(grep vendor_id /proc/cpuinfo)
if [[ "$cpuinfo" == *"AuthenticAMD"* ]]; then
    microcode="amd-ucode"
else
    microcode="intel-ucode"
fi

# Dependencies

pacman -Sy --noconfirm dialog
