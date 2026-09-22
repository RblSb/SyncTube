#!/bin/sh
# SyncTube launcher.
#
# The server resolves its res/, default-config.json and node_modules/ trees
# relative to build/server.js (rootDir = dirname(__dirname), see
# src/server/Main.hx). Since the nix store is read-only, this wrapper
# assembles a runtime root with symlinks into the store and a writable
# user/ directory for state.
#
# server.js itself is copied (not symlinked): the server builds paths by
# appending "/.." to __dirname, and the kernel would resolve that ".."
# inside the symlink *target* (the store), not the assembled root.
#
# SYNCTUBE_ROOT: persistent runtime root (default: throwaway tmpdir).
#   Persistent example: SYNCTUBE_ROOT=~/.local/share/synctube synctube
#
# The listen port comes from the packaged default-config.json (set at build
# time via the derivation's `port` argument). Runtime overrides, in
# increasing priority:
#   user/config.json "port"  <  PORT env var  <  --port=NNNN argument
set -eu

share="@out@/share/synctube"
node="@nodejs@/bin/node"

root="${SYNCTUBE_ROOT:-}"
cleanup=0
if [ -z "$root" ]; then
  root="$(mktemp -d /tmp/synctube.XXXXXX)"
  cleanup=1
fi

mkdir -p "$root/user" "$root/build"
# Refresh on every start so upgrades are picked up (cheap, ~300 KB).
# Atomic replace so a still-running old instance keeps its inode.
cat "$share/build/server.js" > "$root/build/server.js.new"
mv -f "$root/build/server.js.new" "$root/build/server.js"
ln -sfn "$share/res" "$root/res"
ln -sfn "$share/node_modules" "$root/node_modules"
ln -sfn "$share/default-config.json" "$root/default-config.json"

status=0
"$node" "$root/build/server.js" "$@" || status=$?

if [ "$cleanup" -ne 0 ]; then
  rm -rf "$root"
fi
exit $status
