{raspberrypi-firmware, ...}: {
  nixpkgs.overlays = [
    (final: prev: {
      raspberrypifw = prev.raspberrypifw.overrideAttrs (_: rec {
        version = "1.20250915";
        src = raspberrypi-firmware;
      });
    })
  ];
}
