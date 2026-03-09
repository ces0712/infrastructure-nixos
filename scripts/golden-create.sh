#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

DEVICE="${DEVICE:-${GOLDEN_DEVICE:-/dev/disk4}}"
GOLDEN_IMAGE="${GOLDEN_IMAGE:-output/golden-$(date +%Y%m%d-%H%M%S).img.zst}"

require_block_device "${DEVICE}"
require_unmounted_disk "${DEVICE}"

mkdir -p "$(dirname "${GOLDEN_IMAGE}")"

echo "Creating golden image from ${DEVICE}"
echo "Output: ${GOLDEN_IMAGE}"
confirm_continue

if command -v zstd >/dev/null 2>&1; then
  sudo dd if="${DEVICE}" bs=4m status=progress | zstd -T0 -10 -o "${GOLDEN_IMAGE}"
elif command -v gzip >/dev/null 2>&1; then
  case "${GOLDEN_IMAGE}" in
    *.gz) : ;;
    *)
      GOLDEN_IMAGE="${GOLDEN_IMAGE}.gz"
      echo "zstd not found; writing gzip image: ${GOLDEN_IMAGE}"
      ;;
  esac
  sudo dd if="${DEVICE}" bs=4m status=progress | gzip -1 > "${GOLDEN_IMAGE}"
else
  echo "Error: neither zstd nor gzip found."
  exit 1
fi

echo "Golden image created: ${GOLDEN_IMAGE}"
