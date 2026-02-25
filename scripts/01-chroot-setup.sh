#!/usr/bin/env bash
# 🦐 Shrimply OS: Chroot Setup Script 🦐
set -e

export DEBIAN_FRONTEND=noninteractive

echo "🦐 Configuring APT sources..."
cp /tmp/configs/apt-sources.list /etc/apt/sources.list

echo "🦐 Updating package lists and installing core utilities..."
apt-get update
apt-get install -y --no-install-recommends \
    linux-image-amd64 linux-headers-amd64 \
    systemd-sysv pciutils whiptail dialog \
    xserver-xorg-core lightdm lightdm-gtk-greeter \
    xfce4-session xfwm4 xfce4-panel xfce4-terminal

echo "🦐 Applying LightDM and XFCE configurations..."
mkdir -p /etc/lightdm
cp /tmp/configs/lightdm.conf /etc/lightdm/lightdm.conf
cp /tmp/assets/lightdm-crustacean-theme.conf /etc/lightdm/lightdm-gtk-greeter.conf

# Disable graphical target by default to save RAM (TUI Fallback logic)
echo "🦐 Setting default target to multi-user (TUI)..."
systemctl set-default multi-user.target

# Setup the crustacean TUI to launch on TTY1 login
echo "🦐 Configuring TUI hardware detection on login..."
echo "/tmp/scripts/02-hardware-detect.sh" >> /root/.profile

echo "🦐 Chroot setup complete. Ready for molting phase."
