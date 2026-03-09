# SOPS Secrets Configuration
# forgejo-server - Uruguay Staking Platform
#
# Maps encrypted secrets from secrets/secrets.yaml to filesystem paths
# for use by NixOS services.
{config, ...}: {
  sops.secrets = {
    # ----------------------------------------------------------
    # Forgejo Secrets
    # ----------------------------------------------------------
    "forgejo/secret_key" = {
      owner = "forgejo";
      group = "forgejo";
    };

    "forgejo/internal_token" = {
      owner = "forgejo";
      group = "forgejo";
    };

    "tailscale/auth_key" = {
      owner = "root";
      group = "root";
    };

    "restic/borgbase_repo" = {
      owner = "restic-backup";
      group = "restic-backup";
    };

    "restic/borgbase_password" = {
      owner = "restic-backup";
      group = "restic-backup";
    };

    "rclone/pcloud_config" = {
      owner = "restic-backup";
      group = "restic-backup";
      path = "${config.forgejo-pi.backupStateDir}/.config/rclone/rclone.conf";
      mode = "0600";
    };
  };
}
