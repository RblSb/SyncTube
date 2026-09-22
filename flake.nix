{
  description = "SyncTube - synchronized video viewing with chat and other features";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          synctube = pkgs.callPackage ./nix/package.nix { source = ./.; };
          synctube-ytdlp = self.packages.${system}.synctube.override { withYtDlp = true; };
          default = self.packages.${system}.synctube;
        }
      );

      nixosModules = {
        synctube = import ./nix/module.nix;
        default = self.nixosModules.synctube;
      };

      overlays.default = final: _prev: {
        synctube = final.callPackage ./nix/package.nix { source = ./.; };
      };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              haxe
              nodejs
            ];
          };
        }
      );
    };
}
