#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

PI_HOST="${PI_HOST:?PI_HOST is required}"
BOOTSTRAP_USER="${BOOTSTRAP_USER:-root}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
SSD_DEVICE="${SSD_DEVICE:-/dev/sda}"
ROOT_SIZE_GIB="${ROOT_SIZE_GIB:-200}"
BOOTSTRAP_POWEROFF="${BOOTSTRAP_POWEROFF:-1}"

TARGET="$(target_host "${BOOTSTRAP_USER}" "${PI_HOST}")"

echo "Preparing flashed SSD ${SSD_DEVICE} on ${TARGET}..."
echo "Bootstrap expects:"
echo "  ${SSD_DEVICE}1 -> flashed FIRMWARE"
echo "  ${SSD_DEVICE}2 -> flashed NIXOS_SD"
echo "Bootstrap will keep 1-2, grow 2, and recreate:"
echo "  ${SSD_DEVICE}3 -> NIXOS_DATA"

ssh_opts="$(standard_ssh_opts "${IDENTITY_FILE}")"

ssh ${ssh_opts} "${TARGET}" \
  SSD_DEVICE="${SSD_DEVICE}" ROOT_SIZE_GIB="${ROOT_SIZE_GIB}" BOOTSTRAP_POWEROFF="${BOOTSTRAP_POWEROFF}" \
  'sh -s' <<'EOF'
set -eu

if [ "$(id -u)" -ne 0 ]; then
  exec sudo env \
    SSD_DEVICE="${SSD_DEVICE}" \
    ROOT_SIZE_GIB="${ROOT_SIZE_GIB}" \
    BOOTSTRAP_POWEROFF="${BOOTSTRAP_POWEROFF}" \
    forgejo-pi-bootstrap-partition
else
  exec env \
    SSD_DEVICE="${SSD_DEVICE}" \
    ROOT_SIZE_GIB="${ROOT_SIZE_GIB}" \
    BOOTSTRAP_POWEROFF="${BOOTSTRAP_POWEROFF}" \
    forgejo-pi-bootstrap-partition
fi
EOF
