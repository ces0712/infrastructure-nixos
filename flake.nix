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
  in {
    formatter = forSystem ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"] (system: alejandra.packages.${system}.default);

    nixosConfigurations.forgejo-pi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit secrets;};
      modules = [
        sops-nix.nixosModules.sops
        disko.nixosModules.disko
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ./hosts/forgejo-pi/options.nix
        ./hosts/forgejo-pi/packages.nix
        ./hosts/forgejo-pi/default.nix
        ./hosts/forgejo-pi/secrets.nix
        ./hosts/forgejo-pi/disk.nix
        ./hosts/forgejo-pi/forgejo.nix
        ./hosts/forgejo-pi/hardware.nix
        ./hosts/forgejo-pi/backup.nix
        ./hosts/forgejo-pi/networking.nix
      ];
    };
  };
}
