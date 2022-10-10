# archsetup

Yet another Arch Linux installation script.

## base.sh

Keywords: `btrfs` `systemd-boot`

- Creating BTRFS pool with simple subvolumes scheme from multiple devices.
- Mounting options for suitable for SSD/NVME: `noatime,space_cache=v2,compress=zstd:1,discard=async`.
- Sets timezone using https://ip-api.com/line?fields=timezone.
- Sets default locale to `en_US.UTF-8`.
- Installs microcode for detected CPU.
- Explicitly installs packages: `base linux linux-firmware vim networkmanager btrfs-progs sudo`.
- Starts services: `NetworkManager`.
- Uses `systemd-boot` bootloader.
- Creating one user with `sudo` rights.
- Disabling `root` account.
