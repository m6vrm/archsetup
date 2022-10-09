#!/bin/bash
set -x
set -euf -o pipefail

# Unmount everything

umount -R /mnt || /bin/true

# Sync time

timedatectl set-ntp true

# Partitioning

lsblk

read -p "Enter first drive name /dev/{name}: " DISK1
read -p "Enter second drive name /dev/{name}: " DISK2

DISK1="/dev/{$DISK1}"
DISK2="/dev/{$DISK2}"

sgdisk --clear \
    --new=1:0:+1G   --typecode=1:ef00 \
    --new=2:0:0     --typecode=2:8300 \
    "$DISK1"

sgdisk --clear --new=1:0:0 --typecode=1:8300 "$DISK2"

# Formatting

EFI_PARTITION=`lsblk -lnp -o name | grep "$DISK1" | sed -n 2p`
DISK1_ROOT_PARTITION=`lsblk -lnp -o name | grep "$DISK1" | sed -n 3p`
DISK2_ROOT_PARTITION=`lsblk -lnp -o name | grep "$DISK2" | sed -n 2p`

echo "EFI: $EFI_PARTITION"
echo "First root partition: $DISK1_ROOT_PARTITION"
echo "Second root partition: $DISK2_ROOT_PARTITION"

mkfs.fat -F 32 -n EFI "$EFI_PARTITION"
mkfs.btrfs -f -d single -L ROOT "$DISK1_ROOT_PARTITION" "$DISK2_ROOT_PARTITION"

# Mounting

mount "$DISK1_ROOT_PARTITION" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

mount -o noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@ "$DISK1_ROOT_PARTITION" /mnt
mkdir /mnt/home
mount -o noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@home "$DISK1_ROOT_PARTITION" /mnt/home
mkdir /mnt/boot
mount "$EFI_PARTITION" /mnt/boot

# Pacstrap

pacstrap /mnt base linux linux-firmware vim

# Fstab

genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab

# Chroot

cp ./chroot.sh /mnt/chroot.sh
arch-chroot /mnt ./chroot.sh
