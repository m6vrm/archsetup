Yet another Arch Linux installer.

Features
========

*   Encrypted BTRFS pool
*   Recovery entry in the bootloader
*   BTRFS snapshots during installation
*   systemd-boot bootloader
*   dracut initramfs generator
*   Disabled root account

Usage
=====

1.  Boot with Arch Linux ISO
2.  Connect to the internet
3.  Install git:

        pacman -Sy git

4.  Clone this repository:

        git clone https://github.com/m6vrm/archsetup

5.  Run installer:

        ./archsetup/install.sh

6.  Reboot after installation.

NOTE: If installation fails due to a memory error, run following command:

    mount -o remount,size=2G /run/archiso/cowspace

Base system
===========

Installs the base system as if it had been installed according to the ArchWiki
installation guide:

    Partitions              Encrypted BTRFS pool with simple subvolume layout
                            (@ and @home subvolumes)
    Mount options           noatime,compress=zstd:1,discard=async (suitable
                            for SSD/NVME)
    Recovery options        Recovery entry in the bootloader
                            BTRFS snapshots during installation
    Time zone               Detected automatically using
                            http://ip-api.com/line?fields=timezone
    Locale                  en_US.UTF-8
    Bootloader              systemd-boot
    Initramfs generator     dracut
    Packages                base linux-* linux-*-headers linux-firmware
                            {amd,intel}-ucode vim dracut base-devel btrfs-progs
                            networkmanager
    Pacman hooks            kernel-install hook for automatic initramfs
                            and bootloader entries generation
    Users                   Regular user with sudo rights
                            root account disabled

Maintenance
===========

Kernel boot parameters
----------------------

Either edit bootloader entries in the /boot/loader/entries/ or edit
the /etc/kernel/cmdline and reinstall the kernel to trigger initramfs
and bootloader entries generation:

    sudoedit /etc/kernel/cmdline
    sudo pacman -S <kernel-package>

Update recovery image
---------------------

1.  Download latest Arch Linux ISO from https://archlinux.org/download/
    and place it at /boot/recovery/archlinux.iso
2.  Check booting into recovery mode
3.  If boot failed, mount downloaded archlinux.iso and copy vmlinuz-linux
    and initramfs-linux.img to the /boot/recovery/ directory

Installation example
====================

    rmmod pcspkr
    rfkill unblock all
    iwctl
        station wlan0 get-networks
        station wlan0 connect <SSID>
        exit
    pacman -Sy git
    git clone https://github.com/m6vrm/archsetup
    ./archsetup/install.sh
    reboot
