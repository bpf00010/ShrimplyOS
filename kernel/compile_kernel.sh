#!/usr/bin/env bash
# 🦐 Shrimply OS: Custom Kernel Compilation (LFS Style) 🦐
set -e

KERNEL_VERSION="6.6.15"
KERNEL_TARBALL="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TARBALL}"

echo "🦐 Fetching the Linux Kernel source (${KERNEL_VERSION})..."
wget -c $KERNEL_URL
tar -xf $KERNEL_TARBALL
cd linux-${KERNEL_VERSION}

echo "🦐 Applying Shrimply OS minimal kernel configuration..."
cp ../.config .config

echo "🦐 Compiling the kernel (this may take a while)..."
make olddefconfig
make -j$(nproc)

echo "🦐 Installing kernel modules..."
make modules_install

echo "🦐 Installing the kernel..."
make install

echo "🦐 Kernel compilation and installation complete!"
