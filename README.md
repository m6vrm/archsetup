Yet another Arch Linux installer.

## Usage

1. Boot into Arch Linux ISO.
2. Connect to the internet.
3. Install git: `pacman -Sy git`
4. Clone this repository: `git clone https://gitlab.com/madyanov/archsetup`
5. Run installer: `./archsetup/install.sh`
6. Reboot after installation.

> Run following command if installation fails with memory error: `mount -o remount,size=2G /run/archiso/cowspace`

## Base

Installs base system as if installed according to the [ArchWiki installation guide](https://wiki.archlinux.org/title/installation_guide).

|                           |                                                                                               |
| -                         | -                                                                                             |
| **Partitions**            | Encrypted BTRFS pool from selected devices with simple subvolume layout (`@` and `@home`)     |
| **Mount options**         | `noatime,compress=zstd:1,discard=async` (suitable for SSD/NVME)                               |
| **Recovery options**      | - Recovery bootloader entry (latest Arch Linux ISO downloaded via BitTorrent)<br>- BTRFS snapshots after installation (saved to the `/.snapshots` directory) |
| **Time zone**             | Detected automatically using http://ip-api.com/line?fields=timezone                           |
| **Locale**                | `en_US.UTF-8`                                                                                 |
| **Bootloader**            | `systemd-boot`                                                                                |
| **Initramfs generator**   | `dracut`                                                                                      |
| **Packages**              | `base linux-* linux-*-headers linux-firmware {amd,intel}-ucode vim dracut base-devel btrfs-progs networkmanager` |
| **Pacman hooks**          | `kernel-install` hook for automatic `initramfs` and bootloader entries generation             |
| **Users**                 | - One user with `sudo` rights<br>- *`root` account disabled*                                  |

### Maintenance

**Kernel boot parameters**

Either edit bootloader entries in `/boot/loader/entries/` or edit the `/etc/kernel/cmdline` and *reinstall the kernel* to trigger `initramfs` and bootloader entries generation:

```sh
sudoedit /etc/kernel/cmdline
kernel-install add "$(uname r)" "/usr/lib/modules/$(uname -r)/vmlinuz" # or just `pacman -S <kernel-package>`
```

**Update recovery image**

1. Download the [latest Arch Linux ISO](https://archlinux.org/download/) and place it at `/boot/recovery/archlinux.iso`.
2. Check booting into recovery mode.
3. If boot failed, mount downloaded `archlinux.iso` and copy `vmlinuz-linux` and `initramfs-linux.img` to `/boot/recovery/`.

## Installation example

```sh
rmmod pcspkr
rfkill unblock all
iwctl
station wlan0 get-networks
station wlan0 connect <SSID>
exit
pacman -Sy git
git clone https://gitlab.com/madyanov/archsetup
./archsetup/install.sh
reboot
```
