{lib, ...}: {
  options.forgejo-pi = {
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv";
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
