#!/bin/bash
set -euf -o pipefail

features="$1"
de="$2"
apps="$3"

i=0
feature_nobeep=$(( 1 << ++i ))
feature_zsh=$(( 1 << ++i ))
feature_zram=$(( 1 << ++i ))
feature_multilib=$(( 1 << ++i ))
feature_autologin=$(( 1 << ++i ))
feature_reflector=$(( 1 << ++i ))
feature_paccache=$(( 1 << ++i ))
feature_firewall=$(( 1 << ++i ))
feature_man=$(( 1 << ++i ))
feature_paru=$(( 1 << ++i ))
feature_nvidia=$(( 1 << ++i ))
feature_vbox=$(( 1 << ++i ))

i=-1 # de_none should be == 0
de_none=$(( ++i ))
de_plasma=$(( ++i ))
de_xfce=$(( ++i ))

i=0
apps_devtools=$(( 1 << ++i ))
apps_cpp=$(( 1 << ++i ))
apps_pass=$(( 1 << ++i ))
apps_neovim=$(( 1 << ++i ))
apps_tmux=$(( 1 << ++i ))
apps_htop=$(( 1 << ++i ))
apps_mc=$(( 1 << ++i ))
apps_fzf=$(( 1 << ++i ))
apps_ripgrep=$(( 1 << ++i ))
apps_flatpak=$(( 1 << ++i ))
# apps_chrome=$(( 1 << ++i ))
apps_firefox=$(( 1 << ++i ))
apps_kitty=$(( 1 << ++i ))
apps_vscode=$(( 1 << ++i ))
apps_steam=$(( 1 << ++i ))
apps_lutris=$(( 1 << ++i ))
apps_libreoffice=$(( 1 << ++i ))

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

    firewall-offline-cmd --set-default-zone=home

    systemctl enable firewalld.service
fi

# Reflector

if (( features & feature_reflector )); then
    pacman -S --noconfirm reflector

    cat > /etc/xdg/reflector/reflector.conf <<EOF
--download-timeout 3
--save /etc/pacman.d/mirrorlist
--protocol https
--fastest 20
--age 6
--sort age
EOF

    systemctl enable reflector.timer
fi

# Paccahe

if (( features & feature_paccache )); then
    pacman -S --noconfirm pacman-contrib
    systemctl enable paccache.timer
fi

# Man pages

if (( features & feature_man )); then
    pacman -S --noconfirm man-pages man-db texinfo tldr
fi

# Zsh

if (( features & feature_zsh )); then
    pacman -S --noconfirm --needed zsh

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
zram-size = min(ram, 8192)
compression-algorithm = zstd
EOF

fi

# Paru

if (( features & feature_paru )); then
    pacman -S --noconfirm --needed git

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

    pacman -S --noconfirm nvidia-dkms nvidia-settings
fi

# VirtualBox guest additions

if (( features & feature_vbox )); then
    pacman -S --noconfirm virtualbox-guest-utils
fi

# Plasma DE

if [ "$de" = "$de_plasma" ]; then
    pacman -S --noconfirm \
        pipewire \
        pipewire-pulse \
        pipewire-jack \
        wireplumber \
        phonon-qt5-gstreamer

    pacman -S --noconfirm \
        ttf-liberation \
        $(pacman -Ssq noto-fonts) \
        ttf-hack \
        plasma-wayland-session \
        sddm \
        plasma-meta

    pacman -S --noconfirm \
        dolphin \
        konsole \
        kate \
        krunner \
        kcalc \
        kdeconnect

    pacman -S --noconfirm \
        kdegraphics-thumbnailers ffmpegthumbs \
        gwenview \
        okular \
        ark \
        spectacle

    systemctl enable sddm.service

    # Allow kdeconnect in firewall
    if (( features & feature_firewall )); then
        firewall-offline-cmd --zone=home --add-service=kdeconnect
    fi

    # Disable baloo
    su - "$username" -c "balooctl suspend"
    su - "$username" -c "balooctl disable"
    su - "$username" -c "balooctl purge"

    # SDDM autologin
    if (( features & feature_autologin )) && [ "$root_encrypted" != "0" ]; then
        mkdir -p /etc/sddm.conf.d

        cat > /etc/sddm.conf.d/10-autologin.conf <<EOF
[Autologin]
User=${username}
Session=plasma
EOF

    fi
fi

# Xfce

if [ "$de" = "$de_xfce" ]; then
    pacman -S --noconfirm \
        pipewire \
        pipewire-pulse \
        pipewire-jack \
        wireplumber

    pacman -S --noconfirm \
        ttf-liberation \
        $(pacman -Ssq noto-fonts) \
        ttf-hack \
        lightdm \
        lightdm-gtk-greeter \
        xfce4 \
        xfce4-goodies

    pacman -S --noconfirm \
        ffmpegthumbnailer

    systemctl enable lightdm.service

    # LightDM autologin
    if (( features & feature_autologin )) && [ "$root_encrypted" != "0" ]; then
        groupadd -r autologin
        usermod -aG autologin "$username"

        mkdir -p /etc/lightdm/lightdm.conf.d

        cat > /etc/lightdm/lightdm.conf.d/10-autologin.conf <<EOF
[Seat:*]
autologin-user=${username}
autologin-session=xfce
EOF

    fi
fi

# Flatpak

if (( apps & apps_flatpak )); then
    pacman -S --noconfirm flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

# Chrome

# if (( features & feature_paru )) && (( apps & apps_chrome )); then
#     sudoers=/etc/sudoers.d/90-user-pacman
#     echo "${username} ALL=(root) NOPASSWD: $(which pacman)" > "$sudoers"
#     su - "$username" -c "paru -S --noconfirm google-chrome"
#     rm "$sudoers"
# fi

# Apps

(( apps & apps_devtools ))    && pacman -S --noconfirm devtools
(( apps & apps_cpp ))         && pacman -S --noconfirm clang cmake ninja llvm cppcheck universal-ctags
(( apps & apps_pass ))        && pacman -S --noconfirm pass
(( apps & apps_neovim ))      && pacman -S --noconfirm neovim xclip # xclip for system clipboard
(( apps & apps_tmux ))        && pacman -S --noconfirm tmux
(( apps & apps_htop ))        && pacman -S --noconfirm htop
(( apps & apps_mc ))          && pacman -S --noconfirm mc
(( apps & apps_ripgrep ))     && pacman -S --noconfirm ripgrep
(( apps & apps_fzf ))         && pacman -S --noconfirm fzf
(( apps & apps_firefox ))     && pacman -S --noconfirm firefox
(( apps & apps_kitty ))       && pacman -S --noconfirm kitty
(( apps & apps_vscode ))      && pacman -S --noconfirm code
(( apps & apps_steam ))       && pacman -S --noconfirm steam
(( apps & apps_lutris ))      && pacman -S --noconfirm wine-staging winetricks lutris lib32-gnutls
(( apps & apps_libreoffice )) && pacman -S --noconfirm libreoffice-fresh

# Cleanup

pacman -Sc --noconfirm

# TODO: here we should check that /etc/sudoers.d contains only one file for current user

# End

echo
echo "#################################"
echo "# Extras installation complete! #"
echo "#################################"
echo
