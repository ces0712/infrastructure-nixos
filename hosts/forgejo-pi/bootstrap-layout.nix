{
  config,
  pkgs,
  ...
}: let
  labels = config.forgejo-pi.labels;
  bootstrap = config.forgejo-pi.bootstrap;
  bootstrapScript = pkgs.writeTextFile {
    name = "forgejo-pi-bootstrap-layout.sh";
    executable = true;
    text = builtins.readFile ../../scripts/bootstrap-layout.sh;
  };
in {
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
        export ROOT_SIZE_GIB="''${ROOT_SIZE_GIB:-${toString bootstrap.rootSizeGiB}}"
        export BOOTSTRAP_BOOT_LABEL='${labels.firmware}'
        export BOOTSTRAP_ROOT_LABEL='${labels.root}'
        export BOOTSTRAP_DATA_LABEL='${labels.data}'
        export BOOTSTRAP_DATA_FS='${bootstrap.dataFsType}'
        exec ${bootstrapScript} "$@"
      '';
    })
  ];
}
