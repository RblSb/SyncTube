# NixOS module for SyncTube <https://github.com/RblSb/SyncTube>
#
# Packages the project from source (Haxe compile via nix/package.nix),
# assembles a writable runtime tree in /var/lib/synctube at service start
# (symlinks into the store + persistent user/ data) and runs it as a
# hardened, dynamically-user'd systemd service.
#
# Minimal usage:
#   services.synctube = {
#     enable = true;
#     openFirewall = true;
#     settings.channelName = "-=SuperChannel=-";
#   };
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.synctube;

  jsonFormat = pkgs.formats.json { };

  # Declarative part of user/config.json (see user/README.md).
  # `port` here overrides settings.port for convenience.
  effectiveSettings = cfg.settings // lib.optionalAttrs (cfg.port != null) {
    port = cfg.port;
  };

  # The port the service will actually use: settings.port, overridden by
  # services.synctube.port, falling back to the upstream default (4200).
  effectivePort = effectiveSettings.port or 4200;

  # Baked into the package's default-config.json so even a manually managed
  # (or absent) user/config.json starts on the right port. user/config.json
  # still overrides it (see getUserConfig in src/server/Main.hx).
  synctube = pkgs.callPackage ./package.nix {
    source = ../.;
    withYtDlp = cfg.enableYtDlp;
    port = effectivePort;
  };

  configFile = jsonFormat.generate "synctube-config.json" effectiveSettings;

  runtimeRoot = "/var/lib/synctube";
in
{
  options.services.synctube = {
    enable = lib.mkEnableOption "SyncTube, synchronized video viewing with chat";

    package = lib.mkOption {
      type = lib.types.package;
      default = synctube;
      defaultText = lib.literalExpression "pkgs.callPackage ./nix/package.nix { }";
      description = ''
        SyncTube package to use. The default is built from the repository
        this module was imported from, with the effective port baked into
        its default-config.json and ytdlp support matching `enableYtDlp`.
      '';
    };

    port = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      example = 4200;
      description = ''
        TCP port to listen on. When null, no port is forced and the server
        default (4200) or `settings.port` applies.

        The port is applied twice: baked into the default package's
        default-config.json, and written to user/config.json — so a custom
        `package` also picks it up.
      '';
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      example = {
        channelName = "-=SuperChannel=-";
        totalVideoLimit = 10;
      };
      description = ''
        Declarative server settings, written to user/config.json on every
        start (overriding manual edits). All root fields of
        default-config.json can be overridden; see user/README.md.
        Leave empty to manage the config file manually.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall for the effective listen port.";
    };

    enableYtDlp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the "Cache on server" feature for YouTube and other
        yt-dlp-supported sites: vendors the ytdlp-nodejs module into the
        package (default package only) and adds yt-dlp and ffmpeg to the
        service PATH. Default cache limit is `cacheStorageLimitGiB` (3 GiB).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.port == null || (cfg.settings.port or null) == null || cfg.settings.port == cfg.port;
        message = "services.synctube.port and services.synctube.settings.port differ; the former wins, remove one of them.";
      }
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ effectivePort ];
    };

    systemd.services.synctube = {
      description = "SyncTube - synchronized video viewing with chat";
      documentation = [ "https://github.com/RblSb/SyncTube" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        # Persistent runtime root assembled by the package's wrapper script.
        SYNCTUBE_ROOT = runtimeRoot;
        HOME = runtimeRoot;
        # The wrapper (and yt-dlp) need coreutils on PATH.
        PATH = lib.mkDefault (lib.makeBinPath (
          [ pkgs.coreutils ]
          ++ lib.optionals cfg.enableYtDlp [
            pkgs.yt-dlp
            pkgs.ffmpeg
          ])
        );
      };

      preStart = ''
        set -eu
        mkdir -p ${runtimeRoot}/user
        ${lib.optionalString (effectiveSettings != { }) ''
          install -m 0644 ${configFile} ${runtimeRoot}/user/config.json
        ''}
      '';

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe cfg.package;
        DynamicUser = true;
        StateDirectory = "synctube";
        WorkingDirectory = runtimeRoot;

        # README suggests testing auto-restart with the /crash command.
        Restart = "on-failure";
        RestartSec = "5s";

        # Hardening.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        RestrictNamespaces = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        RestrictSUIDSGID = true;
      };
    };
  };
}
