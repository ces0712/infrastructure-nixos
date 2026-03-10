#!/bin/sh
set -eu

die() {
  echo "$*" >&2
  exit 1
}

ssh_run() {
  ssh ${SSH_OPTS} "${TARGET}" "$@"
}

ssh_run_stdin() {
  ssh ${SSH_OPTS} "${TARGET}" "$@"
}

PI_HOST="${PI_HOST:?PI_HOST is required}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-}"
SOPS_AGE_KEY="${SOPS_AGE_KEY:-}"
SOPS_AGE_KEY_PASS_ENTRY="${SOPS_AGE_KEY_PASS_ENTRY:-sops/age-key}"
DEPLOY_REBOOT="${DEPLOY_REBOOT:-1}"

TARGET="${DEPLOY_USER}@${PI_HOST}"
SSH_OPTS="-o IdentitiesOnly=yes"
if [ -n "${IDENTITY_FILE}" ]; then
  SSH_OPTS="${SSH_OPTS} -i ${IDENTITY_FILE}"
fi

LOCAL_UTC_NOW="$(date -u '+%Y-%m-%d %H:%M:%S')"

TMP_AGE_DIR=""
AGE_KEY_SOURCE_FILE=""

cleanup() {
  if [ -n "${TMP_AGE_DIR}" ] && [ -d "${TMP_AGE_DIR}" ]; then
    rm -rf "${TMP_AGE_DIR}"
  fi
}
trap cleanup EXIT INT TERM

resolve_age_key_source() {
  if [ -n "${SOPS_AGE_KEY_FILE}" ]; then
    if [ ! -f "${SOPS_AGE_KEY_FILE}" ]; then
      die "SOPS_AGE_KEY_FILE does not exist: ${SOPS_AGE_KEY_FILE}"
    fi
    AGE_KEY_SOURCE_FILE="${SOPS_AGE_KEY_FILE}"
    return 0
  fi

  if [ -n "${SOPS_AGE_KEY}" ]; then
    TMP_AGE_DIR="$(mktemp -d)"
    AGE_KEY_SOURCE_FILE="${TMP_AGE_DIR}/age.key"
    printf '%s\n' "${SOPS_AGE_KEY}" > "${AGE_KEY_SOURCE_FILE}"
    chmod 600 "${AGE_KEY_SOURCE_FILE}"
    return 0
  fi

  if command -v pass >/dev/null 2>&1; then
    if AGE_KEY_FROM_PASS="$(pass show "${SOPS_AGE_KEY_PASS_ENTRY}" 2>/dev/null)"; then
      TMP_AGE_DIR="$(mktemp -d)"
      AGE_KEY_SOURCE_FILE="${TMP_AGE_DIR}/age.key"
      printf '%s\n' "${AGE_KEY_FROM_PASS}" > "${AGE_KEY_SOURCE_FILE}"
      chmod 600 "${AGE_KEY_SOURCE_FILE}"
      return 0
    fi
  fi

  die "Unable to resolve a SOPS age key from file, env, or pass entry '${SOPS_AGE_KEY_PASS_ENTRY}'."
}

push_age_key_to_target() {
  echo "Pushing stable SOPS age key to ${TARGET}:/var/lib/sops-nix/key.txt ..."
  cat "${AGE_KEY_SOURCE_FILE}" | ssh_run '
set -eu
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi
$SUDO install -d -m 700 /var/lib/sops-nix
$SUDO tee /var/lib/sops-nix/key.txt >/dev/null
$SUDO chmod 600 /var/lib/sops-nix/key.txt
'
}

prepare_remote_time() {
  echo "Preparing remote clock on ${TARGET} ..."
  ssh_run "REMOTE_UTC='${LOCAL_UTC_NOW}' sh -s" <<'EOF'
set -eu
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

$SUDO date -u -s "$REMOTE_UTC" >/dev/null

if command -v timedatectl >/dev/null 2>&1; then
  $SUDO timedatectl set-ntp true >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
  $SUDO systemctl restart systemd-timesyncd >/dev/null 2>&1 || true
fi

date -u '+remote time: %Y-%m-%d %H:%M:%S UTC'
EOF
}

resolve_age_key_source
prepare_remote_time
push_age_key_to_target

if [ "${DEPLOY_USER}" = "root" ]; then
  SUDO_FLAG=""
else
  SUDO_FLAG="--sudo"
fi

run_rebuild() {
  export NIX_SSHOPTS="${SSH_OPTS}"
  nix run nixpkgs#nixos-rebuild -- \
    boot --flake ".#forgejo-pi" \
    --target-host "${TARGET}" \
    --build-host "${TARGET}" \
    ${SUDO_FLAG}
}

reboot_target() {
  echo "Rebooting ${TARGET} into the newly installed generation ..."
  ssh_run '
set -eu
if [ "$(id -u)" -ne 0 ]; then
  exec sudo systemctl reboot
else
  exec systemctl reboot
fi
' || true
}

handle_boot_reboot() {
  if [ "${DEPLOY_REBOOT}" = "1" ]; then
    reboot_target
    echo "Reboot triggered. Reconnect to ${PI_HOST} manually to verify the new generation."
  else
    echo "Skipping reboot because DEPLOY_REBOOT=${DEPLOY_REBOOT}."
    echo "Verify /boot before rebooting manually."
  fi
}

run_rebuild
handle_boot_reboot
