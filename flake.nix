{
  description = "NixOS infrastructure for Raspberry Pi 4 with Forgejo";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    alejandra.url = "github:kamadorueda/alejandra";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "git+ssh://git@github.com/ces0712/infrastructure-secrets.git";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    alejandra,
    secrets,
    sops-nix,
    disko,
  }: let
    forSystem = nixpkgs.lib.genAttrs;
    commonModules = [
      sops-nix.nixosModules.sops
      ./hosts/forgejo-pi/options.nix
      ./hosts/forgejo-pi/packages.nix
      ./hosts/forgejo-pi/default.nix
      ./hosts/forgejo-pi/secrets.nix
      ./hosts/forgejo-pi/forgejo.nix
      ./hosts/forgejo-pi/hardware.nix
      ./hosts/forgejo-pi/backup.nix
      ./hosts/forgejo-pi/networking.nix
    ];
  in {
    formatter = forSystem ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"] (system: alejandra.packages.${system}.default);

    # Runtime configuration for normal deploys after first boot.
    nixosConfigurations.forgejo-pi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit secrets;};
      modules =
        commonModules
        ++ [
          disko.nixosModules.disko
          ./hosts/forgejo-pi/disk.nix
        ];
    };

    # Buildable installer image; keep sd-image concerns isolated from disko.
    nixosConfigurations.forgejo-pi-image = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit secrets;};
      modules =
        commonModules
        ++ [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./hosts/forgejo-pi/image.nix
        ];
    };

    # Final SSD layout profile (root/nix/data/swap) using disko.
    nixosConfigurations.forgejo-pi-disko = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit secrets;};
      modules =
        commonModules
        ++ [
          disko.nixosModules.disko
          ./hosts/forgejo-pi/disk.nix
        ];
    };
  };
}
