{
  lib,
  stdenv,
  haxe,
  nodejs,
  jq,
  fetchurl,
  fetchFromGitHub,
  yt-dlp,
  ffmpeg,
  # SyncTube source tree (already filtered or raw path); only src/, res/ and
  # the top-level build files are used, see `cleanSource` below.
  source,
  # Include the optional `ytdlp-nodejs` module and wire its `bin/` shims to
  # nixpkgs' yt-dlp / ffmpeg. Enables the "Cache on server" feature.
  withYtDlp ? false,
  # Default listen port, baked into the packaged default-config.json.
  # Runtime overrides (in increasing priority):
  #   user/config.json "port"  <  PORT env var  <  --port=NNNN command line arg
  port ? 4200,
}:

let
  # Allowlist filter: everything under src/ and res/ plus top-level build files.
  cleanSource =
    let root = toString source; in
    lib.cleanSourceWith {
      src = source;
      filter =
        path: type:
        let
          rel = lib.removePrefix "${root}/" (toString path);
          topLevel = builtins.head (lib.splitString "/" rel);
        in
        lib.elem topLevel [
          "src"
          "res"
          "build-all.hxml"
          "build-client.hxml"
          "build-server.hxml"
          "tests.hxml"
          "default-config.json"
          "hxformat.json"
        ];
      name = "synctube-source";
    };

  # Haxelib dependencies, pinned to the revisions upstream uses
  # (see build-server.hxml / build-client.hxml).
  haxeLibs = {
    hxnodejs = fetchFromGitHub {
      owner = "HaxeFoundation";
      repo = "hxnodejs";
      rev = "f88685a70b2e4f03dbe0a824ce90ea8b56b27753";
      hash = "sha256-LiCdE4GIabOnS1VGTk/Sq0WomoIQMNW0bzpsirnW55g=";
    };
    hxnodejs-ws = fetchFromGitHub {
      owner = "haxe-externs";
      repo = "hxnodejs-ws";
      rev = "2d0e770489abdb8d095fc4694353eaa9d6743562";
      hash = "sha256-Gls4OeOCSU9Ld3rZ76086BH2TMxRvPj658sKWDP4pds=";
    };
    json2object = fetchFromGitHub {
      owner = "RblSb";
      repo = "json2object";
      rev = "8d949c12a93bdae010603af955a453458603cd47"; # branch: nightly_safe_macros
      hash = "sha256-lD1IDg6xULRwisAtSZIyBju8yIa7nmM5eSezz05udaw=";
    };
    # transitive dependency of json2object
    hxjsonast = fetchFromGitHub {
      owner = "nadako";
      repo = "hxjsonast";
      rev = "20e72cc68c823496359775ac1f06500e67f189d5";
      hash = "sha256-IfgHkzJLV7LuvWdjlu3FMqmC6zOXkfOe9695b8BY7Q8=";
    };
    ytdlp-nodejs = fetchFromGitHub {
      owner = "haxe-externs";
      repo = "ytdlp-nodejs-externs";
      rev = "dbd476ce53a0c38db36e430ded28b2740001e8aa";
      hash = "sha256-mitC7wzZdJxt4B0UhMrnShhMd9Gup5G9EpSbUSJj8dA=";
    };
    youtubeIFramePlayer = fetchFromGitHub {
      owner = "haxe-externs";
      repo = "youtubeIFramePlayer-externs";
      rev = "8d47d71a4e3b8030a83a2e11672f120ca9a086d4";
      hash = "sha256-ov0nbhEazVCcWHcxplCNdN0KRhxBKqsvFHjmGzvTvPI=";
    };
    "hls.js-extern" = fetchFromGitHub {
      owner = "zoldesi-andor";
      repo = "hls.js-haxe-extern";
      rev = "86448a1dad21e72126ce8cc078062648de8bc2c5";
      hash = "sha256-MnT71PwoQd66DOzHMp8X3Yt8XulUkA1tX4dgUv7JLio=";
    };
    utest = fetchFromGitHub {
      owner = "haxe-utest";
      repo = "utest";
      rev = "a055e05e2e872ae12a32b53d0200612345059c38";
      hash = "sha256-VSfWKEGGjpgEwY1gFhSzvvLDexZkyUmI+mCm8FdDQK8=";
    };
  };

  haxelibSetup = lib.concatStrings (
    lib.mapAttrsToList
      (name: path: ''
        haxelib dev ${lib.escapeShellArg name} ${lib.escapeShellArg (toString path)}
      '')
      haxeLibs
  );

  # The single runtime npm dependency of the generated server.js
  # (see package.json / package-lock.json).
  ws = fetchurl {
    url = "https://registry.npmjs.org/ws/-/ws-8.21.0.tgz";
    hash = "sha512-Vsp28b7DRcimFQvrqu2Wek3z1iYxDCWqHYB8Qsnk/S4RfaCQzPGPyBNuVjJV3cd6UiKtUtp6sNM77gWvzcCH+g==";
  };

  # Optional "Cache on server" backend (README: npm i https://github.com/RblSb/ytdlp-nodejs).
  # The fork ships a prebuilt dist/ so no TypeScript toolchain is needed.
  ytdlpNodejs = fetchFromGitHub {
    owner = "RblSb";
    repo = "ytdlp-nodejs";
    rev = "bf0d03b9a3a9e12644746827ccbdf1edd9e48f0a";
    hash = "sha256-hvJvPsqEo9AxYaYPZEV4Wc/3sG6UM2ghCS5FAPYsNYE=";
  };

  share = "$out/share/synctube";
in
assert (lib.assertMsg
  (lib.isInt port && port >= 1 && port <= 65535)
  "synctube: port must be an integer in [1, 65535], got ${toString port}");

stdenv.mkDerivation {
  pname = "synctube";
  version = "1.0.0";

  src = cleanSource;

  # Exposed to substituteAll in synctube-wrapper.sh.
  inherit nodejs;

  nativeBuildInputs = [
    haxe
    nodejs
    jq
  ];

  buildPhase = ''
    runHook preBuild

    # Local haxelib repository with all git dependencies registered as dev libs.
    export HAXELIB_PATH="$NIX_BUILD_TOP/haxelib-repo"
    mkdir -p "$HAXELIB_PATH"
    ${haxelibSetup}

    # Compile server (build/server.js) and client (res/client.js).
    mkdir -p build
    haxe build-all.hxml

    # Sanity check the generated JavaScript.
    node --check build/server.js
    node --check res/client.js

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Runtime tree: the server resolves everything relative to
    # dirname(build/server.js)/.. at runtime (see src/server/Main.hx rootDir).
    install -vd ${share}/build ${share}/res ${share}/node_modules
    install -vm 0644 build/server.js ${share}/build/server.js
    cp -r res/. ${share}/res/
    # Bake the default port into the packaged default-config.json.
    # jq keeps key order and number formatting (3.0, 0.51) intact.
    jq --argjson port ${toString port} '.port = $port' default-config.json \
      > default-config.json.packaged
    install -vm 0644 default-config.json.packaged ${share}/default-config.json

    # ws (pure JS, no transitive runtime deps)
    tar -xf ${ws}
    mv package ${share}/node_modules/ws

  '' + lib.optionalString withYtDlp ''
    # ytdlp-nodejs + shims so it uses nixpkgs binaries instead of downloading.
    # v2.x looks up: bin/yt-dlp (x64), bin/yt-dlp_linux_aarch64 (arm64), bin/ffmpeg.
    cp -r ${ytdlpNodejs} ${share}/node_modules/ytdlp-nodejs
    chmod -R u+w ${share}/node_modules/ytdlp-nodejs
    # The constructor chmod()s its binaries, which fails on the read-only
    # store (harmless but noisy); store binaries are already executable.
    substituteInPlace ${share}/node_modules/ytdlp-nodejs/dist/index.js \
      --replace-fail "fs.chmodSync(this.binaryPath, 0o755);" "fs.accessSync(this.binaryPath, fs.constants.X_OK);"
    mkdir -p ${share}/node_modules/ytdlp-nodejs/bin
    ln -s ${lib.getBin yt-dlp}/bin/yt-dlp ${share}/node_modules/ytdlp-nodejs/bin/yt-dlp
    ln -s ${lib.getBin yt-dlp}/bin/yt-dlp ${share}/node_modules/ytdlp-nodejs/bin/yt-dlp_linux_aarch64
    ln -s ${lib.getBin ffmpeg}/bin/ffmpeg ${share}/node_modules/ytdlp-nodejs/bin/ffmpeg
    ln -s ${lib.getBin ffmpeg}/bin/ffprobe ${share}/node_modules/ytdlp-nodejs/bin/ffprobe

  '' + ''
    # CLI wrapper: assembles a runtime root (see nix/module.nix) and runs the server.
    # Set SYNCTUBE_ROOT to a persistent directory to keep state, otherwise a
    # throwaway tmpdir is used.
    install -vd $out/bin
    substituteAll ${./synctube-wrapper.sh} $out/bin/synctube
    chmod +x $out/bin/synctube

    runHook postInstall
  '';

  passthru = {
    inherit withYtDlp port;
    inherit nodejs;
  };

  meta = {
    description = "Synchronized video viewing with chat and other features";
    homepage = "https://github.com/RblSb/SyncTube";
    license = lib.licenses.mit;
    mainProgram = "synctube";
    platforms = lib.platforms.unix;
  };
}
