{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
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
    secrets,
    sops-nix,
    disko,
  }: {
    nixosConfigurations.forgejo-pi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit secrets;};
      modules = [
        sops-nix.nixosModules.sops
        disko.nixosModules.disko
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
