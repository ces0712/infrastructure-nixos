{
  config,
  lib,
  ...
}: {
  fileSystems = lib.mkForce {
    "/".device = "/dev/disk/by-partlabel/disk-ssd-root";
    "/boot".device = "/dev/disk/by-partlabel/disk-ssd-boot";
    "/nix".device = "/dev/disk/by-partlabel/disk-ssd-nix";
    "/var/lib".device = "/dev/disk/by-partlabel/disk-ssd-data";
  };

  disko.devices = {
    disk.ssd = {
      type = "disk";
      device = config.forgejo-pi.ssdDevice;

      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "512M";
            type = "EF00";
            label = "disk-ssd-boot";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0022" "dmask=0022"];
            };
          };

          root = {
            size = "40G";
            label = "disk-ssd-root";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = ["noatime" "nodiratime" "discard"];
            };
          };

          nix = {
            size = "150G";
            label = "disk-ssd-nix";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/nix";
              mountOptions = ["noatime" "nodiratime" "discard"];
            };
          };

          data = {
            size = "300G";
            label = "disk-ssd-data";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var/lib";
              mountOptions = ["noatime" "nodiratime" "discard" "nofail"];
            };
          };

          swap = {
            size = "2G";
            label = "disk-ssd-swap";
            content = {
              type = "swap";
              randomEncryption = false;
            };
          };
        };
      };
    };
  };
}
