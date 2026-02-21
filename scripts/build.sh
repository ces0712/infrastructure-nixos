#!/bin/sh
set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo "${GREEN}📋 Building NixOS Image for Raspberry Pi 4...${NC}"

nix build .#packages.aarch64-linux.pi-image \
  --extra-experimental-features "nix-command flakes" \
  --print-out-paths

echo "${GREEN}💾 Copying image to project root...${NC}"
cp -L result/sd-image/*.img ./nixos-pi.img
rm result

echo "${GREEN}✅ Image ready: nixos-pi.img${NC}"
