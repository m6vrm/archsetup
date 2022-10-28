#!/bin/bash
set -euf -o pipefail

features="$1"
de="$2"
apps="$3"

i=0
feature_reflector=$(( 1 << ++i ))
feature_multilib=$(( 1 << ++i ))
feature_zram=$(( 1 << ++i ))
feature_firewall=$(( 1 << ++i ))
feature_autologin=$(( 1 << ++i ))
feature_nobeep=$(( 1 << ++i ))
feature_man=$(( 1 << ++i ))
feature_paru=$(( 1 << ++i ))
feature_nvidia=$(( 1 << ++i ))
feature_vbox=$(( 1 << ++i ))

i=0
de_none=$(( ++i ))
de_plasma=$(( ++i ))

i=0
apps_flatpak=$(( 1 << ++i ))
apps_steam=$(( 1 << ++i ))
apps_kitty=$(( 1 << ++i ))
apps_neovim=$(( 1 << ++i ))
apps_tmux=$(( 1 << ++i ))
apps_htop=$(( 1 << ++i ))
apps_mc=$(( 1 << ++i ))
apps_ripgrep=$(( 1 << ++i ))

# Environment

username=$(getent passwd | awk -F ':' '$6 == "/home/"$1 {print $1}' | head -n 1)

root_part=$(findmnt -n -o SOURCES -T / | head -n 1)
cryptsetup status "$root_part" | grep -qF "LUKS" && root_encrypted=1 || root_encrypted=0

# TTY autologin

if (( features & feature_autologin )) && [ "$root_encrypted" != "0" ]; then
    mkdir -p /etc/systemd/system/getty@tty1.service.d

    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\\u' --noclear --autologin ${username} %I \$TERM
EOF

fi

# Pacman

sed -i "/Color/s/#//" /etc/pacman.conf
sed -i "/ParallelDownloads/s/#//" /etc/pacman.conf

if (( features & feature_multilib )); then
    sed -i "/\[multilib]/s/^#//" /etc/pacman.conf
    sed -i "/\[multilib]/{N;s/\n#/\n/}" /etc/pacman.conf
fi

pacman -Sy

# No beep

if (( features & feature_nobeep )); then
    echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
fi

# Firewall

if (( features & feature_firewall )); then
    pacman -S --noconfirm firewalld

    sed -i "/DefaultZone=/s/=.\+/=home/" /etc/firewalld/firewalld.conf

    systemctl enable firewalld.service
fi

# Reflector

if (( features & feature_reflector )); then
    pacman -S --noconfirm reflector

    sed -i "/--latest/s/[0-9]\+/20/" /etc/xdg/reflector/reflector.conf
    sed -i "/--sort/s/ .\+/ rate/" /etc/xdg/reflector/reflector.conf

    echo "Retrieving fastest pacman mirrors, it may take a few minutes..."
    reflector \
        --save /etc/pacman.d/mirrorlist \
        --protocol https \
        --latest 20 \
        --sort rate

    systemctl enable reflector.timer
fi

# Man pages

if (( features & feature_man )); then
    pacman -S --noconfirm man-pages man-db texinfo
fi

# Zram

if (( features & feature_zram )); then
    pacman -S --noconfirm zram-generator

    cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram, 8192)
compression-algorithm = zstd
EOF

fi

# Paru

if (( features & feature_paru )); then
    pacman -S --noconfirm --needed git base-devel

    git clone https://aur.archlinux.org/paru-bin.git paru

    chgrp nobody paru
    chmod g+w paru

    echo "nobody ALL=(root) NOPASSWD: $(which pacman)" > /etc/sudoers.d/10-nobody-pacman
    (cd paru && sudo -u nobody makepkg -fsri --noconfirm)
    rm /etc/sudoers.d/10-nobody-pacman

    rm -rf paru
fi

# NVIDIA drivers

if (( features & feature_nvidia )); then
    grep -qF "nvidia_drm.modeset=1" /etc/kernel/cmdline || \
        echo -n " nvidia_drm.modeset=1" >> /etc/kernel/cmdline

    pacman -S --noconfirm nvidia-dkms nvidia-settings
fi

# VirtualBox guest additions

if (( features & feature_vbox )); then
    pacman -S --noconfirm virtualbox-guest-utils
fi

# Plasma DE

if [ "$de" = "$de_plasma" ]; then
    pacman -S --noconfirm --asdeps \
        wireplumber \
        pipewire-jack \
        phonon-qt5-gstreamer

    pacman -S --noconfirm \
        ttf-iosevka-nerd \
        ttf-liberation \
        $(pacman -Ssq noto-fonts) \
        ttf-hack \
        plasma-wayland-session \
        sddm \
        plasma-meta

    pacman -S --noconfirm \
        kdegraphics-thumbnailers ffmpegthumbs \
        dolphin \
        konsole \
        kate \
        kdeconnect

    systemctl enable sddm.service

    if (( features & feature_autologin )) && [ "$root_encrypted" != "0" ]; then
        mkdir /etc/sddm.conf.d

        cat > /etc/sddm.conf.d/autologin.conf <<EOF
[Autologin]
User=${username}
Session=plasma
EOF

    fi
fi

# Flatpak

if (( apps & apps_flatpak )); then
    pacman -S flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

# Apps

(( apps & apps_steam ))   && pacman -S --noconfirm steam
(( apps & apps_kitty ))   && pacman -S --noconfirm kitty
(( apps & apps_neovim ))  && pacman -S --noconfirm neovim
(( apps & apps_tmux ))    && pacman -S --noconfirm tmux
(( apps & apps_htop ))    && pacman -S --noconfirm htop
(( apps & apps_mc ))      && pacman -S --noconfirm mc
(( apps & apps_ripgrep )) && pacman -S --noconfirm ripgrep

# End

echo
echo "#################################"
echo "# Extras installation complete! #"
echo "#################################"
echo
