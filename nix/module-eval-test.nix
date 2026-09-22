# Standalone evaluation smoke test for nix/module.nix (no full NixOS needed).
# Usage:
#   nix-instantiate --eval --json nix/module-eval-test.nix
{ lib ? import <nixpkgs/lib>, pkgs ? import <nixpkgs> { } }:

let
  eval = lib.evalModules {
    modules = [
      # Minimal shims for what the NixOS module system provides.
      {
        options.assertions = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
        };
        options.networking.firewall.allowedTCPPorts = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
        };
        options.systemd.services = lib.mkOption {
          type = lib.types.attrsOf lib.types.attrs;
          default = { };
        };
        config = { };
      }
      ./module.nix
      ./module-test-config.nix
    ];
    specialArgs = { inherit lib pkgs; };
  };

  cfg = eval.config;
in
{
  inherit (cfg) assertions;
  firewallPorts = cfg.networking.firewall.allowedTCPPorts;
  unitNames = builtins.attrNames cfg.systemd.services;
  unit = cfg.systemd.services.synctube;
}
