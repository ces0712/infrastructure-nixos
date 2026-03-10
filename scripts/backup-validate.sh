#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

PI_HOST="${PI_HOST:?PI_HOST is required}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
RCLONE_CONFIG_PATH="${RCLONE_CONFIG_PATH:-/run/secrets/rclone/pcloud_config}"

ssh_ctx="$(ssh_target "${DEPLOY_USER}" "${PI_HOST}" "${IDENTITY_FILE}")"
SSH_OPTS="${ssh_ctx%%|*}"
TARGET="${ssh_ctx#*|}"

echo "Validating backup readiness on ${TARGET} ..."

remote_wait_for_ssh "${SSH_OPTS}" "${TARGET}"

remote_run "${SSH_OPTS}" "${TARGET}" "
set -eu

if [ \"\$(id -u)\" -ne 0 ]; then
  SUDO=sudo
else
  SUDO=
fi

echo 'unit state:'
\$SUDO systemctl is-enabled restic-backups-borgbase.timer rclone-pcloud-backup.timer
echo
echo 'timer state:'
\$SUDO systemctl is-active restic-backups-borgbase.timer rclone-pcloud-backup.timer
echo
echo 'secret files:'
for path in \
  /run/secrets/restic/borgbase_repo \
  /run/secrets/restic/borgbase_password \
  ${RCLONE_CONFIG_PATH}
do
  if \$SUDO test -f \"\$path\"; then
    echo \"ok  \$path\"
  else
    echo \"missing  \$path\" >&2
    exit 1
  fi
done
\$SUDO ls -l /run/secrets/restic/borgbase_repo /run/secrets/restic/borgbase_password ${RCLONE_CONFIG_PATH}
echo
echo 'repository access:'
\$SUDO -u restic-backup restic snapshots \
  --repository-file /run/secrets/restic/borgbase_repo \
  --password-file /run/secrets/restic/borgbase_password \
  --compact
echo
echo 'pcloud access:'
\$SUDO -u restic-backup rclone lsd pcloud: \
  --config ${RCLONE_CONFIG_PATH}
echo
echo 'local backup paths:'
\$SUDO ls -ld /srv/forgejo /srv/forgejo/data /srv/restic-backup
"

echo "Backup validation complete."
