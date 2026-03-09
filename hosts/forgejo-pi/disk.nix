{
  config,
  lib,
  ...
}: {
  fileSystems = {
    "/" = {
      device = lib.mkForce "/dev/disk/by-label/${config.forgejo-pi.labels.root}";
      neededForBoot = true;
    };
    "/srv" = {
      device = lib.mkForce "/dev/disk/by-label/${config.forgejo-pi.labels.data}";
      fsType = "ext4";
      neededForBoot = false;
      options = [
        "noatime"
        "nodiratime"
        "discard"
        "nofail"
        "x-systemd.device-timeout=10s"
      ];
    };
  };
}
