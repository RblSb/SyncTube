# Negative test: conflicting port settings must produce a failing assertion.
# Usage: nix-instantiate --eval nix/module-assert-test.nix
{ lib ? import <nixpkgs/lib>, pkgs ? import <nixpkgs> { } }:

let
  eval = lib.evalModules {
    modules = [
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
      }
      ./module.nix
      {
        services.synctube = {
          enable = true;
          port = 1234;
          settings.port = 5678;
        };
      }
    ];
    specialArgs = { inherit lib pkgs; };
  };
  bad = builtins.filter (a: !a.assertion) eval.config.assertions;
in
if builtins.length bad == 1 then "CONFLICT ASSERTION TRIGGERS" else "NOT TRIGGERED: ${toString (builtins.length bad)}"
