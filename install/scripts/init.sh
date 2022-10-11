#!/usr/bin/env bash
set -euf -o pipefail

# Unmount /mnt

umount -R /mnt || /bin/true

# Sync time

timezone=$(curl -s http://ip-api.com/line?fields=timezone)

timedatectl set-timezone $timezone
timedatectl set-ntp true

# Microcode

cpuinfo=$(grep vendor_id /proc/cpuinfo)
if [[ "$cpuinfo" == *"AuthenticAMD"* ]]; then
    microcode="amd-ucode"
else
    microcode="intel-ucode"
fi

# Installer dependencies

pacman -Sy --noconfirm dialog
