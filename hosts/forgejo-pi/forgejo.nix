{
  config,
  lib,
  pkgs,
  ...
}: let
  forgejoHost = "${config.networking.hostName}.${config.networking.domain}";
  forgejoPort = 3000;
  forgejoSSHPort = 2222;
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "gitea" ''
      exec ${config.services.forgejo.package}/bin/gitea \
        --config ${config.services.forgejo.stateDir}/custom/conf/app.ini \
        "$@"
    '')
  ];

  services.forgejo = {
    enable = true;
    stateDir = config.forgejo-pi.forgejoStateDir;
    lfs.enable = true;
    database = {
      type = "sqlite3";
      path = config.forgejo-pi.dbPath;
    };
    settings = {
      # ============================================================
      # Mirroring
      # ============================================================
      mirror = {
        ENABLED = true;
        DEFAULT_INTERVAL = "8h";
        MIN_INTERVAL = "1h";
      };
      git.MAX_GIT_DIFF_FILES = 100;
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "https://code.forgejo.org";
      };
      mailer.ENABLED = false;
      i18n.DEFAULT_LANGUAGE = "en-US";
      time.DEFAULT_UI_LOCATION = config.time.timeZone;
      database.LOG_SQL = false;
      server = {
        DOMAIN = forgejoHost;
        ROOT_URL = "http://${forgejoHost}:${toString forgejoPort}";
        HTTP_PORT = forgejoPort;
        SSH_DOMAIN = forgejoHost;
        SSH_PORT = forgejoSSHPort;
        SSH_LISTEN_PORT = forgejoSSHPort;
        START_SSH_SERVER = true;
        LFS_START_SERVER = true;
        DISABLE_SSH = false;
      };
      repository = {
        DEFAULT_BRANCH = "main";
        DEFAULT_TRUST_MODEL = "committer";
      };
      security = {
        SECRET_KEY_FILE = config.sops.secrets."forgejo/secret_key".path;
        INTERNAL_TOKEN_FILE = config.sops.secrets."forgejo/internal_token".path;
      };
    };
  };

  systemd.services.forgejo-secrets = {
    before = ["forgejo.service"];
    after = ["srv.mount"];
    requires = ["srv.mount"];
  };

  systemd.services.forgejo = {
    wantedBy = lib.mkForce ["multi-user.target"];
    wants = ["network-online.target"];
    after = [
      "network-online.target"
      "forgejo-secrets.service"
      "srv.mount"
    ];
    requires = [
      "forgejo-secrets.service"
      "srv.mount"
    ];
  };

  systemd.timers.forgejo-autostart = {
    description = "Start Forgejo shortly after boot";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "15s";
      Unit = "forgejo.service";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${builtins.dirOf config.forgejo-pi.dbBackup} 0750 forgejo forgejo -"
  ];

  systemd.services.forgejo-wal = {
    description = "Enable WAL mode for Forgejo SQLite";
    after = ["forgejo.service"];
    requires = ["forgejo.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "forgejo";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.sqlite}/bin/sqlite3 ${config.forgejo-pi.dbPath} "PRAGMA journal_mode=WAL;"
    '';
  };
}
