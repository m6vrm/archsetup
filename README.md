# archsetup

Yet another Arch Linux installation script.

## Base System

Keywords: `dracut` `systemd-boot` `btrfs`

```sh
./archsetup/install/base.sh
```

- Create BTRFS pool with simple subvolumes scheme from multiple devices.
- Mount options are suitable for SSD/NVME: `noatime,compress=zstd:1,space_cache=v2,discard=async`.
- Set time zone using http://ip-api.com/line?fields=timezone.
- Set default locale to `en_US.UTF-8`.
- Install microcode for detected CPU.
- Explicitly install packages `base linux linux-firmware {amd|intel}-ucode vim dracut btrfs-progs sudo networkmanager`.
- Start services `systemd-boot-update NetworkManager`.
- Use `dracut` to generate `initramfs`.
- Use `systemd-boot` bootloader.
- Create one user with `sudo` rights.
- Disabe `root` account.
