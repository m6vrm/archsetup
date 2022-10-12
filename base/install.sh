#!/usr/bin/env bash
set -euf -o pipefail

# Cleanup

umount -A --recursive /mnt || :
dmsetup remove_all -f

# Dependencies

pacman -Sy --noconfirm dialog

# Wizard

. "$(dirname "$0")/wizard.sh"

# Sync time

timedatectl set-timezone "$timezone"
timedatectl set-ntp true

# Partitioning

partname() { [[ $1 == *[0-9] ]] && echo -n "${1}p${2}" || echo -n "${1}${2}"; }

sgdisk --clear \
    --new=1:0:+1G   --typecode=1:ef00 \
    --new=2:0:0     --typecode=2:8300 \
    "$root_device"

for device in "${pool_devices[@]}"; do
    sgdisk --clear --new=1:0:0 --typecode=1:8300 "$device"
done

# EFI

efi_part=$(partname "$root_device" 1)
mkfs.fat -F 32 -n EFI "$efi_part"

# BTRFS pool

root_part=$(partname "$root_device" 2)

all_parts=("$root_part")
for device in "${pool_devices[@]}"; do
    all_parts+=("$(partname "$device" 1)")
done

crypttab=""
if [[ -n "$passphrase" ]]; then
    crypt_parts=()
    for part in "${all_parts[@]}"; do
        uuid=$(uuidgen)
        crypt_name="luks-${uuid}"

        echo -n "$passphrase" | cryptsetup luksFormat --uuid "$uuid" "$part"
        echo -n "$passphrase" | cryptsetup open "$part" "$crypt_name"

        crypttab+="${crypt_name}\tUUID=${uuid}\tnone\tdiscard\n"
        crypt_parts+=("/dev/mapper/${crypt_name}")
    done

    root_part=${crypt_parts[0]}
    all_parts=("${crypt_parts[@]}")
fi

mkfs.btrfs -f -L ROOT "${all_parts[@]}"

# Subvolumes

mount "$root_part" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

# Mounting

mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@ "$root_part" /mnt

mkdir /mnt/home
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@home "$root_part" /mnt/home

mkdir /mnt/boot
mount "$efi_part" /mnt/boot

# Pacstrap

pacstrap /mnt linux linux-firmware base "$microcode" vim dracut

# FS tables

genfstab -U /mnt >> /mnt/etc/fstab
printf "$crypttab" >> /mnt/etc/crypttab

# Pacman hooks

mkdir -p /mnt/etc/pacman.d/hooks
mkdir -p /mnt/usr/local/bin

cp "$(dirname "$0")/pacman/kernel-install-add.hook" /mnt/etc/pacman.d/hooks/90-kernel-install-add.hook
cp "$(dirname "$0")/pacman/kernel-install-add-hook.sh" /mnt/usr/local/bin/kernel-install-add-hook.sh

cp "$(dirname "$0")/pacman/kernel-install-remove.hook" /mnt/etc/pacman.d/hooks/60-kernel-install-remove.hook
cp "$(dirname "$0")/pacman/kernel-install-remove-hook.sh" /mnt/usr/local/bin/kernel-install-remove-hook.sh

# Chroot

cp "$(dirname "$0")/chroot.sh" /mnt/chroot.sh

arch-chroot /mnt ./chroot.sh \
    "$username" \
    "$password" \
    "$hostname" \
    "$timezone" \
    "$kernel_options"
