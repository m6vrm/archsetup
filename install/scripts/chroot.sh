#!/usr/bin/env bash
set -euf -o pipefail

username=$1
password=$2
hostname=$3
timezone=$4
microcode=$5

# System time

ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
hwclock --systohc

# Locale

sed -i "s/#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=us" >> /etc/vconsole.conf

# Host

echo "$hostname" >> /etc/hostname

echo "127.0.0.1	localhost"      >> /etc/hosts
echo "::1		localhost"      >> /etc/hosts
echo "127.0.1.1	${hostname}"    >> /etc/hosts

# Packages

pacman -S --noconfirm networkmanager btrfs-progs sudo "$microcode"

# Services

systemctl enable NetworkManager
systemctl mask NetworkManager-wait-online

# Bootloader

bootctl install

rm /boot/loader/loader.conf
echo "default arch.conf"    >> /boot/loader/loader.conf
echo "timeout 0"            >> /boot/loader/loader.conf
echo "console-mode auto"    >> /boot/loader/loader.conf
echo "editor no"            >> /boot/loader/loader.conf

echo "title Arch Linux"                                     >> /boot/loader/entries/arch.conf
echo "linux /vmlinuz-linux"                                 >> /boot/loader/entries/arch.conf
[[ -n "$microcode" ]] && echo "initrd /${microcode}.img"    >> /boot/loader/entries/arch.conf
echo "initrd /initramfs-linux.img"                          >> /boot/loader/entries/arch.conf
echo "options root=LABEL=ROOT rootflags=subvol=@ rw"        >> /boot/loader/entries/arch.conf

# User

useradd -m -G wheel "$username"
echo "${username}:${password}" | chpasswd

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Disable root

passwd -l root

# Remove this script

rm -- "$0"

# Last but not least step

echo
echo "##########################"
echo "# Installation complete! #"
echo "##########################"
echo
