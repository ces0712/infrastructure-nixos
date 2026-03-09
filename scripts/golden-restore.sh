#!/bin/sh
set -eu

GOLDEN_DEVICE="${GOLDEN_DEVICE:-/dev/disk4}"
GOLDEN_IMAGE="${GOLDEN_IMAGE:-}"

if [ -z "${GOLDEN_IMAGE}" ]; then
  echo "Error: GOLDEN_IMAGE is required."
  echo "Example: GOLDEN_IMAGE=output/golden-20260301-120000.img.zst"
  exit 1
fi

if [ ! -f "${GOLDEN_IMAGE}" ]; then
  echo "Error: image not found: ${GOLDEN_IMAGE}"
  exit 1
fi

if [ ! -b "${GOLDEN_DEVICE}" ]; then
  echo "Error: device not found: ${GOLDEN_DEVICE}"
  exit 1
fi

DISK_ID="$(echo "${GOLDEN_DEVICE}" | sed 's|/dev/||')"

if mount | grep -q "^/dev/${DISK_ID}"; then
  echo "Error: ${GOLDEN_DEVICE} has mounted partitions."
  echo "Run: diskutil unmountDisk ${GOLDEN_DEVICE}"
  exit 1
fi

echo "Restoring golden image to ${GOLDEN_DEVICE}"
echo "Image: ${GOLDEN_IMAGE}"
echo "WARNING: this will erase all data on ${GOLDEN_DEVICE}"
echo "Press ENTER to continue or Ctrl+C to abort"
read -r

case "${GOLDEN_IMAGE}" in
  *.zst)
    if ! command -v zstd >/dev/null 2>&1; then
      echo "Error: zstd is required to restore .zst images."
      exit 1
    fi
    zstd -dc "${GOLDEN_IMAGE}" | sudo dd of="${GOLDEN_DEVICE}" bs=4m status=progress
    ;;
  *.gz)
    gzip -dc "${GOLDEN_IMAGE}" | sudo dd of="${GOLDEN_DEVICE}" bs=4m status=progress
    ;;
  *.img)
    sudo dd if="${GOLDEN_IMAGE}" of="${GOLDEN_DEVICE}" bs=4m status=progress
    ;;
  *)
    echo "Error: unsupported image extension (use .img, .img.gz, or .img.zst)"
    exit 1
    ;;
esac

echo "Golden image restored to ${GOLDEN_DEVICE}"
