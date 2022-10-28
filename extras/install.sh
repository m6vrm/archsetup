#!/bin/bash
set -euf -o pipefail

# Wizard

. "${archsetup_dir}/extras/wizard.sh"

# Base installer

. "${archsetup_dir}/base/install.sh"

# Chroot

cp "${archsetup_dir}/extras/chroot.sh" /mnt/chroot.sh

arch-chroot /mnt ./chroot.sh \
    "$features" \
    "$de" \
    "$apps"

rm /mnt/chroot.sh

# BTRFS snapshot

if [ -d "/mnt${config_snapshots_directory}" ]; then
    btrfs subvolume snapshot -r /mnt "/mnt${config_snapshots_directory}/${config_extras_snapshot}"
fi
