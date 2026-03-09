#!/bin/sh
set -eu

IMAGE_CONFIG="${IMAGE_CONFIG:-forgejo-pi-image}"

echo "Building NixOS image for Raspberry Pi 4 ..."
output_path="$(
  nix build ".#nixosConfigurations.${IMAGE_CONFIG}.config.system.build.sdImage" \
    --print-out-paths
)"

echo "Copying image to output/nixos-pi.img ..."
mkdir -p output
cp -L "${output_path}"/sd-image/*.img ./output/nixos-pi.img
chmod 644 ./output/nixos-pi.img

echo "Image ready: output/nixos-pi.img"
