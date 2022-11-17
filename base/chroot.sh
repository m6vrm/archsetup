#!/bin/bash
set -euf -o pipefail

username=$1
password=$2

locale=$3
keymap=$4
timezone=$5
hostname=$6

kernels=$7
kernel_options=$8

pacman -Sy

# Locale

sed -i "/${locale}/s/^#//" /etc/locale.gen
locale-gen

echo "LANG=${locale}" > /etc/locale.conf
echo "KEYMAP=${keymap}" > /etc/vconsole.conf

# System time

ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
hwclock --systohc

# Host

echo "$hostname" > /etc/hostname

grep -qF "127.0.1.1	${hostname}" /etc/hosts || cat >> /etc/hosts <<EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	${hostname}
EOF

# Packages

pacman -S --noconfirm base-devel btrfs-progs networkmanager

# Services

systemctl enable systemd-boot-update.service
systemctl enable NetworkManager.service

systemctl mask NetworkManager-wait-online.service

# Bootloader

bootctl install

cat > /boot/loader/loader.conf <<EOF
timeout 2
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

pacman -S --noconfirm $kernels

# User

useradd -m -G wheel "$username"
echo "${username}:${password}" | chpasswd

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/40-wheel-all

# Disable root

passwd -l root

# End

echo
echo "###############################"
echo "# Base installation complete! #"
echo "###############################"
echo
