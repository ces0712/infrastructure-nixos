{
  config,
  pkgs,
  ...
}: {
  # ============================================================
  # Restic → Borgbase
  # append-only: prune managed from borgbase UI or trusted machine
  # not from Pi to protect backup integrity
  # ============================================================
  users.users.restic-backup = {
    isSystemUser = true;
    group = "restic-backup";
    home = config.forgejo-pi.backupStateDir;
    createHome = true;
    # needs to read forgejo data
    extraGroups = ["forgejo"];
  };
  users.groups.restic-backup = {};

  systemd.tmpfiles.rules = [
    "d ${config.forgejo-pi.backupStateDir} 0750 restic-backup restic-backup -"
  ];

  services.restic.backups.borgbase = {
    initialize = true;
    repositoryFile = config.sops.secrets."restic/borgbase_repo".path;
    passwordFile = config.sops.secrets."restic/borgbase_password".path;
    paths = [
      config.forgejo-pi.dbBackup
      config.services.forgejo.repositoryRoot
      config.services.forgejo.customDir
      "${config.services.forgejo.stateDir}/data"
    ];
    exclude = [
      "${config.services.forgejo.stateDir}/log"
      "${config.services.forgejo.stateDir}/data/lfs/**"
      "**/.cache"
      "**/tmp"
      "**/cache"
    ];
    backupPrepareCommand = ''
      install -d -m 750 "$(dirname ${config.forgejo-pi.dbBackup})"
      ${pkgs.sqlite}/bin/sqlite3 ${config.forgejo-pi.dbPath} \
        ".backup ${config.forgejo-pi.dbBackup}"
      chmod 640 ${config.forgejo-pi.dbBackup}
    '';
    backupCleanupCommand = ''
      rm -f ${config.forgejo-pi.dbBackup}
    '';
    pruneOpts = [];
    runCheck = true;
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
    extraOptions = [
      "--verbose"
      "--one-file-system"
    ];
  };

  # ============================================================
  # Rclone → pCloud
  # LFS objects - weekly Sunday 03:00
  # ============================================================
  systemd.services.rclone-pcloud-backup = {
    description = "Rclone LFS backup to pCloud";
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      # cache dir for rclone checksums
      CacheDirectory = "rclone-pcloud";
      CacheDirectoryMode = "0700";
      ConditionPathExists = config.sops.secrets."rclone/pcloud_config".path;
    };

    script = ''
      ${pkgs.rclone}/bin/rclone sync \
          ${config.services.forgejo.stateDir}/data/lfs \
          pcloud:forgejo-lfs-backup \
          --config ${config.sops.secrets."rclone/pcloud_config".path} \
          --checksum \
          --fast-list \
          --track-renames \
          --order-by size,ascending \
          --transfers 2 \
          --retries 3 \
          --low-level-retries 10 \
          --max-delete 50 \
          --log-level INFO \
          --exclude "**/.cache/**" \
          --exclude "**/tmp/**"
    '';
  };

  systemd.timers.rclone-pcloud-backup = {
    description = "Rclone LFS backup to pCloud - weekly Sunday 03:00";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:00:00";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
