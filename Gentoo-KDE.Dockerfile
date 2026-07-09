# Dockerfile (Gentoo Linux KDE Plasma — systemd, X11)
# Stage 1: Build and customize the rootfs for Droidspaces with KDE
ARG TARGETPLATFORM
FROM gentoo/stage3:systemd AS customizer

# Cache bust for CI rebuilds
ARG CACHEBUST=0

# Build options
ARG PulseAudio=socket
ARG ENABLE_zh=true
ARG ENABLE_dev=true
ARG USERNAME=luochen570

# Update Portage, configure with binhost for fast binary installs
RUN echo "cachebust=${CACHEBUST}" ; \
    emerge --sync && \
    emerge --oneshot sys-apps/portage && \
    echo 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox getbinpkg"' >> /etc/portage/make.conf && \
    echo 'EMERGE_DEFAULT_OPTS="--jobs=4 --load-average=6 --quiet-build=y --getbinpkg --usepkg --binpkg-respect-use=n --binpkg-changed-deps=n"' >> /etc/portage/make.conf && \
    echo 'PORTAGE_BINHOST="https://gentoo.osuosl.org/releases/arm64/binpackages/23.0/arm64/"' >> /etc/portage/make.conf && \
    # glib needs rst2man (dev-python/docutils) during configure, even with 'noman'
    emerge --oneshot --getbinpkg --usepkg dev-python/docutils && \
    # Stage3 Docker image lacks dev files — install glib first (needed by gobject-introspection build)
    emerge --oneshot --nodeps --getbinpkg --usepkg dev-libs/glib && \
    emerge --oneshot --getbinpkg --usepkg dev-libs/gobject-introspection

# Accept KDE licenses and set USE flags
RUN echo 'kde-plasma/* QPL-2.0 GPL-2 GPL-3 LGPL-2.1 LGPL-3' >> /etc/portage/package.license && \
    echo 'x11-libs/* QPL-2.0 GPL-2 GPL-3 LGPL-2.1 LGPL-3' >> /etc/portage/package.license && \
    echo 'kde-apps/* QPL-2.0 GPL-2 GPL-3 LGPL-2.1 LGPL-3' >> /etc/portage/package.license && \
    echo 'kde-frameworks/* QPL-2.0 GPL-2 GPL-3 LGPL-2.1 LGPL-3' >> /etc/portage/package.license && \
    echo 'media-libs/mesa X wayland' >> /etc/portage/package.use/mesa && \
    echo 'x11-base/xorg-server xorg' >> /etc/portage/package.use/xorg && \
    echo 'media-video/pipewire sound-server' >> /etc/portage/package.use/pipewire && \
    echo 'media-libs/libglvnd X' >> /etc/portage/package.use/libglvnd && \
    echo 'media-libs/libcanberra alsa' >> /etc/portage/package.use/libcanberra && \
    echo 'dev-qt/qtbase vulkan libproxy icu opengl wayland cups' >> /etc/portage/package.use/qtbase && \
    echo 'dev-qt/qtmultimedia opengl vulkan qml' >> /etc/portage/package.use/qtmultimedia && \
    echo 'dev-qt/qtquick3d opengl vulkan' >> /etc/portage/package.use/qtquick3d && \
    echo 'dev-qt/qttools opengl' >> /etc/portage/package.use/qttools && \
    echo 'x11-libs/libxkbcommon X' >> /etc/portage/package.use/libxkbcommon && \
    echo 'x11-libs/cairo X' >> /etc/portage/package.use/cairo && \
    echo 'x11-libs/pango X' >> /etc/portage/package.use/pango && \
    echo 'sys-apps/dbus X' >> /etc/portage/package.use/dbus && \
    echo 'app-i18n/fcitx keyboard X' >> /etc/portage/package.use/fcitx && \
    echo 'media-libs/freetype harfbuzz' >> /etc/portage/package.use/freetype && \
    echo 'app-text/xmlto text' >> /etc/portage/package.use/xmlto && \
    echo 'kde-frameworks/kwindowsystem wayland X' >> /etc/portage/package.use/kwindowsystem && \
    echo 'sys-apps/systemd policykit' >> /etc/portage/package.use/systemd && \
    echo 'kde-frameworks/kconfig dbus qml' >> /etc/portage/package.use/kconfig && \
    echo 'kde-frameworks/kcoreaddons dbus' >> /etc/portage/package.use/kcoreaddons && \
    echo 'kde-frameworks/kidletime wayland' >> /etc/portage/package.use/kidletime && \
    echo 'kde-frameworks/kguiaddons wayland' >> /etc/portage/package.use/kguiaddons && \
    echo 'kde-frameworks/sonnet qml' >> /etc/portage/package.use/sonnet && \
    echo 'kde-frameworks/kimageformats avif' >> /etc/portage/package.use/kimageformats && \
    echo 'kde-frameworks/prison qml' >> /etc/portage/package.use/prison && \
    echo 'dev-libs/qcoro dbus' >> /etc/portage/package.use/qcoro && \
    echo 'x11-base/xwayland libei' >> /etc/portage/package.use/xwayland && \
    echo 'sys-libs/zlib minizip' >> /etc/portage/package.use/zlib && \
    echo 'dev-qt/qt5compat qml icu' >> /etc/portage/package.use/qt5compat && \
    echo 'dev-qt/qtdeclarative vulkan opengl' >> /etc/portage/package.use/qtdeclarative && \
    # Accept fcitx ecosystem for arm64 (keyword missing on this arch)
    echo 'app-i18n/fcitx* **' >> /etc/portage/package.accept_keywords/fcitx

# ── ONE emerge: all packages together (Catalyst-style) ──────────────────
# This avoids USE flag conflicts between incremental emerges.
# Portage resolves the full dependency tree once.
RUN --mount=type=cache,target=/var/cache/distfiles,sharing=locked \
    emerge --newuse --backtrack=100 \
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
        x11-base/xorg-server \
        x11-apps/xrandr \
        x11-apps/xset \
        x11-apps/xrdb \
        media-fonts/noto \
        media-fonts/noto-cjk \
        media-fonts/noto-emoji \
        media-video/pipewire \
        media-video/wireplumber \
        media-libs/libpulse \
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
        app-i18n/fcitx \
        app-i18n/fcitx-chinese-addons \
        app-i18n/fcitx-configtool \
        app-i18n/fcitx-rime \
        sys-devel/gcc \
        dev-build/cmake \
        llvm-core/clang \
        llvm-core/llvm \
        dev-lang/python \
        dev-python/pip \
        dev-debug/strace \
        && rm -rf /var/cache/distfiles/* /var/cache/binpkgs/* /var/tmp/portage/*

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
    usermod -aG wheel,audio,video,input ${USERNAME} && \
    echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

# Environment variables
RUN cat <<'EOF' > /etc/profile.d/custom_env.sh
export XCURSOR_SIZE=48
export DISPLAY=:5
EOF

# PulseAudio config
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo "export PULSE_SERVER=unix:/tmp/.pulse-socket" >> /etc/profile.d/custom_env.sh; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo "export PULSE_SERVER=tcp:127.0.0.1:4713" >> /etc/profile.d/custom_env.sh; \
    fi && \
    chmod +x /etc/profile.d/custom_env.sh

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
usermod -a -G aid_inet,aid_net_raw,input,video,tty root || true

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

# Create plasma-x11 systemd service (autostart KDE on boot)
RUN printf '[Unit]\nDescription=Start Plasma X11\nAfter=network.target dbus.service\n\n[Service]\nType=simple\nUser=%s\nEnvironmentFile=-/etc/environment\nExecStart=/bin/bash -lc '\''DISPLAY=:5 startplasma-x11'\''\nRestart=no\nRestartSec=3\n\n[Install]\nWantedBy=multi-user.target\n' "${USERNAME}" > /etc/systemd/system/plasma-x11.service && \
    mkdir -p /etc/systemd/system/multi-user.target.wants && \
    ln -sf /etc/systemd/system/plasma-x11.service /etc/systemd/system/multi-user.target.wants/plasma-x11.service

# Set ownership of home directory
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Final cleanup — strip all build-time cruft
RUN rm -rf \
    /var/cache/distfiles/* \
    /var/cache/binpkgs/* \
    /var/tmp/portage/* \
    /var/cache/edb/* \
    /var/db/repos/gentoo \
    /usr/portage \
    /var/log/*.log \
    /var/log/portage \
    /usr/share/gtk-doc \
    /usr/share/doc/* \
    /usr/share/man/* \
    /usr/share/info/* \
    && find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'zh*' -exec rm -rf {} + \
    && find /usr/lib* -name '*.la' -delete \
    && find /usr/lib* -name '*.a' ! -name 'crt*.a' ! -name 'libpthread*.a' -delete \
    && find /usr -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /usr -name '*.pyc' -delete 2>/dev/null || true \
    && find /usr -name '*.pyo' -delete 2>/dev/null || true

# Stage 2: Export to scratch for extraction
FROM scratch AS export

# Copy the entire filesystem from the customizer stage
COPY --from=customizer / /
