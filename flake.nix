{
  description = "NixOS infrastructure for Raspberry Pi 4 with Forgejo";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    alejandra.url = "github:kamadorueda/alejandra";
    raspberrypi-firmware = {
      url = "github:raspberrypi/firmware/1.20250915";
      flake = false;
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "git+ssh://git@github.com/ces0712/infrastructure-secrets.git";
      flake = false;
    };
  };

  outputs = {
    nixpkgs,
    alejandra,
    raspberrypi-firmware,
    secrets,
    sops-nix,
    ...
  }: let
    forSystem = nixpkgs.lib.genAttrs;
    baseModules = [
      ./hosts/forgejo-pi/options.nix
      ./hosts/forgejo-pi/firmware.nix
      ./hosts/forgejo-pi/packages.nix
      ./hosts/forgejo-pi/hardware.nix
    ];
    bootstrapModules =
      baseModules
      ++ [
        ./hosts/forgejo-pi/bootstrap-base.nix
        ./hosts/forgejo-pi/bootstrap-networking.nix
        ./hosts/forgejo-pi/bootstrap-ssh.nix
      ];
    runtimeModules =
      baseModules
      ++ [
        ./hosts/forgejo-pi/profile-runtime.nix
        sops-nix.nixosModules.sops
        ./hosts/forgejo-pi/default.nix
        ./hosts/forgejo-pi/sops.nix
        ./hosts/forgejo-pi/secrets.nix
        ./hosts/forgejo-pi/forgejo.nix
        ./hosts/forgejo-pi/networking.nix
        ./hosts/forgejo-pi/backup.nix
      ];
  in {
    formatter = forSystem ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"] (system: alejandra.packages.${system}.default);

    # Runtime configuration for normal deploys after first boot.
    nixosConfigurations.forgejo-pi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {
        inherit secrets raspberrypi-firmware;
      };
      modules =
        runtimeModules
        ++ [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./hosts/forgejo-pi/image.nix
          ./hosts/forgejo-pi/disk.nix
        ];
    };

    # Shared bootstrap image flashed to both the SD card and the SSD.
    nixosConfigurations.forgejo-pi-image = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {
        inherit secrets raspberrypi-firmware;
      };
      modules =
        bootstrapModules
        ++ [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./hosts/forgejo-pi/image.nix
        ];
    };
  };
}
