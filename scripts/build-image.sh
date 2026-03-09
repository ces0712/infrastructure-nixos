#!/bin/sh
set -eu

IMAGE_CONFIG="${IMAGE_CONFIG:-forgejo-pi-image}"
BUILD_ATTR="${BUILD_ATTR:-.#nixosConfigurations.${IMAGE_CONFIG}.config.system.build.sdImage}"
OUTPUT_IMAGE="${OUTPUT_IMAGE:-output/nixos-pi.img}"

echo "Building NixOS image for Raspberry Pi 4 ..."
output_path="$(
  nix build "${BUILD_ATTR}" \
    --print-out-paths
)"

mkdir -p output
image_artifact="$(
  find "${output_path}" -type f \
    \( -name '*.img' -o -name '*.raw' -o -name '*.raw.zst' -o -name '*.img.zst' -o -name '*.xz' \) \
    | sort \
    | head -n 1
)"

if [ -z "${image_artifact}" ]; then
  echo "Error: could not find an image artifact under ${output_path}" >&2
  exit 1
fi

echo "Copying image to ${OUTPUT_IMAGE} ..."
cp -L "${image_artifact}" "${OUTPUT_IMAGE}"
chmod 644 "${OUTPUT_IMAGE}"

echo "Image ready: ${OUTPUT_IMAGE}"
