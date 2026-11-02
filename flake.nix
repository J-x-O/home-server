{
  description = "Home server NixOS configuration";

  inputs = {
    # TODO: switch to nixos-26.11 once released (late Nov 2026); 26.05 only has an insecure Immich 2.x.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
