#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

PI_HOST="${PI_HOST:-forgejo-pi.tail8f7f61.ts.net}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
DB_PATH="${DB_PATH:-/srv/forgejo/data/forgejo.db}"
DB_BACKUP_PATH="${DB_BACKUP_PATH:-/srv/backup/forgejo/forgejo-backup.db}"
RCLONE_CONFIG_PATH="${RCLONE_CONFIG_PATH:-/run/secrets/rclone/pcloud_config}"
RESTORE_DRY_RUN="${RESTORE_DRY_RUN:-0}"

ssh_ctx="$(ssh_target "${DEPLOY_USER}" "${PI_HOST}" "${IDENTITY_FILE}")"
SSH_OPTS="${ssh_ctx%%|*}"
TARGET="${ssh_ctx#*|}"

echo "Waiting for SSH on ${TARGET} ..."
remote_wait_for_ssh "${SSH_OPTS}" "${TARGET}"

if [ "${RESTORE_DRY_RUN}" = "1" ]; then
  echo "Checking restore readiness on ${TARGET} ..."
  remote_run "${SSH_OPTS}" "${TARGET}" "
    set -eu
    sudo test -f /run/secrets/restic/borgbase_repo
    sudo test -f /run/secrets/restic/borgbase_password
    sudo test -f ${RCLONE_CONFIG_PATH}
    sudo -u restic-backup restic snapshots \
      --repository-file /run/secrets/restic/borgbase_repo \
      --password-file /run/secrets/restic/borgbase_password \
      --compact
    if sudo -u restic-backup rclone lsd pcloud:forgejo-lfs-backup \
      --config ${RCLONE_CONFIG_PATH} >/dev/null 2>&1; then
      echo 'LFS backup path found: pcloud:forgejo-lfs-backup'
    else
      echo 'LFS backup path not found: pcloud:forgejo-lfs-backup (skipping LFS restore check)'
    fi
    sudo ls -ld /srv/forgejo /srv/forgejo/data /srv/restic-backup
  "
  echo "Restore readiness check complete."
  exit 0
fi

echo "This will restore Forgejo data from backups on ${TARGET}."
echo "Existing data under /srv/forgejo will be overwritten."
echo "Press ENTER to continue or Ctrl+C to abort."
read -r

echo "Stopping Forgejo ..."
remote_run "${SSH_OPTS}" "${TARGET}" "sudo systemctl stop forgejo"

echo "Restoring from Borgbase ..."
remote_run "${SSH_OPTS}" "${TARGET}" "
  sudo restic restore latest \
    --repository-file /run/secrets/restic/borgbase_repo \
    --password-file /run/secrets/restic/borgbase_password \
    --target / \
    --verbose
"

echo "Restoring SQLite database ..."
remote_run "${SSH_OPTS}" "${TARGET}" "
  if [ -f ${DB_PATH} ]; then
    sudo cp ${DB_PATH} ${DB_PATH}.bak
  fi
  sudo install -d -m 750 \$(dirname ${DB_PATH})
  sudo sh -c '
    restic dump latest ${DB_BACKUP_PATH} \
      --repository-file /run/secrets/restic/borgbase_repo \
      --password-file /run/secrets/restic/borgbase_password \
      > ${DB_PATH}
  '
  sudo sqlite3 ${DB_PATH} \
    'PRAGMA journal_mode=WAL;'
  sudo chown -R forgejo:forgejo /srv/forgejo
"

echo "Restoring LFS data from pCloud ..."
remote_run "${SSH_OPTS}" "${TARGET}" "
  if sudo rclone lsd pcloud:forgejo-lfs-backup \
    --config ${RCLONE_CONFIG_PATH} >/dev/null 2>&1; then
    sudo rclone sync \
      pcloud:forgejo-lfs-backup \
      /srv/forgejo/data/lfs \
      --config ${RCLONE_CONFIG_PATH} \
      --checksum \
      --fast-list \
      --transfers 4 \
      --log-level INFO
  else
    echo 'Skipping LFS restore: pcloud:forgejo-lfs-backup does not exist.'
  fi
"

echo "Starting Forgejo ..."
remote_run "${SSH_OPTS}" "${TARGET}" "
  sudo chown -R forgejo:forgejo /srv/forgejo
  sudo systemctl start forgejo
  sudo systemctl status forgejo
"

echo "Restore complete."
