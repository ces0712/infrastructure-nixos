#!/bin/sh
set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo "${GREEN}📋 Building NixOS Image for Raspberry Pi 4...${NC}"

nix build .#nixosConfigurations.forgejo-pi.config.system.build.sdImage \
  --extra-experimental-features "nix-command flakes" \
  --print-out-paths

echo "${GREEN}💾 Copying image to project root...${NC}"
cp -L result/*.img ./nixos-pi.img 2>/dev/null || cp -L result/sd-image/*.img ./nixos-pi.img
rm -rf result

echo "${GREEN}✅ Image ready: nixos-pi.img${NC}"
