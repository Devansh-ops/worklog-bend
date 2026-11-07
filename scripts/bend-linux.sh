#!/bin/sh
# Invoke the verified compiler from the caller's working directory in Linux/WSL.
set -eu
toolchain_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
proof_cache="${WORKLOG_PROOF_CACHE:-$HOME/.cache/worklog-bend-proof}"
export BUN="$proof_cache/bun-linux-x64/bun"
export PATH="$proof_cache/lean-4.34.0-linux/bin:$PATH"
exec "$BUN" "$toolchain_root/scripts/bend.mjs" "$@"
