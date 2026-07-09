# Dockerfile (Gentoo Linux KDE Plasma — systemd, Wayland + Anland)
# Stage 1: Build and customize the rootfs for Droidspaces with KDE + Anland
ARG TARGETPLATFORM
FROM gentoo/stage3:systemd AS customizer

# Build options
ARG PulseAudio=socket
ARG ENABLE_zh=true
ARG ENABLE_dev=true
ARG ENABLE_gpu=true
ARG USERNAME=luochen570

# Update Portage, configure for source build
RUN emerge --sync && \
    emerge --oneshot sys-apps/portage && \
    echo 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox noman noinfo nodoc"' >> /etc/portage/make.conf && \
    echo 'EMERGE_DEFAULT_OPTS="--jobs=$(nproc) --load-average=$(nproc) --quiet-build=y"' >> /etc/portage/make.conf

# ── Droidspaces Overlay ────────────────────────────────────────────────────
# Priority: droidspaces (50) > gentoo, ensures patched kwin/xwayland take precedence
RUN mkdir -p /etc/portage/repos.conf && \
    cat > /etc/portage/repos.conf/droidspaces.conf << 'EOF'
[droidspaces]
location = /var/db/repos/droidspaces
sync-type = git
sync-uri = https://github.com/luochen88/droidspaces-overlay.git
priority = 50
auto-sync = yes
EOF
    # Mask standard kwin/xwayland from ::gentoo — only use overlay versions
    mkdir -p /etc/portage/package.mask && \
    echo '# Block ::gentoo kwin/xwayland — use droidspaces overlay patched versions' >> /etc/portage/package.mask/anland && \
    echo 'kde-plasma/kwin::gentoo' >> /etc/portage/package.mask/anland && \
    echo 'x11-base/xwayland::gentoo' >> /etc/portage/package.mask/anland

# Sync droidspaces overlay
RUN emaint sync -r droidspaces || true

# Accept KDE licenses and set USE flags
RUN echo 'kde-plasma/* QPL-2.0 GPL-2 GPL-3 LGPL-2.1 LGPL-3' >> /etc/portage/package.license && \
    echo 'x11-libs/* QPL-2.0 GPL-2 GPL-3 LGPL-2.1 LGPL-3' >> /etc/portage/package.license && \
    echo 'kde-apps/* QPL-2.0 GPL-2 GPL-3 LGPL-2.1 LGPL-3' >> /etc/portage/package.license && \
    echo 'kde-frameworks/* QPL-2.0 GPL-2 GPL-3 LGPL-2.1 LGPL-3' >> /etc/portage/package.license && \
    # Wayland + GPU
    echo 'media-libs/mesa X wayland vulkan gles2' >> /etc/portage/package.use/mesa && \
    echo 'x11-base/xorg-server xorg' >> /etc/portage/package.use/xorg && \
    echo 'media-video/pipewire sound-server' >> /etc/portage/package.use/pipewire && \
    echo 'media-libs/libcanberra alsa' >> /etc/portage/package.use/libcanberra && \
    echo 'media-libs/libglvnd X' >> /etc/portage/package.use/libglvnd && \
    echo 'dev-qt/qtbase vulkan libproxy icu opengl wayland' >> /etc/portage/package.use/qtbase && \
    echo 'app-text/xmlto text' >> /etc/portage/package.use/xmlto && \
    echo 'kde-frameworks/kwindowsystem wayland X' >> /etc/portage/package.use/kwindowsystem && \
    echo 'sys-apps/systemd policykit' >> /etc/portage/package.use/systemd && \
    echo 'kde-frameworks/kconfig dbus qml' >> /etc/portage/package.use/kconfig && \
    echo 'dev-qt/qt5compat qml' >> /etc/portage/package.use/qt5compat && \
    echo 'dev-qt/qtdeclarative vulkan opengl' >> /etc/portage/package.use/qtdeclarative

# Install base system packages (shell, network, tools)
RUN --mount=type=cache,target=/var/cache/distfiles,sharing=locked \
    emerge --newuse --update \
    app-shells/bash \
    net-misc/curl \
    app-misc/ca-certificates \
    dev-vcs/git \
    app-editors/nano \
    app-admin/sudo \
    net-misc/openssh \
    sys-apps/net-tools \
    net-firewall/iptables \
    net-misc/iputils \
    sys-apps/iproute2 \
    sys-process/htop \
    sys-process/procps \
    app-shells/bash-completion \
    # Wayland + X11 (XWayland for legacy apps)
    x11-base/xorg-server \
    x11-base/xwayland \
    gui-apps/wl-clipboard \
    gui-apps/wayland-utils \
    x11-apps/xrandr \
    media-fonts/noto \
    media-fonts/noto-cjk \
    media-fonts/noto-emoji \
    # Audio (PipeWire)
    media-video/pipewire \
    media-video/wireplumber \
    media-libs/libpulse \
    # Dev tools for building anland (方案A: cmake, meson, ninja)
    dev-build/cmake \
    dev-build/ninja \
    dev-build/meson \
    dev-vcs/git \
    # Clean up distfiles
    && rm -rf /var/cache/distfiles/* /var/tmp/portage/*

# Install KDE Plasma desktop
# Use autounmask to let Portage resolve USE conflicts automatically
RUN --mount=type=cache,target=/var/cache/distfiles,sharing=locked \
    (emerge --autounmask-write --newuse --update \
        kde-plasma/plasma-desktop \
        kde-apps/konsole \
        kde-apps/dolphin \
        kde-plasma/powerdevil \
        kde-plasma/kscreen \
        kde-plasma/plasma-pa \
        kde-apps/ark \
        kde-apps/kate \
        kde-plasma/kinfocenter \
        sys-power/upower \
        app-arch/xz-utils \
        app-arch/gzip \
        app-arch/tar \
        app-arch/unzip \
        app-arch/zip \
        || true) && \
    emerge --newuse --update \
        kde-plasma/plasma-desktop \
        kde-apps/konsole \
        kde-apps/dolphin \
        kde-plasma/powerdevil \
        kde-plasma/kscreen \
        kde-plasma/plasma-pa \
        kde-apps/ark \
        kde-apps/kate \
        kde-plasma/kinfocenter \
        sys-power/upower \
        app-arch/xz-utils \
        app-arch/gzip \
        app-arch/tar \
        app-arch/unzip \
        app-arch/zip \
        && rm -rf /var/cache/distfiles/* /var/tmp/portage/*

# ── Anland Daemon (方案A: 从源码编译) ────────────────────────────────────────
RUN git clone --depth=1 https://github.com/superturtlee/anland.git /tmp/anland && \
    cd /tmp/anland && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_DAEMON=ON && \
    make -j$(nproc) && \
    cp daemon /usr/local/bin/anland-daemon && \
    rm -rf /tmp/anland

# ── Anland systemd service ──────────────────────────────────────────────────
RUN cat > /etc/systemd/system/anland-daemon.service << 'EOF'
[Unit]
Description=Anland Display Protocol Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/anland-daemon
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
    mkdir -p /etc/systemd/system/multi-user.target.wants && \
    ln -sf /etc/systemd/system/anland-daemon.service /etc/systemd/system/multi-user.target.wants/anland-daemon.service

# Install Chinese locale and input method
RUN --mount=type=cache,target=/var/cache/distfiles,sharing=locked \
    if [ "$ENABLE_zh" = "true" ]; then \
        emerge --newuse --update \
        app-i18n/fcitx5 \
        app-i18n/fcitx5-chinese-addons \
        app-i18n/fcitx5-configtool \
        && rm -rf /var/cache/distfiles/* /var/tmp/portage/*; \
    fi

# Install dev tools
RUN --mount=type=cache,target=/var/cache/distfiles,sharing=locked \
    if [ "$ENABLE_dev" = "true" ]; then \
        emerge --newuse --update \
        sys-devel/gcc \
        llvm-core/clang \
        llvm-core/llvm \
        dev-lang/python \
        dev-python/pip \
        dev-debug/strace \
        && rm -rf /var/cache/distfiles/* /var/tmp/portage/*; \
    fi

# Copy our bashrc script to the rootfs
COPY scripts/bashrc.sh /etc/profile.d/ds-aliases.sh
RUN chmod +x /etc/profile.d/ds-aliases.sh

# Configure legacy iptables (MANDATORY for Android compatibility)
RUN ln -sf /sbin/iptables-legacy /sbin/iptables && \
    ln -sf /sbin/ip6tables-legacy /sbin/ip6tables && \
    ln -sf /sbin/arptables-legacy /sbin/arptables && \
    ln -sf /sbin/ebtables-legacy /sbin/ebtables || true

# Configure locales
RUN if [ "$ENABLE_zh" = "true" ]; then \
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
        echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen && \
        echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
        locale-gen && \
        eselect locale set zh_CN.UTF-8; \
    else \
        echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
        locale-gen && \
        eselect locale set en_US.UTF-8; \
    fi && \
    # Configure SSH
    mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Create normal user
RUN useradd -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME}:12345678" | chpasswd && \
    usermod -aG wheel,audio,video,input,render ${USERNAME} && \
    echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

# ── Environment variables (Wayland) ─────────────────────────────────────────
RUN cat <<'EOF' > /etc/profile.d/custom_env.sh
export XCURSOR_SIZE=48
export WAYLAND_DISPLAY=wayland-0
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export XDG_SESSION_TYPE=wayland
EOF

# PulseAudio config
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo "export PULSE_SERVER=unix:/tmp/.pulse-socket" >> /etc/profile.d/custom_env.sh; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo "export PULSE_SERVER=tcp:127.0.0.1:4713" >> /etc/profile.d/custom_env.sh; \
    fi && \
    chmod +x /etc/profile.d/custom_env.sh

# ── Mesa / kgsl GPU overrides (Qualcomm Adreno) ────────────────────────────
RUN if [ "$ENABLE_gpu" = "true" ]; then \
        cat <<'EOF' >> /etc/profile.d/custom_env.sh
# kgsl / Turnip GPU
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export TU_DEBUG=noconform
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
EOF
    fi

# ── /etc/environment for systemd services ───────────────────────────────────
RUN cat <<'EOF' >> /etc/environment
WAYLAND_DISPLAY=wayland-0
QT_QPA_PLATFORM=wayland
GDK_BACKEND=wayland
XDG_SESSION_TYPE=wayland
EOF

# Fcitx5 autostart
RUN if [ "$ENABLE_zh" = "true" ]; then \
        mkdir -p /home/${USERNAME}/.config/autostart && \
        printf '[Desktop Entry]\nName=Fcitx5\nGenericName=Input Method\nComment=Start Input Method\nExec=fcitx5 -d\nIcon=fcitx\nTerminal=false\nType=Application\nCategories=System;Utility;\nStartupNotify=false\nNoDisplay=true\n' > /home/${USERNAME}/.config/autostart/fcitx5.desktop && \
        echo 'export XMODIFIERS=@im=fcitx5' >> /etc/profile.d/custom_env.sh && \
        echo 'export GTK_IM_MODULE=fcitx5' >> /etc/profile.d/custom_env.sh && \
        echo 'export QT_IM_MODULE=fcitx5' >> /etc/profile.d/custom_env.sh && \
        echo 'export SDL_IM_MODULE=fcitx5' >> /etc/profile.d/custom_env.sh && \
        echo 'export GLFW_IM_MODULE=fcitx' >> /etc/profile.d/custom_env.sh; \
    fi

# Fix DHCP in the container
RUN mkdir -p /etc/systemd/network && \
    cat <<'EOF' > /etc/systemd/network/10-eth-dhcp.network
[Match]
Name=eth*

[Network]
DHCP=yes
IPv6AcceptRA=yes

[DHCPv4]
UseDNS=yes
UseDomains=yes
RouteMetric=100
EOF

# Apply Android compatibility fixes (Systemd and Udev)
RUN <<EOF_RUN
# --- 1. General Fixes ---
grep -q '^aid_inet:' /etc/group    || echo 'aid_inet:x:3003:'    >> /etc/group
grep -q '^aid_net_raw:' /etc/group || echo 'aid_net_raw:x:3004:' >> /etc/group
grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:' >> /etc/group
usermod -a -G aid_inet,aid_net_raw,input,video,tty,render root || true

# --- 2. Systemd-Specific Fixes ---
ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service
ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket

cat >> /etc/systemd/journald.conf << 'EOT'
[Journal]
ReadKMsg=no
Audit=no
Storage=volatile
EOT

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/ds-logging.conf << 'EOT'
[Journal]
SystemMaxUse=200M
RuntimeMaxUse=200M
MaxRetentionSec=7day
MaxLevelStore=info
EOT

# Enable essential services
mkdir -p /etc/systemd/system/multi-user.target.wants
GUEST_SYSTEMD_PATH="/usr/lib/systemd/system"
for service in dbus.service systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$service" ]; then
        ln -sf "$GUEST_SYSTEMD_PATH/$service" "/etc/systemd/system/multi-user.target.wants/$service"
    fi
done

# Disable power button handling
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/99-power-key.conf << 'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKeyLongPress=ignore
HandlePowerKeyLongPressHibernate=ignore
EOF

# Apply udev overrides
mkdir -p /etc/systemd/system/systemd-udev-trigger.service.d
cat > /etc/systemd/system/systemd-udev-trigger.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net
EOF

for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-kernel.socket systemd-udevd-control.socket; do
    mkdir -p "/etc/systemd/system/${unit}.d"
    printf "[Unit]\nConditionPathIsReadWrite=\n" > "/etc/systemd/system/${unit}.d/99-readonly-fix.conf"
done

# Limit network services
for unit in NetworkManager.service dhcpcd.service systemd-resolved.service systemd-networkd.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$unit" ] || [ -f "/etc/systemd/system/multi-user.target.wants/$unit" ]; then
        mkdir -p "/etc/systemd/system/${unit}.d"
        cat > "/etc/systemd/system/${unit}.d/99-netmode-limit.conf" << 'EOF'
[Service]
ExecCondition=
ExecCondition=/bin/sh -c "grep -qE 'net_mode=(nat|gateway)' /run/droidspaces/container.config"
EOF
    fi
done

# Mark fixes as completed
echo "Post-extraction fixes applied on $(date)" > /etc/droidspaces
EOF_RUN

# KWin customization: disable compositing for better performance on Android
RUN mkdir -p /home/${USERNAME}/.config && \
    cat <<'EOF' > /home/${USERNAME}/.config/kwinrc
[Compositing]
Enabled=false
EOF

# ── plasma-wayland systemd service (autostart KDE on boot) ──────────────────
RUN cat <<EOF > /etc/systemd/system/plasma-wayland.service
[Unit]
Description=Start Plasma Wayland
After=network.target dbus.service anland-daemon.service
Wants=anland-daemon.service

[Service]
Type=simple
User=${USERNAME}
EnvironmentFile=-/etc/environment
ExecStart=/bin/bash -lc 'startplasma-wayland'
Restart=no
RestartSec=3
PAMName=login

[Install]
WantedBy=multi-user.target
EOF
RUN mkdir -p /etc/systemd/system/multi-user.target.wants && \
    ln -sf /etc/systemd/system/plasma-wayland.service /etc/systemd/system/multi-user.target.wants/plasma-wayland.service

# Set ownership of home directory
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Final cleanup — strip all build-time cruft
RUN rm -rf \
    /var/cache/distfiles/* \
    /var/tmp/portage/* \
    /var/cache/edb/* \
    /var/db/repos/gentoo \
    /usr/portage \
    /var/log/*.log \
    /var/log/portage \
    /usr/share/gtk-doc \
    /usr/share/doc/*

# Stage 2: Export to scratch for extraction
FROM scratch AS export

# Copy the entire filesystem from the customizer stage
COPY --from=customizer / /
