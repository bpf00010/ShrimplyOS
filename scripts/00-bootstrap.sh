#!/usr/bin/env bash
# 🦐 Shrimply OS: Bootstrap Script 🦐
set -e

TARGET_DIR="/mnt/shrimply-os"
DISTRO="bookworm"
MIRROR="http://deb.debian.org/debian/"

echo "🦐 Spawning the Shrimply OS base filesystem..."
debootstrap --arch=amd64 --variant=minbase \
  --components=main,contrib,non-free,non-free-firmware \
  $DISTRO $TARGET_DIR $MIRROR

echo "🦐 Mounting virtual filesystems..."
mount --bind /dev $TARGET_DIR/dev
mount --bind /sys $TARGET_DIR/sys
mount -t proc /proc $TARGET_DIR/proc

echo "🦐 Injecting configuration and scripts into the chroot..."
cp -r ../configs $TARGET_DIR/tmp/
cp -r ../scripts $TARGET_DIR/tmp/
cp -r ../assets $TARGET_DIR/tmp/

echo "🦐 Entering the chroot environment..."
chroot $TARGET_DIR /tmp/scripts/01-chroot-setup.sh
