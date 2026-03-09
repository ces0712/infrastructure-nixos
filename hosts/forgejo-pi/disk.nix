{lib, ...}: {
  fileSystems = {
    "/" = {
      device = lib.mkForce "/dev/disk/by-label/NIXOS_SD";
      neededForBoot = true;
    };
    "/srv" = {
      device = lib.mkForce "/dev/disk/by-label/NIXOS_DATA";
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
