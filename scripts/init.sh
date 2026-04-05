#!/bin/sh
set -e

SECRETS_LOCAL="/tmp/keys"
SSH_KEYS_PATH="${SSH_KEYS_PATH:-$SECRETS_LOCAL}"
SECRETS_PATH="${SECRETS_PATH:-$(nix eval --raw --impure --expr '(builtins.getFlake "git+file://'"$(pwd)"'").inputs.secrets.outPath' 2>/dev/null | tail -1)}"
export SECRETS_PATH
export SSH_KEYS_PATH
SSH_KEY_PATH="${SECRETS_LOCAL}/id_ed25519"
SSH_PUB_KEY_PATH="${SECRETS_LOCAL}/id_ed25519.pub"
echo "Preparing..."

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Add temp key..."
    mkdir -p "$SECRETS_LOCAL"
    SOPS_AGE_KEY=$(pass show sops/age-key) sops -d "$SECRETS_PATH/ssh-hosts/forgejo-pi_key.enc" > "$SSH_KEY_PATH"
    chmod 600 "$SSH_KEY_PATH"
    cp "$SECRETS_PATH/ssh-hosts/forgejo-pi_key.pub" "$SSH_PUB_KEY_PATH"
    chmod 644 "$SSH_PUB_KEY_PATH"
fi
