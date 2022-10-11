# archsetup

Yet another Arch Linux installation script.

## base.sh

Keywords: `btrfs` `systemd-boot` `dracut`

- Create BTRFS pool with simple subvolumes scheme from multiple devices.
- Mount options are suitable for SSD/NVME: `noatime,space_cache=v2,compress=zstd:1,discard=async`.
- Set time zone using http://ip-api.com/line?fields=timezone.
- Set default locale to `en_US.UTF-8`.
- Install microcode for detected CPU.
- Explicitly install packages: `base linux linux-firmware dracut vim networkmanager btrfs-progs sudo`.
- Start services: `NetworkManager`.
- Use `dracut` for `initramfs` generation.
- Use `systemd-boot` bootloader.
- Create one user with `sudo` rights.
- Disabe `root` account.
