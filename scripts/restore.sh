#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

PI_HOST="${PI_HOST:-forgejo-pi.tail8f7f61.ts.net}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
DB_PATH="${DB_PATH:-/srv/forgejo/data/forgejo.db}"
DB_BACKUP_PATH="${DB_BACKUP_PATH:-/srv/backup/forgejo/forgejo-backup.db}"
RCLONE_CONFIG_PATH="${RCLONE_CONFIG_PATH:-/srv/restic-backup/.config/rclone/rclone.conf}"

SSH_OPTS="$(standard_ssh_opts "${IDENTITY_FILE}")"
TARGET="$(target_host "${DEPLOY_USER}" "${PI_HOST}")"

echo "This will restore Forgejo data from backups on ${TARGET}."
echo "Existing data under /srv/forgejo will be overwritten."
echo "Press ENTER to continue or Ctrl+C to abort."
read -r

echo "Waiting for SSH on ${TARGET} ..."
until ssh ${SSH_OPTS} "${TARGET}" true 2>/dev/null; do
  echo "Retrying..."
  sleep 5
done

echo "Stopping Forgejo ..."
ssh ${SSH_OPTS} "${TARGET}" "sudo systemctl stop forgejo"

echo "Restoring from Borgbase ..."
ssh ${SSH_OPTS} "${TARGET}" "
  sudo restic restore latest \
    --repository-file /run/secrets/restic/borgbase_repo \
    --password-file /run/secrets/restic/borgbase_password \
    --target / \
    --verbose
"

echo "Restoring SQLite database ..."
ssh ${SSH_OPTS} "${TARGET}" "
  if [ -f ${DB_PATH} ]; then
    sudo cp ${DB_PATH} ${DB_PATH}.bak
  fi
  if [ ! -f ${DB_BACKUP_PATH} ]; then
    echo "Missing restored DB backup at ${DB_BACKUP_PATH}"
    exit 1
  fi
  sudo install -d -m 750 \$(dirname ${DB_PATH})
  sudo cp -f ${DB_BACKUP_PATH} ${DB_PATH}
  sudo sqlite3 ${DB_PATH} \
    'PRAGMA journal_mode=WAL;'
  sudo chown -R forgejo:forgejo /srv/forgejo
"

echo "Restoring LFS data from pCloud ..."
ssh ${SSH_OPTS} "${TARGET}" "
  sudo rclone sync \
    pcloud:forgejo-lfs-backup \
    /srv/forgejo/data/lfs \
    --config ${RCLONE_CONFIG_PATH} \
    --checksum \
    --fast-list \
    --transfers 4 \
    --log-level INFO
"

echo "Starting Forgejo ..."
ssh ${SSH_OPTS} "${TARGET}" "
  sudo chown -R forgejo:forgejo /srv/forgejo
  sudo systemctl start forgejo
  sudo systemctl status forgejo
"

echo "Restore complete."
