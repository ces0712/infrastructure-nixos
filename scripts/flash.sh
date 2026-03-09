#!/bin/sh
set -eu

SSD_DEVICE="${SSD_DEVICE:-/dev/disk4}"
IMAGE_PATH="${IMAGE_PATH:-output/nixos-pi.img}"

if [ ! -f "${IMAGE_PATH}" ]; then
  echo "Error: ${IMAGE_PATH} not found. Run 'just build' first."
  exit 1
fi

if [ ! -b "${SSD_DEVICE}" ]; then
  echo "Error: device not found: ${SSD_DEVICE}"
  exit 1
fi

RAW_DEVICE="$(echo "${SSD_DEVICE}" | sed 's|/dev/disk|/dev/rdisk|')"

echo "Flashing ${IMAGE_PATH} to ${SSD_DEVICE}"
echo "This wrapper runs: diskutil unmountDisk + dd + diskutil eject"
echo "Press ENTER to continue or Ctrl+C to abort"
read -r

diskutil unmountDisk "${SSD_DEVICE}"
sudo dd if="${IMAGE_PATH}" of="${RAW_DEVICE}" bs=4m status=progress conv=fsync
sync
diskutil eject "${SSD_DEVICE}" || true

echo "Flash complete: ${SSD_DEVICE}"
