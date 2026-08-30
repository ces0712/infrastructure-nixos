{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.forgejo-pi;
  invidiousPort = toString cfg.invidiousPort;
  invidiousExternalPort = toString cfg.invidiousExternalPort;
  invidiousCompanionPort = toString cfg.invidiousCompanionPort;
  companion = pkgs.stdenvNoCC.mkDerivation {
    pname = "invidious-companion";
    version = cfg.invidiousCompanionVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/iv-org/invidious-companion/releases/download/release-master/invidious_companion-aarch64-unknown-linux-gnu.tar.gz";
      hash = cfg.invidiousCompanionHash;
    };

    sourceRoot = ".";
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 invidious_companion $out/bin/invidious-companion
      runHook postInstall
    '';

    meta = {
      description = "Companion service for Invidious video stream retrieval";
      homepage = "https://github.com/iv-org/invidious-companion";
      license = lib.licenses.agpl3Only;
      mainProgram = "invidious-companion";
      platforms = ["aarch64-linux"];
    };
  };
in {
  environment.etc."invidious-runtime.env".text = ''
    INVIDIOUS_PORT=${invidiousPort}
    INVIDIOUS_EXTERNAL_PORT=${invidiousExternalPort}
  '';

  sops.templates = {
    "invidious-companion.env" = {
      content = ''
        SERVER_SECRET_KEY=${config.sops.placeholder."invidious/companion_key"}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = ["invidious-companion.service"];
    };

    "invidious-secrets.json" = {
      content = ''
        {"invidious_companion_key":"${config.sops.placeholder."invidious/companion_key"}"}
      '';
      owner = "invidious";
      group = "invidious";
      mode = "0400";
      restartUnits = ["invidious.service"];
    };
  };

  # A stable identity lets sops-nix render a private settings file before the
  # service starts. systemd otherwise creates this user dynamically at runtime.
  users.groups.invidious = {};
  users.users.invidious = {
    isSystemUser = true;
    group = "invidious";
  };

  services.invidious = {
    enable = true;
    address = "127.0.0.1";
    port = cfg.invidiousPort;
    domain = cfg.tailnetHostname;
    extraSettingsFile = config.sops.templates."invidious-secrets.json".path;

    database = {
      createLocally = true;
      host = null;
      passwordFile = null;
    };

    settings = {
      check_tables = true;
      external_port = cfg.invidiousExternalPort;
      https_only = true;
      registration_enabled = false;
      login_enabled = false;
      popular_enabled = false;
      statistics_enabled = false;
      invidious_companion = [
        {private_url = "http://127.0.0.1:${invidiousCompanionPort}/companion";}
      ];
    };
  };

  services.postgresql.enableTCPIP = false;

  programs.nix-ld.enable = true;

  systemd.services.invidious = {
    after = ["invidious-companion.service"];
    requires = ["invidious-companion.service"];
  };

  systemd.services.invidious-companion = {
    description = "Invidious Companion";
    wantedBy = ["multi-user.target"];
    before = ["invidious.service"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    environment = {
      HOST = "127.0.0.1";
      PORT = invidiousCompanionPort;
      SERVER_BASE_PATH = "/companion";
      CACHE_DIRECTORY = "/var/cache/invidious-companion/youtubei.js";
      NIX_LD = config.environment.variables.NIX_LD;
      NIX_LD_LIBRARY_PATH = config.environment.variables.NIX_LD_LIBRARY_PATH;
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = lib.getExe companion;
      EnvironmentFile = config.sops.templates."invidious-companion.env".path;
      Restart = "on-failure";
      RestartSec = "5s";

      DynamicUser = true;
      CacheDirectory = "invidious-companion";
      CacheDirectoryMode = "0700";
      UMask = "0077";

      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
    };
  };
}
