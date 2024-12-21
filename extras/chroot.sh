#!/bin/bash
set -euf -o pipefail

features="$1"
de="$2"

i=0
feature_nobeep=$(( 1 << ++i ))
feature_zsh=$(( 1 << ++i ))
feature_zram=$(( 1 << ++i ))
feature_autologin=$(( 1 << ++i ))
feature_reflector=$(( 1 << ++i ))
feature_paccache=$(( 1 << ++i ))
feature_man=$(( 1 << ++i ))
feature_bluetooth=$(( 1 << ++i ))
feature_vbox=$(( 1 << ++i ))

i=-1 # de_none should be == 0
de_none=$(( ++i ))
de_xfce=$(( ++i ))

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

sed -i "/\[multilib]/s/^#//" /etc/pacman.conf
sed -i "/\[multilib]/{N;s/\n#/\n/}" /etc/pacman.conf

pacman -Sy

# No beep

if (( features & feature_nobeep )); then
    echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
fi

# Reflector

if (( features & feature_reflector )); then
    pacman -S --noconfirm reflector

    cat > /etc/xdg/reflector/reflector.conf <<EOF
--download-timeout 2
--save /etc/pacman.d/mirrorlist
--protocol https
--fastest 20
--age 6
--sort rate
EOF

    systemctl enable reflector.timer
fi

# Paccache

if (( features & feature_paccache )); then
    pacman -S --noconfirm pacman-contrib

    systemctl enable paccache.timer
fi

# Man pages

if (( features & feature_man )); then
    pacman -S --noconfirm \
        man-pages \
        man-db
fi

# Zsh

if (( features & feature_zsh )); then
    pacman -S --noconfirm zsh

    chsh -s "$(which zsh)" "$username"

    rm -f "/home/${username}/.bash_history"
    rm -f "/home/${username}/.bash_logout"
    rm -f "/home/${username}/.bash_profile"
    rm -f "/home/${username}/.bashrc"
fi

# Zram

if (( features & feature_zram )); then
    pacman -S --noconfirm zram-generator

    cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

fi

# Bluetooth

if (( features & feature_bluetooth )); then
    pacman -S --noconfirm \
        bluez \
        bluez-utils

    systemctl enable bluetooth.service
fi

# VirtualBox guest additions

if (( features & feature_vbox )); then
    pacman -S --noconfirm virtualbox-guest-utils

    systemctl enable vboxservice.service

    usermod -aG vboxsf "{$username}"
fi

# Any DE

if [ "$de" != "$de_none" ]; then
    # Audio
    pacman -S --noconfirm \
        pipewire \
        pipewire-pulse \
        pipewire-jack \
        wireplumber

    # Common
    pacman -S --noconfirm \
        xdg-user-dirs \
        wl-clipboard \
        xclip

    # Fonts
    pacman -S --noconfirm \
        noto-fonts \
        noto-fonts-cjk \
        noto-fonts-emoji
fi

# XFCE

if [ "$de" = "$de_xfce" ]; then
    pacman -S --noconfirm \
        xorg \
        xfce4 \
        xfce4-goodies \
        lightdm \
        lightdm-gtk-greeter

    pacman -S --noconfirm \
        papirus-icon-theme \
        arc-gtk-theme

    pacman -S --noconfirm \
        network-manager-applet

    systemctl enable lightdm.service

    # LightDM autologin
    if (( features & feature_autologin )) && [ "$root_encrypted" != "0" ]; then
        sed -i -E "s/#?autologin-user=.*$/autologin-user=${username}/" /etc/lightdm/lightdm.conf

        groupadd -r autologin
        gpasswd -a "$username" autologin
    fi
fi

# Cleanup

pacman -Sc --noconfirm

# End

echo
echo "#################################"
echo "# Extras installation complete! #"
echo "#################################"
echo
