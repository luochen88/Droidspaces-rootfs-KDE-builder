ARG TARGETPLATFORM
FROM gentoo/stage3:nomultilib-systemd AS customizer

ARG USERNAME=Gold
ARG PulseAudio=socket
ARG ENABLE_zh_tz_ARG=true
ARG ENABLE_yj_ARG=true
ARG ENABLE_mesa_ARG=true
ARG ENABLE_binfmt_ARG=false
ARG GENTOO_COMMON_FLAGS="-O2 -pipe -march=armv8-a"
ARG GENTOO_MAKEOPTS="-j4"
ARG GENTOO_USE="dbus systemd pipewire pulseaudio opengl vulkan wayland X -gnome -gtk-doc -test"
ARG GENTOO_VIDEO_CARDS="freedreno"
ARG GENTOO_INPUT_DEVICES="libinput evdev"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY scripts/bashrc.sh /etc/profile.d/ds-aliases.sh
COPY scripts/binfmt/qemu-binfmt-register.sh /usr/local/bin/
COPY scripts/binfmt/qemu-binfmt-register.service /etc/systemd/system/

RUN chmod +x /etc/profile.d/ds-aliases.sh /usr/local/bin/qemu-binfmt-register.sh && \
    mkdir -p /etc/portage /etc/droidspaces /usr/local/sbin /etc/systemd/network /etc/systemd/system/multi-user.target.wants && \
    cat > /etc/portage/make.conf <<EOF
COMMON_FLAGS="${GENTOO_COMMON_FLAGS}"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"
MAKEOPTS="${GENTOO_MAKEOPTS}"
USE="${GENTOO_USE}"
VIDEO_CARDS="${GENTOO_VIDEO_CARDS}"
INPUT_DEVICES="${GENTOO_INPUT_DEVICES}"
ACCEPT_LICENSE="*"
FEATURES="parallel-fetch getbinpkg binpkg-request-signature"
EMERGE_DEFAULT_OPTS="--jobs=4 --load-average=4 --binpkg-respect-use=y --usepkg --verbose-conflicts"
GENTOO_MIRRORS="https://distfiles.gentoo.org"
EOF

RUN cat > /usr/local/sbin/ds-apply-optimizations <<'EOF'
#!/bin/bash
set -euo pipefail

ENV_FILE="${1:-/etc/droidspaces/optimization.env}"
MAKE_CONF="/etc/portage/make.conf"
RUNTIME_ENV="/etc/environment"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "optimization env not found: $ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

COMMON_FLAGS="${GENTOO_COMMON_FLAGS:-${COMMON_FLAGS:-}}"
MAKEOPTS_VALUE="${GENTOO_MAKEOPTS:-${MAKEOPTS:-}}"
USE_VALUE="${GENTOO_USE:-${USE:-}}"
VIDEO_CARDS_VALUE="${GENTOO_VIDEO_CARDS:-${VIDEO_CARDS:-}}"
INPUT_DEVICES_VALUE="${GENTOO_INPUT_DEVICES:-${INPUT_DEVICES:-}}"

TMP="$(mktemp)"
awk '
  /^# BEGIN DROIDSPACES OPTIMIZATION$/ { skip=1; next }
  /^# END DROIDSPACES OPTIMIZATION$/ { skip=0; next }
  skip == 0 { print }
' "$MAKE_CONF" > "$TMP"
{
  echo "# BEGIN DROIDSPACES OPTIMIZATION"
  [[ -n "$COMMON_FLAGS" ]] && echo "COMMON_FLAGS=\"$COMMON_FLAGS\""
  [[ -n "$COMMON_FLAGS" ]] && echo 'CFLAGS="${COMMON_FLAGS}"'
  [[ -n "$COMMON_FLAGS" ]] && echo 'CXXFLAGS="${COMMON_FLAGS}"'
  [[ -n "$COMMON_FLAGS" ]] && echo 'FCFLAGS="${COMMON_FLAGS}"'
  [[ -n "$COMMON_FLAGS" ]] && echo 'FFLAGS="${COMMON_FLAGS}"'
  [[ -n "$MAKEOPTS_VALUE" ]] && echo "MAKEOPTS=\"$MAKEOPTS_VALUE\""
  [[ -n "$USE_VALUE" ]] && echo "USE=\"$USE_VALUE\""
  [[ -n "$VIDEO_CARDS_VALUE" ]] && echo "VIDEO_CARDS=\"$VIDEO_CARDS_VALUE\""
  [[ -n "$INPUT_DEVICES_VALUE" ]] && echo "INPUT_DEVICES=\"$INPUT_DEVICES_VALUE\""
  echo "# END DROIDSPACES OPTIMIZATION"
} >> "$TMP"
install -m 0644 "$TMP" "$MAKE_CONF"
rm -f "$TMP"

if [[ "${DROIDSPACES_KGSL:-}" == "1" ]]; then
  grep -q '^MESA_LOADER_DRIVER_OVERRIDE=' "$RUNTIME_ENV" 2>/dev/null || echo 'MESA_LOADER_DRIVER_OVERRIDE=kgsl' >> "$RUNTIME_ENV"
  grep -q '^GALLIUM_DRIVER=' "$RUNTIME_ENV" 2>/dev/null || echo 'GALLIUM_DRIVER=kgsl' >> "$RUNTIME_ENV"
  grep -q '^FD_FORCE_KGSL=' "$RUNTIME_ENV" 2>/dev/null || echo 'FD_FORCE_KGSL=1' >> "$RUNTIME_ENV"
  grep -q '^TU_DEBUG=' "$RUNTIME_ENV" 2>/dev/null || echo 'TU_DEBUG=noconform' >> "$RUNTIME_ENV"
fi

echo "Applied Droidspaces optimization from $ENV_FILE"
EOF

RUN chmod +x /usr/local/sbin/ds-apply-optimizations && \
    cat > /etc/droidspaces/optimization.env.example <<'EOF'
# Copy to /etc/droidspaces/optimization.env, edit for the target device,
# then run: ds-apply-optimizations
GENTOO_COMMON_FLAGS="-O2 -pipe -march=armv8-a"
GENTOO_MAKEOPTS="-j4"
GENTOO_USE="dbus systemd pipewire pulseaudio opengl vulkan wayland X -gnome -gtk-doc -test"
GENTOO_VIDEO_CARDS="freedreno"
GENTOO_INPUT_DEVICES="libinput evdev"
DROIDSPACES_KGSL=1
EOF

RUN if [[ "${ENABLE_zh_tz_ARG}" == "true" ]]; then \
      ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
      echo 'Asia/Shanghai' > /etc/timezone && \
      grep -q '^zh_CN.UTF-8 UTF-8' /etc/locale.gen || echo 'zh_CN.UTF-8 UTF-8' >> /etc/locale.gen && \
      echo 'LANG=zh_CN.UTF-8' > /etc/locale.conf && \
      echo 'LC_ALL=zh_CN.UTF-8' >> /etc/locale.conf; \
    else \
      echo 'LANG=en_US.UTF-8' > /etc/locale.conf && \
      echo 'LC_ALL=en_US.UTF-8' >> /etc/locale.conf; \
    fi && \
    grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && \
    locale-gen && \
    useradd -m -s /bin/bash "${USERNAME}" && \
    echo "${USERNAME}:1234" | chpasswd && \
    getent group wheel >/dev/null && gpasswd -a "${USERNAME}" wheel || true && \
    if [[ -f /etc/sudoers ]]; then sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || true; fi

RUN cat > /etc/environment <<EOF
XCURSOR_SIZE=48
DISPLAY=:5
EOF

RUN if [[ "${PulseAudio}" == "socket" ]]; then \
      echo 'PULSE_SERVER=unix:/tmp/.pulse-socket' >> /etc/environment; \
    elif [[ "${PulseAudio}" == "tcp" ]]; then \
      echo 'PULSE_SERVER=tcp:127.0.0.1:4713' >> /etc/environment; \
    fi && \
    if [[ "${ENABLE_mesa_ARG}" == "true" ]]; then \
      printf '%s\n' \
        'MESA_LOADER_DRIVER_OVERRIDE=kgsl' \
        'GALLIUM_DRIVER=kgsl' \
        'FD_FORCE_KGSL=1' \
        'TU_DEBUG=noconform' >> /etc/environment; \
    fi

RUN cat > /etc/systemd/network/10-eth-dhcp.network <<'EOF'
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

RUN grep -q '^aid_inet:' /etc/group || echo 'aid_inet:x:3003:' >> /etc/group && \
    grep -q '^aid_net_raw:' /etc/group || echo 'aid_net_raw:x:3004:' >> /etc/group && \
    grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:' >> /etc/group && \
    getent group input >/dev/null || groupadd -r input && \
    getent group video >/dev/null || groupadd -r video && \
    getent group droidspaces-gpu >/dev/null || groupadd -g 786 -r droidspaces-gpu && \
    usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root || true && \
    usermod -a -G aid_inet,aid_net_raw,input,video,tty,wheel,droidspaces-gpu "${USERNAME}" || true && \
    ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service && \
    ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket && \
    mkdir -p /etc/systemd/journald.conf.d /etc/systemd/logind.conf.d /etc/systemd/system/multi-user.target.wants && \
    cat > /etc/systemd/journald.conf.d/ds-logging.conf <<'EOF'
[Journal]
ReadKMsg=no
Audit=no
Storage=volatile
SystemMaxUse=200M
RuntimeMaxUse=200M
MaxRetentionSec=7day
MaxLevelStore=info
EOF

RUN cat > /etc/systemd/logind.conf.d/99-power-key.conf <<'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKeyLongPress=ignore
HandlePowerKeyLongPressHibernate=ignore
EOF

RUN GUEST_SYSTEMD_PATH="/usr/lib/systemd/system" && \
    for service in dbus.service systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do \
      if [[ "${ENABLE_yj_ARG}" == "true" && -f "${GUEST_SYSTEMD_PATH}/${service}" ]]; then \
        ln -sf "${GUEST_SYSTEMD_PATH}/${service}" "/etc/systemd/system/multi-user.target.wants/${service}"; \
      elif [[ "${ENABLE_yj_ARG}" != "true" && "${service}" != "dbus.service" ]]; then \
        ln -sf /dev/null "/etc/systemd/system/${service}"; \
      fi; \
    done && \
    mkdir -p /etc/systemd/system/systemd-udev-trigger.service.d && \
    cat > /etc/systemd/system/systemd-udev-trigger.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net
EOF

RUN for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-kernel.socket systemd-udevd-control.socket; do \
      mkdir -p "/etc/systemd/system/${unit}.d"; \
      printf '[Unit]\nConditionPathIsReadWrite=\n' > "/etc/systemd/system/${unit}.d/99-readonly-fix.conf"; \
    done && \
    for unit in NetworkManager.service dhcpcd.service systemd-resolved.service systemd-networkd.service; do \
      mkdir -p "/etc/systemd/system/${unit}.d"; \
      printf '%s\n' '[Service]' 'ExecCondition=' 'ExecCondition=/bin/sh -c "grep -qE '\''net_mode=(nat|gateway)'\'' /run/droidspaces/container.config"' > "/etc/systemd/system/${unit}.d/99-netmode-limit.conf"; \
    done && \
    for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service; do \
      mkdir -p "/etc/systemd/system/${unit}.d"; \
      printf '%s\n' '[Service]' 'ExecCondition=' 'ExecCondition=/bin/sh -c "grep -q '\''enable_hw_access=1'\'' /run/droidspaces/container.config"' > "/etc/systemd/system/${unit}.d/99-hwaccess-limit.conf"; \
    done && \
    if [[ "${ENABLE_binfmt_ARG}" == "true" ]]; then \
      chmod 644 /etc/systemd/system/qemu-binfmt-register.service && \
      ln -sf /etc/systemd/system/qemu-binfmt-register.service /etc/systemd/system/multi-user.target.wants/qemu-binfmt-register.service; \
    else \
      rm -f /usr/local/bin/qemu-binfmt-register.sh /etc/systemd/system/qemu-binfmt-register.service; \
    fi && \
    echo "Post-extraction fixes applied on $(date)" > /etc/droidspaces/build-info && \
    rm -rf /var/cache/binpkgs/* /var/tmp/portage/* /tmp/*

FROM scratch AS export
COPY --from=customizer / /
