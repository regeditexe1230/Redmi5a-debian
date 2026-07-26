#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="$SCRIPT_DIR/rootfs"
BOOT="$SCRIPT_DIR/boot"
OUTPUT="$SCRIPT_DIR/debian-riva.img"

echo "=== 计算大小 ==="
ROOT_USED=$(du -sm "$ROOTFS" | cut -f1)
ROOT_SIZE=$((ROOT_USED + 200))
BOOT_SIZE=300
TOTAL=$((BOOT_SIZE + ROOT_SIZE + 10))
echo "RootFS: ${ROOT_USED}MB → 分配 ${ROOT_SIZE}MB"
echo "Boot: ${BOOT_SIZE}MB"
echo "镜像总大小: ${TOTAL}MB"

echo ""
echo "=== 创建空白镜像 ==="
rm -f "$OUTPUT"
dd if=/dev/zero of="$OUTPUT" bs=1M count=$TOTAL status=none

echo "=== 分区 ==="
parted -s "$OUTPUT" mklabel msdos
parted -s "$OUTPUT" mkpart primary ext2 1 ${BOOT_SIZE}
parted -s "$OUTPUT" mkpart primary ext4 ${BOOT_SIZE} 100%
parted -s "$OUTPUT" set 1 boot on

echo "=== 格式化 ==="
LOOP=$(losetup --show -fP "$OUTPUT")
mkfs.ext2 -L pmOS_boot ${LOOP}p1 -q
mkfs.ext4 -L pmOS_root ${LOOP}p2 -q

echo "=== 写入 rootfs ==="
mkdir -p /tmp/riva-mnt
mount ${LOOP}p2 /tmp/riva-mnt
rsync -a "$ROOTFS/" /tmp/riva-mnt/
umount /tmp/riva-mnt

echo "=== 写入 boot ==="
mount ${LOOP}p1 /tmp/riva-mnt
cp "$BOOT/vmlinuz" /tmp/riva-mnt/
cp "$BOOT/initramfs" /tmp/riva-mnt/
cp "$BOOT/initramfs-extra" /tmp/riva-mnt/
mkdir -p /tmp/riva-mnt/dtbs /tmp/riva-mnt/extlinux
cp "$BOOT/dtbs/"* /tmp/riva-mnt/dtbs/

# 获取实际分区 UUID
BOOT_UUID=$(blkid -s UUID -o value ${LOOP}p1)
ROOT_UUID=$(blkid -s UUID -o value ${LOOP}p2)

cat > /tmp/riva-mnt/extlinux/extlinux.conf << XF
TIMEOUT 1
DEFAULT riva

LABEL riva
    KERNEL /vmlinuz
    INITRD /initramfs
    FDTDIR /dtbs
    APPEND pmos_root_uuid=$ROOT_UUID pmos_boot_uuid=$BOOT_UUID rootwait rw console=ttyMSM0,115200 force_partition_resize=y quiet
XF

echo "extlinux.conf:"
cat /tmp/riva-mnt/extlinux/extlinux.conf

umount /tmp/riva-mnt
losetup -d $LOOP

echo ""
echo "==================================="
echo "构建完成: $OUTPUT"
ls -lh "$OUTPUT"
echo "==================================="
