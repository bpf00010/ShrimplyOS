#!/usr/bin/env bash
# 🦐 Shrimply OS: Boot Image Build Script (live-build) 🦐
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${1:-$PROJECT_ROOT/build/live-build}"
OUTPUT_DIR="${2:-$PROJECT_ROOT/build/artifacts}"
ISO_NAME="shrimplyos-bookworm-amd64.iso"

if ! command -v lb >/dev/null 2>&1; then
  echo "live-build is required. Install with: sudo apt-get install -y live-build"
  exit 1
fi

for required_cmd in mksquashfs xorriso; do
  if ! command -v "$required_cmd" >/dev/null 2>&1; then
    echo "Missing required host tool: $required_cmd"
    echo "Install with: sudo apt-get install -y squashfs-tools xorriso syslinux-utils"
    exit 1
  fi
done

SHIM_DIR="$BUILD_ROOT/.toolshim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/isohybrid" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$SHIM_DIR/isohybrid"

echo "🦐 Preparing live-build workspace..."
rm -rf "$BUILD_ROOT"
mkdir -p \
  "$BUILD_ROOT/config/package-lists" \
  "$BUILD_ROOT/config/archives" \
  "$BUILD_ROOT/config/includes.chroot/etc/lightdm" \
  "$BUILD_ROOT/config/includes.chroot/usr/bin" \
  "$BUILD_ROOT/config/includes.chroot/usr/local/sbin" \
  "$BUILD_ROOT/config/hooks/normal" \
  "$OUTPUT_DIR"

cp "$PROJECT_ROOT/configs/lightdm.conf" "$BUILD_ROOT/config/includes.chroot/etc/lightdm/lightdm.conf"
cp "$PROJECT_ROOT/assets/lightdm-crustacean-theme.conf" "$BUILD_ROOT/config/includes.chroot/etc/lightdm/lightdm-gtk-greeter.conf"

cat > "$BUILD_ROOT/config/package-lists/shrimply-core.list.chroot" <<'EOF'
linux-image-amd64
systemd-sysv
pciutils
whiptail
dialog
xserver-xorg-core
lightdm
lightdm-gtk-greeter
xfce4-session
xfwm4
xfce4-panel
xfce4-terminal
live-boot
live-config
nvidia-detect
syslinux-utils
EOF

cat > "$BUILD_ROOT/config/archives/00-security.list.chroot" <<'EOF'
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

cat > "$BUILD_ROOT/config/archives/00-security.list.binary" <<'EOF'
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

cat > "$BUILD_ROOT/config/hooks/normal/010-shrimply-tui-default.hook.chroot" <<'EOF'
#!/bin/sh
set -e
systemctl set-default multi-user.target
if ! grep -q '/usr/local/sbin/shrimply-hardware-detect.sh' /root/.profile 2>/dev/null; then
  echo '/usr/local/sbin/shrimply-hardware-detect.sh' >> /root/.profile
fi
EOF
chmod +x "$BUILD_ROOT/config/hooks/normal/010-shrimply-tui-default.hook.chroot"

cat > "$BUILD_ROOT/config/hooks/normal/011-shrimply-isohybrid-fix.hook.chroot" <<'EOF'
#!/bin/sh
set -e
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends syslinux-utils
if [ -x /usr/bin/isohybrid.pl ] && [ ! -x /usr/bin/isohybrid ]; then
  ln -s /usr/bin/isohybrid.pl /usr/bin/isohybrid
fi
EOF
chmod +x "$BUILD_ROOT/config/hooks/normal/011-shrimply-isohybrid-fix.hook.chroot"

cat > "$BUILD_ROOT/config/includes.chroot/usr/local/sbin/shrimply-hardware-detect.sh" <<'EOF'
#!/bin/bash
TITLE="🦐 Shrimply OS: Molting Phase 🦐"
BACKTITLE="Shrimply OS - Bottom-Feeder Configuration Utility"

if command -v nvidia-detect >/dev/null 2>&1 && nvidia-detect >/dev/null 2>&1; then
  if whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
    --yesno "Ahoy, bottom-feeder! NVIDIA carapace detected. Install proprietary driver packages now?" 10 70; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-driver firmware-misc-nonfree || true
  fi
fi

if whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
  --yesno "Ascend to the XFCE Coral Reef now?" 9 60; then
  systemctl isolate graphical.target
fi
EOF
chmod +x "$BUILD_ROOT/config/includes.chroot/usr/local/sbin/shrimply-hardware-detect.sh"

cat > "$BUILD_ROOT/config/includes.chroot/usr/bin/isohybrid" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$BUILD_ROOT/config/includes.chroot/usr/bin/isohybrid"

cd "$BUILD_ROOT"

echo "🦐 Configuring live-build profile..."
lb config noauto \
  --mode debian \
  --distribution bookworm \
  --architectures amd64 \
  --mirror-bootstrap "http://deb.debian.org/debian/" \
  --mirror-chroot "http://deb.debian.org/debian/" \
  --mirror-chroot-security "http://security.debian.org/debian-security/" \
  --mirror-binary "http://deb.debian.org/debian/" \
  --mirror-binary-security "http://security.debian.org/debian-security/" \
  --security false \
  --linux-packages "none" \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-images iso \
  --bootloader grub \
  --debian-installer false \
  --bootappend-live "boot=live components username=shrimp hostname=shrimply"

echo "🦐 Building ISO image (this can take a while)..."
set +e
PATH="$SHIM_DIR:$PATH" lb build
LB_RC=$?
set -e

SOURCE_ISO=""
if [[ -f "$BUILD_ROOT/live-image-amd64.iso" ]]; then
  SOURCE_ISO="$BUILD_ROOT/live-image-amd64.iso"
elif [[ -f "$BUILD_ROOT/chroot/binary.hybrid.iso" ]]; then
  SOURCE_ISO="$BUILD_ROOT/chroot/binary.hybrid.iso"
elif [[ -f "$BUILD_ROOT/chroot/binary.iso" ]]; then
  SOURCE_ISO="$BUILD_ROOT/chroot/binary.iso"
fi

if [[ -z "$SOURCE_ISO" ]]; then
  echo "No ISO artifact found after lb build (exit code: $LB_RC)."
  exit 1
fi

if [[ "$LB_RC" -ne 0 ]]; then
  echo "🦐 live-build exited with code $LB_RC; salvaging ISO from $SOURCE_ISO"
fi

cp "$SOURCE_ISO" "$OUTPUT_DIR/$ISO_NAME"
sha256sum "$OUTPUT_DIR/$ISO_NAME" > "$OUTPUT_DIR/$ISO_NAME.sha256"

echo "🦐 ISO build complete: $OUTPUT_DIR/$ISO_NAME"
echo "🦐 SHA256 file: $OUTPUT_DIR/$ISO_NAME.sha256"
