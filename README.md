# archsetup

Yet another Arch Linux installation script.

## Base

Keywords: `dracut` `systemd-boot` `btrfs`

```sh
./base/install.sh
```
- review suvolumes scheme
- optional encryption

- Create BTRFS pool with simple subvolumes scheme from multiple devices.
- Mount options are suitable for SSD/NVME: `noatime,compress=zstd:1,space_cache=v2,discard=async`.
- Set time zone using http://ip-api.com/line?fields=timezone.
- Set default locale to `en_US.UTF-8`.
- Install microcode for detected CPU.
- Install packages `base linux linux-firmware {amd|intel}-ucode vim dracut btrfs-progs sudo networkmanager`.
- Start services `systemd-boot-update NetworkManager`.
- Use `dracut` to generate `initrd`.
- Use `systemd-boot` bootloader.
- Use `kernel-install` for automatic `initrd` and bootloader management.
- Create one user with `sudo` rights.
- Disabe `root` account.

## Extras (TODO)

- linux lts
- pacman tweaks
- reflector
- journalctl
- swapfile with low swappiness
- zram
## DE (TODO)

- realtime privileges
- plasma-meta
- sddm
- plasma-wayland-session
- dolphin
- konsole
- kate
- kwrite

- nvidia nvidia-settings settings hook
- ipv6.disable
