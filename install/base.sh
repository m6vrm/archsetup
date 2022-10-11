#!/usr/bin/env bash
set -euf -o pipefail

. "$(dirname "$0")/scripts/config.sh"
. "$(dirname "$0")/wizards/base.sh"

# Unmount /mnt

umount -R /mnt || /bin/true

# Sync time

timedatectl set-timezone $timezone
timedatectl set-ntp true

# Installer dependencies

pacman -Sy --noconfirm dialog

# Partitioning

sgdisk --clear \
    --new=1:0:+1G   --typecode=1:ef00 \
    --new=2:0:0     --typecode=2:8300 \
    "$root_device"

for device in ${pool_devices[@]}; do
    sgdisk --clear --new=1:0:0 --typecode=1:8300 "$device"
done

# Formatting

efi_part=$(lsblk -lnp -o NAME | grep "^${root_device}" | sed -n 2p)
root_part=$(lsblk -lnp -o NAME | grep "^${root_device}" | sed -n 3p)

mkfs.fat -F 32 -n EFI "$efi_part"
mkfs.btrfs -f -d single -L ROOT "$root_part"

mount "$root_part" /mnt

for device in ${pool_devices[@]}; do
    disk_part=$(lsblk -lnp -o NAME | grep "^${device}" | sed -n 2p)
    btrfs device add -f "$disk_part" /mnt
done

umount /mnt

# Mounting

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

# Copy pacman hooks

mkdir -p /mnt/etc/pacman.d/hooks
mkdir -p /mnt/usr/local/bin

cp "$(dirname "$0")/pacman/dracut-install.hook" /mnt/etc/pacman.d/hooks/90-dracut-install.hook
cp "$(dirname "$0")/pacman/dracut-uninstall.hook" /mnt/etc/pacman.d/hooks/60-dracut-uninstall.hook
cp "$(dirname "$0")/pacman/dracut-hook.sh" /mnt/usr/local/bin/dracut-hook.sh

# Chroot

cp "$(dirname "$0")/scripts/chroot.sh" /mnt/chroot.sh

arch-chroot /mnt ./chroot.sh \
    "$username" \
    "$password" \
    "$hostname" \
    "$timezone" \
    "$kernel_options"
