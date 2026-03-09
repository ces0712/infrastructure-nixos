{
  config,
  pkgs,
  ...
}: let
  labels = config.forgejo-pi.labels;
  bootstrap = config.forgejo-pi.bootstrap;
  bootstrapEnv = pkgs.writeText "forgejo-pi-bootstrap.env" ''
    BOOTSTRAP_SSD_DEVICE=/dev/sda
    BOOTSTRAP_ROOT_SIZE_GIB=${toString bootstrap.rootSizeGiB}
    BOOTSTRAP_POWEROFF_DEFAULT=1
    BOOTSTRAP_BOOT_LABEL=${labels.firmware}
    BOOTSTRAP_ROOT_LABEL=${labels.root}
    BOOTSTRAP_DATA_LABEL=${labels.data}
    BOOTSTRAP_DATA_FS=${bootstrap.dataFsType}
  '';
  bootstrapScript = pkgs.writeTextFile {
    name = "forgejo-pi-bootstrap-layout.sh";
    executable = true;
    text = builtins.readFile ../../scripts/bootstrap-layout.sh;
  };
in {
  environment.etc."forgejo-pi-bootstrap.env".source = bootstrapEnv;

  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "forgejo-pi-bootstrap-partition";
      runtimeInputs = with pkgs; [
        coreutils
        util-linux
        e2fsprogs
        dosfstools
        gnugrep
        gawk
      ];
      text = ''
        exec ${bootstrapScript} "$@"
      '';
    })
  ];
}
