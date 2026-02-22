#!/bin/sh
set -e


echo "📋 Building NixOS Image for Raspberry Pi 4..."

OUTPUT=$(nix build .#nixosConfigurations.forgejo-pi.config.system.build.sdImage \
  --print-out-paths)

echo "💾 Copying image..."
mkdir -p output
cp -L "$OUTPUT/sd-image"/*.img ./output/nixos-pi.img
chmod 644 ./output/nixos-pi.img

echo "✅ Image ready: output/nixos-pi.img"
echo "   sudo dd if=output/nixos-pi.img of=/dev/diskX bs=1M status=progress"
