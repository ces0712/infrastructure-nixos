#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

PI_HOST="${PI_HOST:?PI_HOST is required}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"

ssh_ctx="$(ssh_target "${DEPLOY_USER}" "${PI_HOST}" "${IDENTITY_FILE}")"
SSH_OPTS="${ssh_ctx%%|*}"
TARGET="${ssh_ctx#*|}"

remote_run "${SSH_OPTS}" "${TARGET}" '
set -eu

ROOT_SOURCE="$(findmnt -n -o SOURCE /)"
ROOT_DISK="$(lsblk -no PKNAME "${ROOT_SOURCE}" 2>/dev/null || true)"
BOOT_SOURCE="$(findmnt -n -o SOURCE /boot 2>/dev/null || true)"
if [ -z "${BOOT_SOURCE}" ]; then
  BOOT_SOURCE="$(findmnt -n -o SOURCE /boot/firmware 2>/dev/null || true)"
fi

echo "hostname: $(hostname)"
echo "root-source: ${ROOT_SOURCE}"
echo "root-disk: ${ROOT_DISK:-unknown}"
echo "boot-source: ${BOOT_SOURCE:-not-mounted}"
echo
echo "disk layout:"
lsblk -o NAME,PARTLABEL,LABEL,FSTYPE,MOUNTPOINTS
'
