{
  description = "Home server NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, sops-nix, ... }:
    {
      nixosConfigurations.homeserver = nixpkgs.lib.nixosSystem {
        modules = [
          sops-nix.nixosModules.sops
          ./hosts/homeserver
        ];
      };
    };
}
