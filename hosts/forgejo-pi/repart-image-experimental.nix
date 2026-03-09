{
  config,
  modulesPath,
  pkgs,
  ...
}: let
  labels = config.forgejo-pi.labels;
  imageCfg = config.forgejo-pi.image;
  configTxt = pkgs.writeText "config.txt" ''
    [pi4]
    kernel=u-boot-rpi4.bin
    enable_gic=1
    armstub=armstub8-gic.bin
    disable_overscan=1
    arm_boost=1

    [all]
    arm_64bit=1
    enable_uart=1
    avoid_warnings=1
    dtoverlay=disable-bt
  '';
  repartReadme = pkgs.writeText "README.repart-experimental" ''
    This GPT image is an experimental systemd-repart prototype.
    It is not part of the supported Raspberry Pi workflow yet.

    Goals:
    - prove that a GPT-first image can be built reproducibly
    - preserve the same FIRMWARE / NIXOS_SD / NIXOS_DATA labels
    - provide an artifact for boot-path comparison against the supported sd-image

    Non-goals:
    - replace the supported sd-image workflow
    - claim Raspberry Pi boot compatibility without explicit testing
  '';
in {
  imports = [
    "${modulesPath}/image/repart.nix"
  ];

  system.image.id = "forgejo-pi-repart-experimental";

  image.repart = {
    name = "forgejo-pi-repart-experimental";
    compression.enable = false;
    partitions = {
      "10-firmware" = {
        contents = {
          "/config.txt".source = configTxt;
          "/start4.elf".source = "${pkgs.raspberrypifw}/boot/start4.elf";
          "/fixup4.dat".source = "${pkgs.raspberrypifw}/boot/fixup4.dat";
          "/u-boot-rpi4.bin".source = "${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin";
          "/armstub8-gic.bin".source = "${pkgs.raspberrypi-armstubs}/armstub8-gic.bin";
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          Label = labels.firmware;
          SizeMinBytes = "${toString imageCfg.firmwareSizeMiB}M";
          SizeMaxBytes = "${toString imageCfg.firmwareSizeMiB}M";
        };
      };
      "20-root" = {
        storePaths = [config.system.build.toplevel];
        contents = {
          "/init".source = "${config.system.build.toplevel}/init";
          "/boot/README.repart-experimental".source = repartReadme;
        };
        repartConfig = {
          Type = "root-arm64";
          Format = "ext4";
          Label = labels.root;
          Minimize = "guess";
        };
      };
      "30-data" = {
        repartConfig = {
          Type = "home";
          Format = "ext4";
          Label = labels.data;
          SizeMinBytes = imageCfg.repartDataSizeMin;
        };
      };
    };
  };
}
