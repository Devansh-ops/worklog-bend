#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 toolchain/install-proof-tools.py
proof_cache="${WORKLOG_PROOF_CACHE:-$HOME/.cache/worklog-bend-proof}"
export BUN="$proof_cache/bun-linux-x64/bun"
export PATH="$proof_cache/lean-4.34.0-linux/bin:$PATH"
export BEND_NO_TELEMETRY=1
"$BUN" scripts/test-bend-toolchain.mjs --verdict
