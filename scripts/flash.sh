#!/bin/sh
set -eu

. "$(dirname "$0")/libmedia.sh"

DEVICE="${DEVICE:-${SSD_DEVICE:-/dev/disk4}}"
IMAGE_PATH="${IMAGE_PATH:-output/nixos-pi.img}"

if [ ! -f "${IMAGE_PATH}" ]; then
  echo "Error: ${IMAGE_PATH} not found. Run 'just build' first."
  exit 1
fi

require_block_device "${DEVICE}"

RAW_DEVICE="$(echo "${DEVICE}" | sed 's|/dev/disk|/dev/rdisk|')"

echo "Flashing ${IMAGE_PATH} to ${DEVICE}"
echo "This wrapper runs: diskutil unmountDisk + dd + diskutil eject"
confirm_continue

diskutil unmountDisk "${DEVICE}"
sudo dd if="${IMAGE_PATH}" of="${RAW_DEVICE}" bs=4m status=progress conv=fsync
sync
diskutil eject "${DEVICE}" || true

echo "Flash complete: ${DEVICE}"
