#!/bin/sh
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SSD_DEVICE="${SSD_DEVICE:-/dev/sda}"
SECRETS_PATH=$(nix eval --raw '.inputs.secrets.outPath')

echo "${YELLOW}⚠️  This will ERASE all data on ${SSD_DEVICE}${NC}"
echo "${YELLOW}   Press ENTER to continue or Ctrl+C to abort${NC}"
read -r

echo "${GREEN}💾 Partitioning with disko...${NC}"
nix run github:nix-community/disko -- \
  --mode disko \
  --flake .#forgejo-pi

echo "${GREEN}📋 Mounting partitions...${NC}"
mount /dev/disk/by-label/NIXOS_ROOT /mnt
mkdir -p /mnt/boot /mnt/nix /mnt/var/lib
mount /dev/disk/by-label/BOOT       /mnt/boot
mount /dev/disk/by-label/NIXOS_NIX  /mnt/nix
mount /dev/disk/by-label/NIXOS_DATA /mnt/var/lib

echo "${GREEN}🚀 Installing NixOS...${NC}"
nixos-install \
  --no-root-passwd \
  --flake .#forgejo-pi \
  --root /mnt \
  --option "forgejo-pi.ssdDevice" "$SSD_DEVICE"

echo "${GREEN}🔐 Injecting host key...${NC}"
export SOPS_AGE_KEY=$(pass show sops/age-key)
sops -d "$SECRETS_PATH/ssh-keys/forgejo-pi_key.enc" \
  > /mnt/etc/ssh/ssh_host_ed25519_key
cp "$SECRETS_PATH/ssh-keys/forgejo-pi_key.pub" \
  /mnt/etc/ssh/ssh_host_ed25519_key.pub
chmod 600 /mnt/etc/ssh/ssh_host_ed25519_key
chmod 644 /mnt/etc/ssh/ssh_host_ed25519_key.pub

echo "${GREEN}🔓 Unmounting...${NC}"
umount /mnt/boot
umount /mnt/nix
umount /mnt/var/lib
umount /mnt

echo "${GREEN}✅ SSD ready! Plug into Pi and boot.${NC}"
echo "${GREEN}   On first boot sops-nix will decrypt secrets${NC}"
echo "${GREEN}   using the injected host key ✅${NC}"
