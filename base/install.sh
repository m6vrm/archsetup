#!/bin/bash
set -euf -o pipefail

# Recovery helpers

. "${archsetup_dir}/base/recovery.sh"

# Cleanup

umount -A --recursive /mnt || :
dmsetup remove_all -f

# Wizard

. "${archsetup_dir}/base/wizard.sh"

# Sync time

timedatectl set-timezone "$timezone"
timedatectl set-ntp true

# Partitioning

partname() { [[ "$1" = *[0-9] ]] && echo -n "${1}p${2}" || echo -n "${1}${2}"; }

[ "$recovery" = "0" ] && efi_size="$config_min_efi_size" || efi_size="$config_max_efi_size"

sgdisk --clear \
    --new=1:0:+${efi_size}  --typecode=1:ef00 \
    --new=2:0:0             --typecode=2:8300 \
    "$root_device"

for device in ${pool_devices[@]}; do
    sgdisk --clear --new=1:0:0 --typecode=1:8300 "$device"
done

# EFI

efi_part=$(partname "$root_device" 1)
mkfs.fat -F 32 -n "${config_efi_label}" "$efi_part"

# Encrypted BTRFS pool

root_part=$(partname "$root_device" 2)

all_parts=("$root_part")
for device in "${pool_devices[@]}"; do
    all_parts+=("$(partname "$device" 1)")
done

crypttab=""
if [ -n "$passphrase" ]; then
    crypt_parts=()
    for part in ${all_parts[@]}; do
        uuid=$(uuidgen)
        crypt_name="luks-${uuid}"

        echo "Encrypting partition ${part}"
        echo -n "$passphrase" | cryptsetup luksFormat --uuid "$uuid" "$part"
        echo -n "$passphrase" | cryptsetup open "$part" "$crypt_name"

        crypttab+="${crypt_name}	UUID=${uuid}	none	${config_crypttab_options}\n"
        crypt_parts+=("/dev/mapper/${crypt_name}")
    done

    root_part=${crypt_parts[0]}
    all_parts=("${crypt_parts[@]}")
fi

root_uuid=$(uuidgen)
mkfs.btrfs -f -U "$root_uuid" -L "$config_root_label" "${all_parts[@]}"

# Subvolumes

mount "$root_part" /mnt
btrfs subvolume create "/mnt/${config_root_subvolume}"
btrfs subvolume create "/mnt/${config_home_subvolume}"
umount /mnt

# Mounting

mount -o "${config_fstab_options},subvol=${config_root_subvolume}" "$root_part" /mnt

mkdir /mnt/home
mount -o "${config_fstab_options},subvol=${config_home_subvolume}" "$root_part" /mnt/home

mkdir /mnt/boot
mount -o "${config_fstab_boot_options}" "$efi_part" /mnt/boot

# Pacstrap

pacstrap -K /mnt \
    base \
    "${kernels[@]}" "${kernel_headers[@]}" \
    linux-firmware \
    "$microcode" \
    vim \
    dracut

# FS tables

genfstab -U /mnt >> /mnt/etc/fstab
printf "$crypttab" >> /mnt/etc/crypttab

# Recovery

if (( recovery & recovery_entry )); then
    create_recovery_entry "$efi_part" /mnt
fi

# Pacman hooks

mkdir -p /mnt/etc/pacman.d/hooks
mkdir -p /mnt/etc/pacman.d/scripts

cp "${archsetup_dir}/base/pacman/kernel-install-add.hook"       /mnt/etc/pacman.d/hooks/90-kernel-install-add.hook
cp "${archsetup_dir}/base/pacman/kernel-install-add-hook.sh"    /mnt/etc/pacman.d/scripts/kernel-install-add-hook.sh

cp "${archsetup_dir}/base/pacman/kernel-install-remove.hook"    /mnt/etc/pacman.d/hooks/60-kernel-install-remove.hook
cp "${archsetup_dir}/base/pacman/kernel-install-remove-hook.sh" /mnt/etc/pacman.d/scripts/kernel-install-remove-hook.sh

# Chroot

cp "${archsetup_dir}/base/chroot.sh" /mnt/chroot.sh

arch-chroot /mnt ./chroot.sh \
    "$username" \
    "$password" \
    \
    "$locale" \
    "$keymap" \
    "$timezone" \
    "$hostname" \
    \
    "${kernels[*]}" \
    "root=UUID=${root_uuid} rootflags=subvol=${config_root_subvolume} rw"

rm /mnt/chroot.sh

# BTRFS snapshot

if (( recovery & recovery_snapshot )); then
    mkdir -p "/mnt${config_snapshots_directory}"
    btrfs subvolume snapshot -r /mnt "/mnt${config_snapshots_directory}/${config_base_snapshot}"
fi
