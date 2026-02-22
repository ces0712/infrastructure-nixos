{config, ...}: {
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
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0022" "dmask=0022"];
              extraArgs = ["-n BOOT"];
            };
          };

          root = {
            size = "40G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = ["noatime" "nodiratime" "discard"];
              extraArgs = ["-L NIXOS_ROOT"];
            };
          };

          nix = {
            size = "150G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/nix";
              mountOptions = ["noatime" "nodiratime" "discard"];
              extraArgs = ["-L NIXOS_NIX"];
            };
          };

          data = {
            size = "300G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var/lib";
              mountOptions = ["noatime" "nodiratime" "discard" "nofail"];
              extraArgs = ["-L NIXOS_DATA"];
            };
          };

          swap = {
            size = "2G";
            content = {
              type = "swap";
              randomEncryption = false;
              extraArgs = ["-L NIXOS_SWAP"];
            };
          };
        };
      };
    };
  };
}
