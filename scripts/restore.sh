#!/bin/sh
set -eu

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PI_HOST="${PI_HOST:-forgejo-pi.tail8f7f61.ts.net}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
DB_PATH="${DB_PATH:-/srv/forgejo/data/forgejo.db}"
DB_BACKUP_PATH="${DB_BACKUP_PATH:-/srv/backup/forgejo/forgejo-backup.db}"
RCLONE_CONFIG_PATH="${RCLONE_CONFIG_PATH:-/srv/restic-backup/.config/rclone/rclone.conf}"

SSH_OPTS="-o IdentitiesOnly=yes"
if [ -n "$IDENTITY_FILE" ]; then
  SSH_OPTS="$SSH_OPTS -i $IDENTITY_FILE"
fi

TARGET="${DEPLOY_USER}@${PI_HOST}"

echo "${YELLOW}⚠️  This will restore forgejo data from borgbase.${NC}"
echo "${YELLOW}   Existing data will be overwritten.${NC}"
echo "${YELLOW}   Press ENTER to continue or Ctrl+C to abort${NC}"
read -r

echo "${GREEN}📡 Waiting for SSH via Tailscale...${NC}"
until ssh $SSH_OPTS "${TARGET}" true 2>/dev/null; do
  echo "   Retrying..."
  sleep 5
done

echo "${GREEN}⏹️  Stopping forgejo...${NC}"
ssh $SSH_OPTS "${TARGET}" "sudo systemctl stop forgejo"

echo "${GREEN}📦 Restoring from borgbase...${NC}"
ssh $SSH_OPTS "${TARGET}" "
  sudo restic restore latest \
    --repository-file /run/secrets/restic/borgbase_repo \
    --password-file /run/secrets/restic/borgbase_password \
    --target / \
    --verbose
"

echo "${GREEN}🗄️  Restoring SQLite DB...${NC}"
ssh $SSH_OPTS "${TARGET}" "
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

echo "${GREEN}📁 Restoring LFS from pCloud...${NC}"
ssh $SSH_OPTS "${TARGET}" "
  sudo rclone sync \
    pcloud:forgejo-lfs-backup \
    /srv/forgejo/data/lfs \
    --config ${RCLONE_CONFIG_PATH} \
    --checksum \
    --fast-list \
    --transfers 4 \
    --log-level INFO
"

echo "${GREEN}▶️  Starting forgejo...${NC}"
ssh $SSH_OPTS "${TARGET}" "
  sudo chown -R forgejo:forgejo /srv/forgejo
  sudo systemctl start forgejo
  sudo systemctl status forgejo
"

echo "${GREEN}✅ Restore complete!${NC}"
