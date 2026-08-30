{lib, ...}: {
  options.forgejo-pi = {
    labels = {
      firmware = lib.mkOption {
        type = lib.types.str;
        default = "FIRMWARE";
      };
      root = lib.mkOption {
        type = lib.types.str;
        default = "NIXOS_SD";
      };
      data = lib.mkOption {
        type = lib.types.str;
        default = "NIXOS_DATA";
      };
    };
    image = {
      firmwareSizeMiB = lib.mkOption {
        type = lib.types.int;
        default = 512;
      };
    };
    bootstrap = {
      rootSizeGiB = lib.mkOption {
        type = lib.types.int;
        default = 200;
      };
      dataFsType = lib.mkOption {
        type = lib.types.enum ["ext4"];
        default = "ext4";
      };
    };
    forgejoStateDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/forgejo";
    };
    backupStateDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/restic-backup";
    };
    forgejoHttpAddr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for the Forgejo HTTP listener.";
    };
    dbPath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/forgejo/data/forgejo.db";
    };
    dbBackup = lib.mkOption {
      type = lib.types.str;
      default = "/srv/backup/forgejo/forgejo-backup.db";
    };
    tailnetHostname = lib.mkOption {
      type = lib.types.str;
      default = "forgejo-pi.tail8f7f61.ts.net";
      description = "Tailnet FQDN shared by services exposed through Tailscale Serve.";
    };
    invidiousPort = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Local Invidious HTTP port.";
    };
    invidiousExternalPort = lib.mkOption {
      type = lib.types.port;
      default = 8443;
      description = "Tailnet HTTPS port for Invidious.";
    };
    invidiousCompanionPort = lib.mkOption {
      type = lib.types.port;
      default = 8282;
      description = "Local Invidious Companion HTTP port.";
    };
    invidiousCompanionVersion = lib.mkOption {
      type = lib.types.str;
      default = "2026-08-10";
      description = "Version label for the pinned Invidious Companion release asset.";
    };
    invidiousCompanionHash = lib.mkOption {
      type = lib.types.str;
      default = "sha256-/rBZ/sWgE/vWewt4hJTywY20JF8Dol1b6TnFiwTeHZc=";
      description = "SHA-256 hash of the pinned Invidious Companion ARM64 release asset.";
    };
    kernelPackages = lib.mkOption {
      type = lib.types.str;
      default = "linuxPackages_6_18";
      description = "Linux kernel packages variant (e.g., linuxPackages_6_18, linuxPackages_latest)";
    };
  };
}
