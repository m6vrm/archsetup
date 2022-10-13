# archsetup

Yet another Arch Linux installation script.

## Base

Keywords: `dracut` `systemd-boot` `btrfs` `encryption`

To install run:

```sh
./base/install.sh
```

- See the beginning of `wizard.sh` to review default installation parameters.
- See `install.sh` to review partitioning and ecryption.
- See `chroot.sh` to review installation after `chroot`.

Installation steps:

- Create encrypted BTRFS pool with simple subvolume layout.
- Mount options are suitable for SSD/NVME: `noatime,compress=zstd:1,space_cache=v2,discard=async`.
- Set time zone using http://ip-api.com/line?fields=timezone.
- Set default locale to `en_US.UTF-8`.
- Install microcode for detected CPU.
- Install packages `base linux linux-firmware {amd|intel}-ucode vim dracut btrfs-progs sudo networkmanager`.
- Start services `systemd-boot-update NetworkManager`.
- Use `systemd-boot` bootloader.
- Use `dracut` to generate `initramfs`.
- Use `kernel-install` for automatic `initramfs` and bootloader management.
- Create one user with `sudo` rights.
- Disabe `root` account.

To change kernel boot parameters you can either edit `/etc/kernel/cmdline` and *reinstall the kernel* or remove `/etc/kernel/cmdline` and edit the bootloader entries directly.

```sh
vim /etc/kernel/cmdline
kernel-install add "$(uname r)" "/usr/lib/modules/$(uname -r)/vmlinuz" # or just pacman -S linux
```
