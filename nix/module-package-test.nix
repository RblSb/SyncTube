# Verifies that the module's default package picks up the effective port
# and enableYtDlp via passthru.
# Usage: nix-instantiate --eval -E 'import ./nix/module-package-test.nix { }'
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
      # port = 4300, enableYtDlp = true, settings.channelName set
      ./module-test-config.nix
    ];
    specialArgs = { inherit lib pkgs; };
  };
  pkg = eval.config.services.synctube.package;
in
if pkg.port == 4300 && pkg.withYtDlp == true then
  "PACKAGE passthru OK: port=4300, withYtDlp=true"
else
  "MISMATCH: port=${toString pkg.port} withYtDlp=${toString pkg.withYtDlp}"
