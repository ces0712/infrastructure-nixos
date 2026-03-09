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
    dbPath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/forgejo/data/forgejo.db";
    };
    dbBackup = lib.mkOption {
      type = lib.types.str;
      default = "/srv/backup/forgejo/forgejo-backup.db";
    };
    kernelPackages = lib.mkOption {
      type = lib.types.str;
      default = "linuxPackages_6_12";
      description = "Linux kernel packages variant (e.g., linuxPackages_6_12, linuxPackages_latest)";
    };
  };
}
