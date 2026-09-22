# Non-flake entry point: nix-build default.nix
{ pkgs ? import <nixpkgs> { } }:

pkgs.callPackage ./nix/package.nix { source = ./.; }
