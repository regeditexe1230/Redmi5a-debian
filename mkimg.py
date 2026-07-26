
#!/usr/bin/env python3
"""Create Android boot image for Redmi 5A (msm8917/riva)."""
import struct, os, sys

PAGE_SIZE = 2048
KERNEL_ADDR = 0x80008000
RAMDISK_ADDR = 0x82000000
TAGS_ADDR = 0x81e00000

# Paths relative to project root
ROOT = os.path.dirname(os.path.abspath(__file__))
KERNEL_IMG = os.path.join(ROOT, 'linux-6.6', 'arch', 'arm64', 'boot', 'Image.gz')
RAMDISK = os.path.join(ROOT, 'ramdisk.gz')
DT_IMG = os.path.join(ROOT, 'dt.img')
OUTPUT = os.path.join(ROOT, 'boot_new.img')

for path, name in [(KERNEL_IMG, 'kernel'), (RAMDISK, 'ramdisk'), (DT_IMG, 'dt')]:
    if not os.path.exists(path):
        print(f"ERROR: {path} not found. Run 'make kernel' first.", file=sys.stderr)
        sys.exit(1)

with open(KERNEL_IMG, 'rb') as f:
    kernel_data = f.read()
kernel_size = len(kernel_data)
print(f"kernel: {kernel_size} bytes")

with open(RAMDISK, 'rb') as f:
    ramdisk_data = f.read()
ramdisk_size = len(ramdisk_data)

with open(DT_IMG, 'rb') as f:
    dtb_data = f.read()
dt_size = len(dtb_data)

print(f"ramdisk: {ramdisk_size}, dt: {dt_size}")

pages_k = (kernel_size + PAGE_SIZE - 1) // PAGE_SIZE
pages_r = (ramdisk_size + PAGE_SIZE - 1) // PAGE_SIZE
pages_d = (dt_size + PAGE_SIZE - 1) // PAGE_SIZE if dt_size > 0 else 0

print(f"pages: k={pages_k} r={pages_r} d={pages_d}")

header = bytearray(PAGE_SIZE)
header[0:8] = b'ANDROID!'
struct.pack_into('<I', header, 8, kernel_size)
struct.pack_into('<I', header, 12, KERNEL_ADDR)
struct.pack_into('<I', header, 16, ramdisk_size)
struct.pack_into('<I', header, 20, RAMDISK_ADDR)
struct.pack_into('<I', header, 24, 0)
struct.pack_into('<I', header, 28, 0)
struct.pack_into('<I', header, 32, TAGS_ADDR)
struct.pack_into('<I', header, 36, PAGE_SIZE)
struct.pack_into('<I', header, 40, dt_size)

cmdline = b"console=tty0 root=UUID=93afcbbe-875f-49b0-83da-ee8193f20ca5 rw loglevel=3 splash"
header[64:64+len(cmdline)] = cmdline[:512]

with open(OUTPUT, 'wb') as f:
    f.write(header)
    f.write(kernel_data)
    pad = PAGE_SIZE - (kernel_size % PAGE_SIZE)
    if pad != PAGE_SIZE:
        f.write(b'\x00' * pad)
    f.write(ramdisk_data)
    pad = PAGE_SIZE - (ramdisk_size % PAGE_SIZE)
    if pad != PAGE_SIZE:
        f.write(b'\x00' * pad)
    if dt_size > 0:
        f.write(dtb_data)
        pad = PAGE_SIZE - (dt_size % PAGE_SIZE)
        if pad != PAGE_SIZE:
            f.write(b'\x00' * pad)

sz = os.path.getsize(OUTPUT)
print(f"boot_new.img: {sz} bytes")

