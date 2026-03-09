#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

DEVICE="${DEVICE:-${GOLDEN_DEVICE:-/dev/disk4}}"
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

require_block_device "${DEVICE}"
require_unmounted_disk "${DEVICE}"

echo "Restoring golden image to ${DEVICE}"
echo "Image: ${GOLDEN_IMAGE}"
echo "WARNING: this will erase all data on ${DEVICE}"
confirm_continue

case "${GOLDEN_IMAGE}" in
  *.zst)
    if ! command -v zstd >/dev/null 2>&1; then
      echo "Error: zstd is required to restore .zst images."
      exit 1
    fi
    zstd -dc "${GOLDEN_IMAGE}" | sudo dd of="${DEVICE}" bs=4m status=progress
    ;;
  *.gz)
    gzip -dc "${GOLDEN_IMAGE}" | sudo dd of="${DEVICE}" bs=4m status=progress
    ;;
  *.img)
    sudo dd if="${GOLDEN_IMAGE}" of="${DEVICE}" bs=4m status=progress
    ;;
  *)
    echo "Error: unsupported image extension (use .img, .img.gz, or .img.zst)"
    exit 1
    ;;
esac

echo "Golden image restored to ${DEVICE}"
