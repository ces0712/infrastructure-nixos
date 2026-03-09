#!/bin/sh
set -eu

PI_HOST="${PI_HOST:?PI_HOST is required}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"

TARGET="${DEPLOY_USER}@${PI_HOST}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=yes -o ConnectTimeout=10"

if [ -n "${IDENTITY_FILE}" ]; then
  SSH_OPTS="${SSH_OPTS} -o IdentityFile=${IDENTITY_FILE} -o IdentitiesOnly=yes"
fi

ssh ${SSH_OPTS} "${TARGET}" '
set -eu

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

profile="$(cat /etc/forgejo-pi-profile)"
root_source="$(findmnt -n -o SOURCE /)"
root_disk="$(lsblk -no PKNAME "${root_source}" 2>/dev/null || true)"
srv_source="$(findmnt -n -o SOURCE /srv 2>/dev/null || true)"
sshd_state="$($SUDO systemctl is-active sshd || true)"
tailscaled_state="$($SUDO systemctl is-active tailscaled || true)"
forgejo_state="$($SUDO systemctl is-active forgejo || true)"

echo "hostname: $(hostname)"
echo "profile: ${profile}"
echo "root-source: ${root_source}"
echo "root-disk: ${root_disk:-unknown}"
echo "srv-source: ${srv_source:-not-mounted}"
echo "sshd: ${sshd_state}"
echo "tailscaled: ${tailscaled_state}"
echo "forgejo: ${forgejo_state}"
echo
echo "disk layout:"
lsblk -o NAME,PARTLABEL,LABEL,FSTYPE,MOUNTPOINTS

test "${profile}" = "runtime"
test "${root_disk}" = "sda"
test -n "${srv_source}"
test "${sshd_state}" = "active"
test "${tailscaled_state}" = "active"
test "${forgejo_state}" = "active"
'
