#!/bin/sh
set -eu

GOLDEN_DEVICE="${GOLDEN_DEVICE:-/dev/disk4}"
GOLDEN_IMAGE="${GOLDEN_IMAGE:-output/golden-$(date +%Y%m%d-%H%M%S).img.zst}"

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

mkdir -p "$(dirname "${GOLDEN_IMAGE}")"

echo "Creating golden image from ${GOLDEN_DEVICE}"
echo "Output: ${GOLDEN_IMAGE}"
echo "Press ENTER to continue or Ctrl+C to abort"
read -r

if command -v zstd >/dev/null 2>&1; then
  sudo dd if="${GOLDEN_DEVICE}" bs=4m status=progress | zstd -T0 -10 -o "${GOLDEN_IMAGE}"
elif command -v gzip >/dev/null 2>&1; then
  case "${GOLDEN_IMAGE}" in
    *.gz) : ;;
    *)
      GOLDEN_IMAGE="${GOLDEN_IMAGE}.gz"
      echo "zstd not found; writing gzip image: ${GOLDEN_IMAGE}"
      ;;
  esac
  sudo dd if="${GOLDEN_DEVICE}" bs=4m status=progress | gzip -1 > "${GOLDEN_IMAGE}"
else
  echo "Error: neither zstd nor gzip found."
  exit 1
fi

echo "Golden image created: ${GOLDEN_IMAGE}"
