#!/bin/sh

require_block_device() {
  device="$1"
  if [ ! -b "${device}" ]; then
    echo "Error: device not found: ${device}" >&2
    exit 1
  fi
}

disk_identifier() {
  device="$1"
  printf '%s' "${device#/dev/}"
}

require_unmounted_disk() {
  device="$1"
  disk_id="$(disk_identifier "${device}")"

  if mount | grep -q "^/dev/${disk_id}"; then
    echo "Error: ${device} has mounted partitions." >&2
    echo "Run: diskutil unmountDisk ${device}" >&2
    exit 1
  fi
}

confirm_continue() {
  prompt="${1:-Press ENTER to continue or Ctrl+C to abort}"
  echo "${prompt}"
  read -r
}
