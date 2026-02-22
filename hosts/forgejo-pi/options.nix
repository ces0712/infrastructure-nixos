{lib, ...}: {
  options.forgejo-pi = {
    dbPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/forgejo/data/forgejo.db";
    };
    dbBackup = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/forgejo-backup.db";
    };
    ssdDevice = lib.mkOption {
      type = lib.types.str;
      default = "/dev/sda";
      description = "SSD device for disko partitioning";
    };
    kernelPackages = lib.mkOption {
      type = lib.types.str;
      default = "linuxPackages_6_12";
      description = "Linux kernel packages variant (e.g., linuxPackages_6_12, linuxPackages_latest)";
    };
  };
}
