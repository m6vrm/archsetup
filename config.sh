#!/bin/bash
set -euf -o pipefail

# Defaults

config_timezone=$(curl -s "http://ip-api.com/line?fields=timezone")
config_locale="en_US.UTF-8"
config_keymap="us"

# Partitions

config_min_efi_size="1G"
config_max_efi_size="2G" # used for recovery boot entry

config_efi_label="EFI"
config_root_label="ROOT"

config_root_subvolume="@"
config_home_subvolume="@home"

# FS tables

config_fstab_options="noatime,compress=zstd:1,discard=async"
config_crypttab_options="x-initrd.attach,discard,no-read-workqueue,no-write-workqueue"

# Recovery

config_archlinux_url="https://archlinux.org"
config_archlinux_releases_url="https://archlinux.org/releng/releases/"
config_archlinux_releases_regex="s/^.*\(\/releng\/releases\/.*\/torrent\/\).*$/\1/p"

config_recovery_kernel_options="modprobe.blacklist=pcspkr rfkill.default_state=1"

config_snapshots_directory="/.snapshots"
config_base_snapshot="base-post-install"
config_extras_snapshot="extras-post-install"
