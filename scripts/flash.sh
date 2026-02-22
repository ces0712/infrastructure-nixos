#!/bin/sh
set -e

SSD_DEVICE="${SSD_DEVICE:-/dev/disk4}"

if [ ! -f output/nixos-pi.img ]; then
    echo "Error: output/nixos-pi.img not found. Run 'make build' first."
    exit 1
fi

echo "⚠️  This will ERASE all data on ${SSD_DEVICE}"
echo "   Press ENTER to continue or Ctrl+C to abort"
read -r

sudo dd if=output/nixos-pi.img of=${SSD_DEVICE} bs=1M status=progress

echo "✅ Flash complete!"
echo "   Plug SSD into Pi and boot."
