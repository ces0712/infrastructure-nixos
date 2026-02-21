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
    };
    kernelPackages = lib.mkOption {
      type = lib.types.raw;
      default = pkgs: pkgs.linuxPackages_6_12;
    };
  };
}
