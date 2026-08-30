#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_NAME="invidious_companion-aarch64-unknown-linux-gnu.tar.gz"

cd "${ROOT_DIR}"

invidious_version="$(nix eval --raw .#nixosConfigurations.forgejo-pi.pkgs.invidious.version)"
pinned_version="$(nix eval --raw .#nixosConfigurations.forgejo-pi.config.forgejo-pi.invidiousCompanionVersion)"
pinned_hash="$(nix eval --raw .#nixosConfigurations.forgejo-pi.config.forgejo-pi.invidiousCompanionHash)"

IFS=$'\t' read -r remote_version remote_digest remote_url < <(
  gh api repos/iv-org/invidious-companion/releases/latest \
    --jq ".assets[] | select(.name == \"${ASSET_NAME}\") | [.updated_at[0:10], .digest, .browser_download_url] | @tsv"
)
remote_hash="$(nix hash convert --hash-algo sha256 --to sri "${remote_digest#sha256:}")"

printf 'Invidious (nixpkgs): %s\n' "${invidious_version}"
printf 'Companion pinned:    %s %s\n' "${pinned_version}" "${pinned_hash}"
printf 'Companion remote:    %s %s\n' "${remote_version}" "${remote_hash}"

if [[ "${pinned_version}" == "${remote_version}" && "${pinned_hash}" == "${remote_hash}" ]]; then
  echo "Companion is current."
  exit 0
fi

cat <<EOF
Companion update available:
  invidiousCompanionVersion = "${remote_version}";
  invidiousCompanionHash = "${remote_hash}";
  URL: ${remote_url}
EOF
exit 2
