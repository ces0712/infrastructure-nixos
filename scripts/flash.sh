#!/bin/sh
set -e

SSD_DEVICE="${SSD_DEVICE:-/dev/disk5}"

if [ ! -f output/nixos-pi.img ]; then
    echo "Error: output/nixos-pi.img not found. Run 'just build' first."
    exit 1
fi

# Extract disk identifier (e.g., disk4 from /dev/disk4)
DISK_ID=$(echo "${SSD_DEVICE}" | sed 's|/dev/||')

# Check if any partitions are mounted
if mount | grep -q "^/dev/${DISK_ID}"; then
    echo "Error: ${SSD_DEVICE} has mounted partitions."
    echo ""
    echo "Please unmount the disk first:"
    echo "  diskutil unmountDisk ${SSD_DEVICE}"
    echo ""
    echo "Or unmount specific partitions:"
    echo "  diskutil unmount /dev/disk4s1"
    echo "  diskutil unmount /dev/disk4s2"
    exit 1
fi

echo "⚠️  This will ERASE all data on ${SSD_DEVICE}"
echo "   Press ENTER to continue or Ctrl+C to abort"
read -r

sudo dd if=output/nixos-pi.img of=${SSD_DEVICE} bs=1M status=progress

echo "✅ Flash complete!"
echo "   Plug SSD into Pi and boot."
