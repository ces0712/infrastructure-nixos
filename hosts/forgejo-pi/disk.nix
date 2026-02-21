{config, ...}: {
  disko.devices = {
    disk.ssd = {
      type = "disk";
      device = config.forgejo-pi.ssdDevice; # adjust if needed

      # ============================================================
      # Filesystems - SSD 512GB
      # /boot     512MB  FAT32
      # /         40GB   ext4
      # /nix      150GB  ext4
      # /var/lib  300GB  ext4  (forgejo data + lfs)
      # swap      2GB    swap  fallback
      # ============================================================
      content = {
        type = "gpt";
        partitions = {
          # ============================================================
          # Boot - 512MB FAT32
          # RPi firmware + extlinux bootloader
          # ============================================================
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

          # ============================================================
          # Root - 40GB
          # OS + system files
          # ============================================================
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

          # ============================================================
          # Nix store - 150GB
          # all nix derivations and closures
          # ============================================================
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

          # ============================================================
          # Forgejo data - 300GB
          # repositories, lfs, sqlite db
          # ============================================================
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

          # ============================================================
          # Swap - 2GB fallback
          # ============================================================
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
