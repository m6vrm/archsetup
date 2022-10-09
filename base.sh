#!/bin/bash
set -euf -o pipefail

# Wizard

. ./scripts/wizard.sh

# Unmount everything

umount -R /mnt || /bin/true

# Sync time

timedatectl set-ntp true

# Partitioning

sgdisk --clear \
    --new=1:0:+1G   --typecode=1:ef00 \
    --new=2:0:0     --typecode=2:8300 \
    "$rootdisk"

for disk in $pooldisks
do
    sgdisk --clear --new=1:0:0 --typecode=1:8300 "$disk"
done

# Formatting

efipart=`lsblk -lnp -o name | grep "$rootdisk" | sed -n 2p`
rootpart=`lsblk -lnp -o name | grep "$rootdisk" | sed -n 3p`

mkfs.fat -F 32 -n EFI "$efipart"
mkfs.btrfs -f -d single -L ROOT "$rootpart"

mount "$rootpart" /mnt

for disk in $pooldisks
do
    diskpart=`lsblk -lnp -o name | grep "$disk" | sed -n 2p`
    btrfs device add "$diskpart" /mnt
done

# Mounting

btrfs sub create /mnt/@
btrfs sub create /mnt/@home
umount /mnt

# Mounting

mount -o noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@ "$rootpart" /mnt
mkdir /mnt/home
mount -o noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@home "$rootpart" /mnt/home
mkdir /mnt/boot
mount "$efipart" /mnt/boot

# Pacstrap

pacstrap /mnt base linux linux-firmware vim

# Fstab

genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab

# Chroot

cp ./scripts/chroot.sh /mnt/chroot.sh
arch-chroot /mnt ./chroot.sh
