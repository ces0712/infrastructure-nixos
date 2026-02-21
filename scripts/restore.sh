#!/bin/sh
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PI_HOST="${PI_HOST:-forgejo-pi.tail8f7f61.ts.net}"
SECRETS_PATH=$(nix eval --raw '.inputs.secrets.outPath')

echo "${YELLOW}⚠️  This will restore forgejo data from borgbase.${NC}"
echo "${YELLOW}   Existing data will be overwritten.${NC}"
echo "${YELLOW}   Press ENTER to continue or Ctrl+C to abort${NC}"
read -r

echo "${GREEN}📡 Waiting for SSH via Tailscale...${NC}"
until ssh root@"$PI_HOST" true 2>/dev/null; do
  echo "   Retrying..."
  sleep 5
done

echo "${GREEN}⏹️  Stopping forgejo...${NC}"
ssh root@"$PI_HOST" "systemctl stop forgejo"

echo "${GREEN}📦 Restoring from borgbase...${NC}"
ssh root@"$PI_HOST" "
  restic restore latest \
    --repo \$(cat \$(cat /run/secrets/restic/borgbase_repo)) \
    --password-file /run/secrets/restic/borgbase_password \
    --target / \
    --verbose
"

echo "${GREEN}🗄️  Restoring SQLite DB...${NC}"
ssh root@"$PI_HOST" "
  # restore from snapshot backup if needed
  cp /var/lib/forgejo/data/forgejo.db \
     /var/lib/forgejo/data/forgejo.db.bak
  sqlite3 /var/lib/forgejo/data/forgejo.db \
    'PRAGMA journal_mode=WAL;'
  chown -R forgejo:forgejo /var/lib/forgejo
"

echo "${GREEN}📁 Restoring LFS from pCloud...${NC}"
ssh root@"$PI_HOST" "
  rclone sync \
    pcloud:forgejo-lfs-backup \
    /var/lib/forgejo/data/lfs \
    --checksum \
    --fast-list \
    --transfers 4 \
    --log-level INFO
"

echo "${GREEN}▶️  Starting forgejo...${NC}"
ssh root@"$PI_HOST" "
  chown -R forgejo:forgejo /var/lib/forgejo
  systemctl start forgejo
  systemctl status forgejo
"

echo "${GREEN}✅ Restore complete!${NC}"
