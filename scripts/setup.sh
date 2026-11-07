#!/usr/bin/env bash
# Compatibility entry point. Node performs exact preview, approval and recovery.
set -euo pipefail
command -v node >/dev/null 2>&1 || { echo "setup.sh: Node 18 or later is required." >&2; exit 1; }
exec node "$(dirname "$0")/setup.mjs" "$@"
