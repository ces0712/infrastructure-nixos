#!/bin/sh
set -eu

DEVICE="${DEVICE:-${SSD_DEVICE:-/dev/disk4}}"
IMAGE_PATH="${IMAGE_PATH:-output/nixos-pi.img}"

if [ ! -f "${IMAGE_PATH}" ]; then
  echo "Error: ${IMAGE_PATH} not found. Run 'just build' first."
  exit 1
fi

if [ ! -b "${DEVICE}" ]; then
  echo "Error: device not found: ${DEVICE}"
  exit 1
fi

RAW_DEVICE="$(echo "${DEVICE}" | sed 's|/dev/disk|/dev/rdisk|')"

echo "Flashing ${IMAGE_PATH} to ${DEVICE}"
echo "This wrapper runs: diskutil unmountDisk + dd + diskutil eject"
echo "Press ENTER to continue or Ctrl+C to abort"
read -r

diskutil unmountDisk "${DEVICE}"
sudo dd if="${IMAGE_PATH}" of="${RAW_DEVICE}" bs=4m status=progress conv=fsync
sync
diskutil eject "${DEVICE}" || true

echo "Flash complete: ${DEVICE}"
