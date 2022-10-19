#!/bin/bash
set -euf -o pipefail

create_recovery_entry() {
    local efi_part root archiso_urls archiso_url archiso

    efi_part=$1
    root="${2:-""}"

    mkdir -p "${root}/boot/recovery"
    mkdir -p "${root}/boot/loader/entries"

    # Parse ISO torrent link
    archiso_urls=$(curl -sL "$config_archlinux_releases_url" | sed -n "$config_archlinux_releases_regex")
    archiso_url=$(echo "$archiso_urls" | head -n 1)

    # Download ISO
    aria2c \
        --seed-time 0 \
        --follow-torrent mem \
        --file-allocation none \
        --dir "${root}/boot/recovery" \
        "${config_archlinux_url}${archiso_url}"

    # Rename ISO
    find "${root}/boot/recovery" -name "archlinux-*.iso" -execdir mv {} archlinux.iso \;

    # Copy initramfs and kernel from ISO to our $BOOT
    archiso=$(mktemp -d)
    mount "${root}/boot/recovery/archlinux.iso" "$archiso"

    cp "${archiso}/arch/boot/intel-ucode.img"              "${root}/boot/recovery/intel-ucode.img"
    cp "${archiso}/arch/boot/amd-ucode.img"                "${root}/boot/recovery/amd-ucode.img"
    cp "${archiso}/arch/boot/x86_64/initramfs-linux.img"   "${root}/boot/recovery/initramfs-linux.img"
    cp "${archiso}/arch/boot/x86_64/vmlinuz-linux"         "${root}/boot/recovery/vmlinuz-linux"

    umount "$archiso"

    # Create bootloader entry
    cat > "${root}/boot/loader/entries/recovery.conf" <<EOF
title Arch Linux Recovery
linux /recovery/vmlinuz-linux
initrd /recovery/intel-ucode.img
initrd /recovery/amd-ucode.img
initrd /recovery/initramfs-linux.img
options img_dev=${efi_part} img_loop=/recovery/archlinux.iso copytoram ${config_recovery_kernel_options}
EOF
}
