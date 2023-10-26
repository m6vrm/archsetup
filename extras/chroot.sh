#!/bin/bash
set -euf -o pipefail

features="$1"
de="$2"
apps="$3"

i=0
feature_nobeep=$(( 1 << ++i ))
feature_zsh=$(( 1 << ++i ))
feature_zram=$(( 1 << ++i ))
feature_autologin=$(( 1 << ++i ))
feature_reflector=$(( 1 << ++i ))
feature_paccache=$(( 1 << ++i ))
feature_man=$(( 1 << ++i ))
feature_bluetooth=$(( 1 << ++i ))
feature_paru=$(( 1 << ++i ))
feature_nvidia=$(( 1 << ++i ))
feature_amd=$(( 1 << ++i ))
feature_vbox=$(( 1 << ++i ))

i=-1 # de_none should be == 0
de_none=$(( ++i ))
de_plasma=$(( ++i ))
de_xfce=$(( ++i ))

i=0

# Console apps
app_devtools=$(( 1 << ++i ))
app_cpp=$(( 1 << ++i ))
app_archiving=$(( 1 << ++i ))
app_tree=$(( 1 << ++i ))
app_tmux=$(( 1 << ++i ))
app_ncdu=$(( 1 << ++i ))
app_lostfiles=$(( 1 << ++i ))
app_podman=$(( 1 << ++i ))
app_ffmpeg=$(( 1 << ++i ))
app_dosfstools=$(( 1 << ++i ))
app_inetutils=$(( 1 << ++i ))
app_wget=$(( 1 << ++i ))

# Standard apps
app_firefox=$(( 1 << ++i ))
app_kitty=$(( 1 << ++i ))
app_steam=$(( 1 << ++i ))
app_wine=$(( 1 << ++i ))
app_libreoffice=$(( 1 << ++i ))
app_qbittorrent=$(( 1 << ++i ))
app_vbox=$(( 1 << ++i ))
app_mpv=$(( 1 << ++i ))
app_obsidian=$(( 1 << ++i ))
app_discord=$(( 1 << ++i ))
app_telegram=$(( 1 << ++i ))

# KDE apps
app_dolphin=$(( 1 << ++i ))
app_konsole=$(( 1 << ++i ))
app_kate=$(( 1 << ++i ))
app_krunner=$(( 1 << ++i ))
app_kcalc=$(( 1 << ++i ))
app_kdeconnect=$(( 1 << ++i ))
app_gwenview=$(( 1 << ++i ))
app_okular=$(( 1 << ++i ))
app_ark=$(( 1 << ++i ))
app_spectacle=$(( 1 << ++i ))
app_kdiff3=$(( 1 << ++i ))

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
        man-db \
        texinfo \
        tldr
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
    pacman -S --noconfirm bluez

    systemctl enable bluetooth.service
fi

# Paru

if (( features & feature_paru )); then
    pacman -S --noconfirm git

    git clone https://aur.archlinux.org/paru-bin.git paru

    chgrp nobody paru
    chmod g+w paru

    sudoers=/etc/sudoers.d/90-nobody-pacman
    echo "nobody ALL=(root) NOPASSWD: $(which pacman)" > "$sudoers"
    (cd paru && sudo -u nobody makepkg -fsri --noconfirm)
    rm "$sudoers"

    rm -rf paru
fi

# NVIDIA drivers

if (( features & feature_nvidia )); then
    grep -qF "nvidia_drm.modeset=1" /etc/kernel/cmdline || \
        echo "nvidia_drm.modeset=1" >> /etc/kernel/cmdline

    pacman -S --noconfirm \
        nvidia-dkms \
        nvidia-settings \
        nvidia-prime \
        lib32-nvidia-utils
fi

# AMD drivers

if (( features & feature_amd )); then
    pacman -S --noconfirm \
        mesa \
        mesa-vdpau \
        vulkan-radeon \
        libva-mesa-driver \
        xf86-video-amdgpu \
        lib32-mesa \
        lib32-libva-mesa-driver \
        lib32-mesa-vdpau
fi

# VirtualBox guest additions

if (( features & feature_vbox )); then
    pacman -S --noconfirm virtualbox-guest-utils
fi

# Any DE

if [ "$de" != "$de_none" ]; then
    # Audio
    pacman -S --noconfirm \
        pipewire \
        pipewire-pulse \
        pipewire-jack \
        wireplumber \
        lib32-libpulse

    # Fonts
    pacman -S --noconfirm \
        noto-fonts \
        noto-fonts-cjk \
        noto-fonts-emoji \
        ttf-liberation \
        ttf-hack

    # Common
    pacman -S --noconfirm \
        xdg-user-dirs \
        wl-clipboard \
        xclip
fi

# Plasma DE

if [ "$de" = "$de_plasma" ]; then
    pacman -S --noconfirm \
        phonon-qt5-gstreamer \
        plasma-wayland-session \
        sddm \
        kwalletmanager \
        plasma-meta

    pacman -S --noconfirm \
        kdegraphics-thumbnailers \
        ffmpegthumbs

    systemctl enable sddm.service

    # Disable baloo
    su - "$username" -c "balooctl suspend"
    su - "$username" -c "balooctl disable"
    su - "$username" -c "balooctl purge"

    # SDDM autologin
    if (( features & feature_autologin )) && [ "$root_encrypted" != "0" ]; then
        mkdir -p /etc/sddm.conf.d

        cat > /etc/sddm.conf.d/autologin.conf <<EOF
[Autologin]
User=${username}
Session=plasmawayland
EOF

    fi
fi

# XFCE

if [ "$de" = "$de_xfce" ]; then
    pacman -S --noconfirm \
        xorg \
        xfce4 \
        xfce4-goodies \
        lightdm \
        lightdm-gtk-greeter \
        gvfs-smb \
        sshfs

    pacman -S --noconfirm \
        papirus-icon-theme \
        arc-gtk-theme

    systemctl enable lightdm.service

    if (( features & feature_autologin )) && [ "$root_encrypted" != "0" ]; then
        sed -i "s/#?autologin-user=/autologin-user=${username}/" /etc/lightdm/lightdm.conf

        groupadd -r autologin
        gpasswd -a "$username" autologin
    fi
fi

# Apps

if (( apps & app_devtools )); then
    pacman -S --noconfirm devtools

    # Disable SSH password authentication
    sed -i -E 's/#?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
fi

if (( apps & app_cpp )); then
    pacman -S --noconfirm \
        clang \
        llvm \
        cmake \
        ninja \
        cppcheck \
        codespell \
        valgrind \
        universal-ctags \
        doxygen \
        lcov \
        gperf
fi

# Console apps
(( apps & app_archiving ))   && pacman -S --noconfirm \
    zip \
    unrar \
    unarchiver \
    p7zip \
    atool
(( apps & app_tree ))        && pacman -S --noconfirm tree
(( apps & app_tmux ))        && pacman -S --noconfirm tmux
(( apps & app_ncdu ))        && pacman -S --noconfirm ncdu
(( apps & app_lostfiles ))   && pacman -S --noconfirm lostfiles
(( apps & app_podman ))      && pacman -S --noconfirm podman
(( apps & app_ffmpeg ))      && pacman -S --noconfirm ffmpeg gifsicle
(( apps & app_dosfstools ))  && pacman -S --noconfirm dosfstools
(( apps & app_inetutils ))   && pacman -S --noconfirm inetutils
(( apps & app_wget ))        && pacman -S --noconfirm wget

# Standard apps
(( apps & app_firefox ))     && pacman -S --noconfirm \
    firefox \
    speech-dispatcher
(( apps & app_kitty ))       && pacman -S --noconfirm kitty
(( apps & app_steam ))       && pacman -S --noconfirm steam
(( apps & app_wine ))        && pacman -S --noconfirm \
    wine-staging \
    wine-mono \
    winetricks \
    xorg-server-xephyr \
    lib32-gnutls
(( apps & app_libreoffice )) && pacman -S --noconfirm libreoffice-fresh
(( apps & app_qbittorrent )) && pacman -S --noconfirm qbittorrent
(( apps & app_vbox ))        && pacman -S --noconfirm virtualbox
(( apps & app_mpv ))         && pacman -S --noconfirm mpv
(( apps & app_obsidian ))    && pacman -S --noconfirm obsidian
(( apps & app_discord ))     && pacman -S --noconfirm discord
(( apps & app_telegram ))    && pacman -S --noconfirm telegram-desktop

# KDE apps
(( apps & app_dolphin ))    && pacman -S --noconfirm dolphin
(( apps & app_konsole ))    && pacman -S --noconfirm konsole
(( apps & app_kate ))       && pacman -S --noconfirm kate
(( apps & app_krunner ))    && pacman -S --noconfirm krunner
(( apps & app_kcalc ))      && pacman -S --noconfirm kcalc
(( apps & app_kdeconnect )) && pacman -S --noconfirm kdeconnect
(( apps & app_gwenview ))   && pacman -S --noconfirm gwenview
(( apps & app_okular ))     && pacman -S --noconfirm okular
(( apps & app_ark ))        && pacman -S --noconfirm ark
(( apps & app_spectacle ))  && pacman -S --noconfirm spectacle
(( apps & app_kdiff3 ))     && pacman -S --noconfirm kdiff3

# Cleanup

pacman -Sc --noconfirm

# End

echo
echo "#################################"
echo "# Extras installation complete! #"
echo "#################################"
echo
