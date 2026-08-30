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

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

profile="$(cat /etc/forgejo-pi-profile)"
. /etc/invidious-runtime.env

timeout 30s systemctl is-system-running --wait >/dev/null || true

root_source="$(findmnt -n -o SOURCE /)"
root_disk="$(lsblk -no PKNAME "${root_source}" 2>/dev/null || true)"
srv_source="$(findmnt -n -o SOURCE /srv 2>/dev/null || true)"
forgejo_data_dir="/srv/forgejo/data"
forgejo_data_present="no"
if $SUDO test -d "${forgejo_data_dir}"; then
  forgejo_data_present="yes"
fi
sshd_state="$($SUDO systemctl is-active sshd || true)"
tailscaled_state="$($SUDO systemctl is-active tailscaled || true)"
tailscale_serve_state="$($SUDO systemctl is-active tailscale-serve-forgejo || true)"
forgejo_state="$($SUDO systemctl is-active forgejo || true)"
postgresql_state="$($SUDO systemctl is-active postgresql || true)"
invidious_companion_state="$($SUDO systemctl is-active invidious-companion || true)"
invidious_state="$($SUDO systemctl is-active invidious || true)"

echo "hostname: $(hostname)"
echo "profile: ${profile}"
echo "root-source: ${root_source}"
echo "root-disk: ${root_disk:-unknown}"
echo "srv-source: ${srv_source:-not-mounted}"
echo "forgejo-data: ${forgejo_data_present} (${forgejo_data_dir})"
echo "sshd: ${sshd_state}"
echo "tailscaled: ${tailscaled_state}"
echo "tailscale-serve: ${tailscale_serve_state}"
echo "forgejo: ${forgejo_state}"
echo "postgresql: ${postgresql_state}"
echo "invidious-companion: ${invidious_companion_state}"
echo "invidious: ${invidious_state}"
echo
echo "disk layout:"
lsblk -o NAME,PARTLABEL,LABEL,FSTYPE,MOUNTPOINTS

test "${profile}" = "runtime"
test "${root_disk}" = "sda"
test -n "${srv_source}"
test "${sshd_state}" = "active"
test "${tailscaled_state}" = "active"
test "${tailscale_serve_state}" = "active"
test "${postgresql_state}" = "active"
test "${invidious_companion_state}" = "active"
test "${invidious_state}" = "active"
curl --fail --silent --show-error "http://127.0.0.1:${INVIDIOUS_PORT}/api/v1/stats" >/dev/null
serve_status="$($SUDO tailscale serve status)"
printf "%s\n" "${serve_status}" | grep -Fq ":${INVIDIOUS_EXTERNAL_PORT}"
printf "%s\n" "${serve_status}" | grep -Fq "127.0.0.1:${INVIDIOUS_PORT}"
if [ "${forgejo_data_present}" = "yes" ]; then
  test "${forgejo_state}" = "active"
else
  if [ "${forgejo_state}" = "active" ]; then
    echo "Forgejo data is not present yet, but forgejo.service is already active."
  else
    echo "Forgejo data is not present yet; allowing forgejo.service to remain inactive before restore."
  fi
fi
'
