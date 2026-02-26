#!/usr/bin/env bash
# 🦐 Shrimply OS: Bootstrap Script 🦐
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_DIR="/mnt/shrimply-os"
DISTRO="bookworm"
MIRROR="http://deb.debian.org/debian/"

for required_cmd in debootstrap mount chroot cp; do
  if ! command -v "$required_cmd" >/dev/null 2>&1; then
    echo "Missing required command: $required_cmd"
    exit 1
  fi
done

cleanup() {
  set +e
  mountpoint -q "$TARGET_DIR/proc" && umount "$TARGET_DIR/proc"
  mountpoint -q "$TARGET_DIR/sys" && umount "$TARGET_DIR/sys"
  mountpoint -q "$TARGET_DIR/dev" && umount "$TARGET_DIR/dev"
}

trap cleanup EXIT

echo "🦐 Spawning the Shrimply OS base filesystem..."
debootstrap --arch=amd64 --variant=minbase \
  --components=main,contrib,non-free,non-free-firmware \
  $DISTRO $TARGET_DIR $MIRROR

echo "🦐 Mounting virtual filesystems..."
mkdir -p "$TARGET_DIR/dev" "$TARGET_DIR/sys" "$TARGET_DIR/proc"
mount --bind /dev $TARGET_DIR/dev
mount --bind /sys $TARGET_DIR/sys
mount -t proc /proc $TARGET_DIR/proc

echo "🦐 Injecting configuration and scripts into the chroot..."
cp -r "$PROJECT_ROOT/configs" "$TARGET_DIR/tmp/"
cp -r "$PROJECT_ROOT/scripts" "$TARGET_DIR/tmp/"
cp -r "$PROJECT_ROOT/assets" "$TARGET_DIR/tmp/"

echo "🦐 Entering the chroot environment..."
chroot $TARGET_DIR /tmp/scripts/01-chroot-setup.sh