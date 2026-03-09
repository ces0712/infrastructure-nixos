#!/bin/sh
set -eu

PI_HOST="${PI_HOST:?PI_HOST is required}"
BOOT_USER="${BOOT_USER:-root}"
IDENTITY_FILE="${IDENTITY_FILE:-}"

TARGET="${BOOT_USER}@${PI_HOST}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=yes -o ConnectTimeout=10"

if [ -n "${IDENTITY_FILE}" ]; then
  SSH_OPTS="${SSH_OPTS} -o IdentityFile=${IDENTITY_FILE} -o IdentitiesOnly=yes"
fi

ssh ${SSH_OPTS} "${TARGET}" '
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
