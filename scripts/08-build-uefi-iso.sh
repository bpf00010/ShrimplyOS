#!/usr/bin/env bash
# 🦐 Shrimply OS: UEFI-only ISO Assembler 🦐
set -euo pipefail

RUN_ROOT="${1:-/root/src/ShrimplyOS-run/build/live-build/chroot}"
OUT_DIR="${2:-/root/src/ShrimplyOS-run/build/artifacts}"
ISO_NAME="${3:-shrimplyos-bookworm-amd64-uefi.iso}"
WORK_DIR="${4:-/tmp/shrimply-uefi-iso-work}"
LIVE_USER="${LIVE_USER:-shrimp}"
LIVE_PASSWORD="${LIVE_PASSWORD:-shrimp}"

for required_cmd in xorriso grub-mkstandalone mkfs.vfat mmd mcopy dd cp unsquashfs mksquashfs chroot; do
  if ! command -v "$required_cmd" >/dev/null 2>&1; then
    echo "Missing required command: $required_cmd"
    exit 1
  fi
done

BINARY_ROOT="$RUN_ROOT/binary"
SQUASHFS="$BINARY_ROOT/live/filesystem.squashfs"

if [[ ! -f "$SQUASHFS" ]]; then
  echo "Missing live filesystem: $SQUASHFS"
  exit 1
fi

KERNEL_SRC=""
INITRD_SRC=""
for candidate in \
  "$RUN_ROOT/boot/vmlinuz-"* \
  "$RUN_ROOT/vmlinuz"; do
  if [[ -f "$candidate" ]]; then
    KERNEL_SRC="$candidate"
    break
  fi
done

for candidate in \
  "$RUN_ROOT/boot/initrd.img-"* \
  "$RUN_ROOT/initrd.img"; do
  if [[ -f "$candidate" ]]; then
    INITRD_SRC="$candidate"
    break
  fi
done

if [[ -z "$KERNEL_SRC" || -z "$INITRD_SRC" ]]; then
  echo "Unable to locate kernel/initrd in $RUN_ROOT"
  exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/iso-root"
cp -a "$BINARY_ROOT/." "$WORK_DIR/iso-root/"

SQUASHFS_IN="$WORK_DIR/iso-root/live/filesystem.squashfs"
SQUASHFS_EXTRACT="$WORK_DIR/squashfs-root"
SQUASHFS_OUT="$WORK_DIR/iso-root/live/filesystem.squashfs.new"

if [[ -f "$SQUASHFS_IN" ]]; then
  rm -rf "$SQUASHFS_EXTRACT"
  unsquashfs -d "$SQUASHFS_EXTRACT" "$SQUASHFS_IN" >/dev/null

  if [[ ! -x "$SQUASHFS_EXTRACT/usr/sbin/useradd" || ! -x "$SQUASHFS_EXTRACT/usr/sbin/chpasswd" ]]; then
    echo "Missing user management tools in squashfs root; cannot inject fallback user."
    exit 1
  fi

  if ! chroot "$SQUASHFS_EXTRACT" id -u "$LIVE_USER" >/dev/null 2>&1; then
    chroot "$SQUASHFS_EXTRACT" useradd -m -s /bin/bash "$LIVE_USER"
  fi
  printf '%s:%s\n' "$LIVE_USER" "$LIVE_PASSWORD" | chroot "$SQUASHFS_EXTRACT" chpasswd

  mksquashfs "$SQUASHFS_EXTRACT" "$SQUASHFS_OUT" -comp xz -noappend >/dev/null
  mv -f "$SQUASHFS_OUT" "$SQUASHFS_IN"
fi

mkdir -p "$WORK_DIR/iso-root/live"
cp -f "$KERNEL_SRC" "$WORK_DIR/iso-root/live/vmlinuz"
cp -f "$KERNEL_SRC" "$WORK_DIR/iso-root/live/vmlinux"
cp -f "$INITRD_SRC" "$WORK_DIR/iso-root/live/initrd.img"

mkdir -p "$WORK_DIR/grub" "$WORK_DIR/iso-root/EFI/BOOT"
cat > "$WORK_DIR/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5

menuentry "Shrimply OS (UEFI Live)" {
  if search --no-floppy --set=isoroot --file /live/vmlinuz; then
    set root=($isoroot)
    linux /live/vmlinuz boot=live components username=shrimp hostname=shrimply quiet
  elif search --no-floppy --set=isoroot --file /live/vmlinux; then
    set root=($isoroot)
    linux /live/vmlinux boot=live components username=shrimp hostname=shrimply quiet
  else
    echo "Shrimply OS boot files not found on ISO root."
    sleep 5
  fi
  initrd /live/initrd.img
}
EOF

grub-mkstandalone \
  -O x86_64-efi \
  -o "$WORK_DIR/BOOTX64.EFI" \
  "boot/grub/grub.cfg=$WORK_DIR/grub/grub.cfg"

EFI_IMG="$WORK_DIR/iso-root/EFI/BOOT/efiboot.img"
dd if=/dev/zero of="$EFI_IMG" bs=1M count=20 status=none
mkfs.vfat "$EFI_IMG" >/dev/null
mmd -i "$EFI_IMG" ::/EFI ::/EFI/BOOT
mcopy -i "$EFI_IMG" "$WORK_DIR/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI

mkdir -p "$OUT_DIR"
OUT_ISO="$OUT_DIR/$ISO_NAME"

xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "SHRIMPLY_UEFI" \
  -output "$OUT_ISO" \
  -eltorito-alt-boot \
  -e EFI/BOOT/efiboot.img \
  -no-emul-boot \
  "$WORK_DIR/iso-root" >/dev/null

sha256sum "$OUT_ISO" > "$OUT_ISO.sha256"

echo "UEFI ISO ready: $OUT_ISO"
echo "Checksum: $OUT_ISO.sha256"
