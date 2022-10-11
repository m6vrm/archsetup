#!/usr/bin/env bash
set -euf -o pipefail

username=$1
password=$2
hostname=$3
timezone=$4
kernel_options=$5

# Disable root

passwd -l root

# Locale

sed -i "s/#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=us" >> /etc/vconsole.conf

# System time

ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
hwclock --systohc

# Host

echo "$hostname" >> /etc/hostname

cat >> /etc/hosts <<EOF
127.0.0.1	localhost
::1			localhost
127.0.1.1	${hostname}
EOF

# Packages

pacman -Sy --noconfirm btrfs-progs sudo networkmanager

# Services

systemctl enable systemd-boot-update

systemctl enable NetworkManager
systemctl mask NetworkManager-wait-online

# User

useradd -m -G wheel "$username"
echo "${username}:${password}" | chpasswd

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Bootloader

bootctl install

cat > /boot/loader/loader.conf <<EOF
timeout 3
console-mode auto
editor yes
EOF

# Dracut

cat > /etc/dracut.conf.d/00-options.conf <<EOF
hostonly="yes"
hostonly_cmdline="no"
early_microcode="yes"
compress="zstd"
reproducible="yes"
EOF

# Trigger initramfs and bootloader entries generation

echo "$kernel_options" > /etc/kernel/cmdline
pacman -S --noconfirm linux
rm /etc/kernel/cmdline

# Remove this script

rm -- "$0"

# Last but not least step

echo
echo "##########################"
echo "# Installation complete! #"
echo "##########################"
echo
