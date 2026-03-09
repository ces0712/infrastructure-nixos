#!/bin/sh
set -eu

PI_HOST="${PI_HOST:?PI_HOST is required}"
BOOTSTRAP_USER="${BOOTSTRAP_USER:-root}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
SSD_DEVICE="${SSD_DEVICE:-/dev/sda}"

TARGET="${BOOTSTRAP_USER}@${PI_HOST}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=yes -o ConnectTimeout=10"

if [ -n "${IDENTITY_FILE}" ]; then
  SSH_OPTS="${SSH_OPTS} -o IdentityFile=${IDENTITY_FILE} -o IdentitiesOnly=yes"
fi

ssh ${SSH_OPTS} "${TARGET}" SSD_DEVICE="${SSD_DEVICE}" 'sh -s' <<'EOF'
set -eu

disk="${SSD_DEVICE}"

if [ ! -b "${disk}" ]; then
  echo "error: ${disk} was not found on the remote host" >&2
  exit 1
fi

if command -v systemd-repart >/dev/null 2>&1; then
  repart_path="$(command -v systemd-repart)"
else
  repart_path="not-installed"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemd_version="$(systemctl --version | awk 'NR==1 {print $2}')"
else
  systemd_version="unknown"
fi

partition_table="$(
  parted -s "${disk}" print 2>/dev/null | awk -F': ' '/Partition Table/ {print $2}'
)"

root_source="$(findmnt -n -o SOURCE / || true)"

echo "host: $(hostname)"
echo "target-disk: ${disk}"
echo "live-root: ${root_source:-unknown}"
echo "systemd-version: ${systemd_version}"
echo "systemd-repart: ${repart_path}"
echo "partition-table: ${partition_table:-unknown}"
echo
echo "current-disk-layout:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS "${disk}"
echo

case "${partition_table:-unknown}" in
  gpt)
    echo "repart-status: candidate"
    echo "reason: disk uses GPT, so a hybrid systemd-repart experiment is technically possible."
    ;;
  msdos|dos)
    echo "repart-status: blocked"
    echo "reason: current flashed sd-image uses an MBR/DOS partition table; systemd-repart requires GPT."
    ;;
  *)
    echo "repart-status: unknown"
    echo "reason: could not determine a supported partition table from parted output."
    ;;
esac
EOF
