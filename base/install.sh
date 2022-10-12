#!/usr/bin/env bash
set -x
set -euf -o pipefail

# Installer dependencies

pacman -Sy --noconfirm dialog

# Installation wizard

. "$(dirname "$0")/wizard.sh"

# Sync time

timedatectl set-timezone "$timezone"
timedatectl set-ntp true

# Partitioning

partname() { [[ $1 == *[0-9] ]] && echo -n "${$1}p${2}" || echo -n "${$1}${2}"; }

umount -A "$root_device" || :
sgdisk --clear \
    --new=1:0:+1G   --typecode=1:ef00 \
    --new=2:0:0     --typecode=2:8300 \
    "$root_device"

for device in "${pool_devices[@]}"; do
    umount -A "$device" || :
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
        uuid=$(blkid -o value -s UUID "$part")
        crypt_name="luks-${uuid}"
        crypt_part="/dev/mapper/${crypt_name}"
        crypt_parts+=("$crypt_part")
        crypttab+=$"${crypt_name}\tUUID=${uuid}\tnone\tdiscard\n"

        echo -n "$passphrase" | cryptsetup luksFormat "$part"
        echo -n "$passphrase" | cryptsetup open "$part" "$crypt_name"
    done

    root_part=${crypt_parts[0]}
    mkfs.btrfs -f -L ROOT "${crypt_parts[@]}"
else
    mkfs.btrfs -f -L ROOT "${all_parts[@]}"
fi

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

# Fstab

genfstab -U /mnt >> /mnt/etc/fstab

# Crypttab

echo "$crypttab" >> /mnt/etc/crypttab

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
