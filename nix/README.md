# Nix / NixOS packaging for SyncTube

This directory packages SyncTube for Nix and provides a NixOS module that
compiles the project from source, assembles a writable runtime tree at
service start, and runs it as a hardened systemd service.

```
nix/
├── package.nix          # derivation: Haxe compile + runtime assembly
├── synctube-wrapper.sh  # runtime-root assembly launcher (bin/synctube)
├── module.nix           # NixOS module: services.synctube
├── module-eval-test.nix # evaluation smoke test for the module
├── module-test-config.nix
└── module-assert-test.nix
```

## How it works

**Build time** (`nix/package.nix`):

- All Haxelib dependencies from `build-server.hxml` / `build-client.hxml`
  (hxnodejs, hxnodejs-ws, json2object @ `nightly_safe_macros`, the extern
  libs, utest and json2object's dependency hxjsonast) are fetched as pinned
  tarballs and registered in a local Haxelib repository with `haxelib dev`.
- `haxe build-all.hxml` compiles `build/server.js` and `res/client.js`,
  both verified with `node --check`.
- The runtime tree is assembled into `$out/share/synctube/`:
  `build/server.js`, `res/`, `default-config.json` and a `node_modules/`
  containing the single runtime npm dependency `ws` (from the locked
  tarball, no npm involved). With `withYtDlp = true` it also vendors
  `ytdlp-nodejs` (RblSb fork, ships prebuilt `dist/`) with `bin/` shims
  pointing at nixpkgs' `yt-dlp` and `ffmpeg`.
- The `port` argument (default `4200`) is baked into the packaged
  `default-config.json` with `jq`, keeping every other field byte-identical
  (key order and number formatting preserved).
- `$out/bin/synctube` assembles a *runtime root* and starts node there
  (see below).

**Runtime root**: the server locates everything relative to
`dirname(build/server.js)/..` (`rootDir` in `src/server/Main.hx`) and
writes state into `user/`. Because the nix store is read-only, the
launcher creates a root directory like

```
/var/lib/synctube/
├── build/server.js          # real file (copied, refreshed each start)
├── res -> …/share/synctube/res            # symlinks into the store
├── node_modules -> …/share/synctube/node_modules
├── default-config.json -> …/share/synctube/default-config.json
└── user/                    # writable: state.json, logs/, crashes/,
                             # res/ overrides, cache/, config.json
```

`server.js` must be a *real file*: `rootDir` is built by string-appending
`/..` to `__dirname`, and a symlinked `build/` would make the kernel
resolve that `..` inside the store instead of the runtime root.

## NixOS module

```nix
# configuration.nix / flake
{
  imports = [ /path/to/SyncTube/nix/module.nix ];

  services.synctube = {
    enable = true;
    port = 4200;              # optional, default 4200 via default-config
    openFirewall = true;      # open the effective port
    enableYtDlp = true;       # "Cache on server" (yt-dlp + ffmpeg)
    settings = {              # -> /var/lib/synctube/user/config.json
      channelName = "-=SuperChannel=-";
      totalVideoLimit = 10;
    };
  };
}
```

The service runs under a dynamic user with `StateDirectory=synctube`
(state persists in `/var/lib/synctube`), `Restart=on-failure` (you can
test it with the admin `/crash` chat command) and restrictive sandbox
options (`ProtectSystem=strict`, `PrivateTmp`, …).

Note: `settings` is fully declarative — `user/config.json` is rewritten
from it on every start. Leave `settings` empty to manage the file by
hand. `services.synctube.package` lets you substitute your own build.

### Port configuration

The derivation takes a `port` argument (default `4200`) that is baked into
the packaged `default-config.json` — i.e. it becomes the *default* port:

```nix
synctube.override { port = 4300; }
```

Everything the server natively supports still overrides it at runtime,
in increasing priority:

| Priority | Source | Example |
|---|---|---|
| 1 (lowest) | packaged `default-config.json` | `override { port = 4300; }` |
| 2 | `user/config.json` `"port"` field | `{ "port": 4400 }` |
| 3 | `PORT` environment variable | `PORT=4500 synctube` |
| 4 (highest) | command line argument | `synctube --port=4600` |

In the NixOS module, `services.synctube.port` (and `settings.port`) drive
both the baked package default and the declaratively written
`user/config.json`.

### With flakes

```nix
{
  inputs.synctube.url = "github:RblSb/SyncTube";

  outputs = { self, nixpkgs, synctube }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        synctube.nixosModules.default
        {
          services.synctube = {
            enable = true;
            openFirewall = true;
          };
        }
      ];
    };
  };
}
```

Also available: `packages.<system>.synctube`,
`packages.<system>.synctube-ytdlp`, `overlays.default`, and a
`devShells` with haxe/nodejs.

## Ad-hoc usage without NixOS

```console
$ nix-run github:RblSb/SyncTube          # throwaway state in a tmpdir
$ SYNCTUBE_ROOT=~/.local/share/synctube nix-run github:RblSb/SyncTube
```

## Tests

```console
$ nix-build default.nix                                   # full build
$ nix-instantiate --eval -E 'import ./nix/module-eval-test.nix {}'
$ nix-instantiate --eval -E 'import ./nix/module-assert-test.nix {}'
```

## Troubleshooting

- **Service crashes at startup with `uv_interface_addresses returned
  Unknown system error 97`**: error 97 is `EAFNOSUPPORT`. SyncTube calls
  `os.networkInterfaces()` on startup, which goes through glibc's
  `getifaddrs()` — that needs an `AF_NETLINK` socket. The unit's
  `RestrictAddressFamilies` must include `AF_NETLINK` (it does since this
  fix; keep it if you copy `serviceConfig` into your own unit overrides).
- **Build fails "without an error"**: run `nixos-rebuild switch
  --print-build-logs` (or `nix log /nix/store/…-synctube-….drv`) to see the
  actual failing step.
- **Building for a different architecture (e.g. aarch64 from x86)**: the
  package compiles Haxe *for the build machine* (`buildPackages`) but runs
  on the target. On the target itself, `haxe` must compile locally — on
  memory-constrained SBCs prefer cross-building (`crossSystem` or
  `boot.binfmt.emulatedSystems`).
- **Flake picks up stale/missing files**: flakes only see git-tracked
  files — `git add` (and commit) `flake.nix`, `default.nix` and `nix/`
  before referencing this repo as a flake input.

## Notes

- Pinned revisions of the git Haxelib dependencies live in
  `nix/package.nix`. To bump them, update `rev`, fetch the new `hash`
  (the build error message prints it), or use
  `nix store prefetch-file --unpack <github archive url>`.
- nixpkgs' `haxe` follows the 4.3 series required by the README.
- The `mbedtls` "marked insecure" evaluation error seen on some nixpkgs
  snapshots comes from haxe's dependency chain; allow it via
  `nixpkgs.config.permittedInsecurePackages` or use a nixpkgs revision
  where it is fixed.
