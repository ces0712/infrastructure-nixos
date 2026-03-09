#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

PI_HOST="${PI_HOST:?PI_HOST is required}"
BOOTSTRAP_USER="${BOOTSTRAP_USER:-root}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
SSD_DEVICE="${SSD_DEVICE:-/dev/sda}"
ROOT_SIZE_GIB="${ROOT_SIZE_GIB:-200}"
BOOTSTRAP_POWEROFF="${BOOTSTRAP_POWEROFF:-1}"

ssh_ctx="$(ssh_target "${BOOTSTRAP_USER}" "${PI_HOST}" "${IDENTITY_FILE}")"
SSH_OPTS="${ssh_ctx%%|*}"
TARGET="${ssh_ctx#*|}"

echo "Preparing flashed SSD ${SSD_DEVICE} on ${TARGET}..."
echo "Bootstrap expects:"
echo "  ${SSD_DEVICE}1 -> flashed FIRMWARE"
echo "  ${SSD_DEVICE}2 -> flashed NIXOS_SD"
echo "Bootstrap will keep 1-2, grow 2, and recreate:"
echo "  ${SSD_DEVICE}3 -> NIXOS_DATA"

remote_prefix="env SSD_DEVICE='${SSD_DEVICE}' ROOT_SIZE_GIB='${ROOT_SIZE_GIB}' BOOTSTRAP_POWEROFF='${BOOTSTRAP_POWEROFF}'"
if [ "${BOOTSTRAP_USER}" = "root" ]; then
  remote_cmd="${remote_prefix} forgejo-pi-bootstrap-partition"
else
  remote_cmd="sudo ${remote_prefix} forgejo-pi-bootstrap-partition"
fi

remote_run "${SSH_OPTS}" "${TARGET}" "${remote_cmd}"
