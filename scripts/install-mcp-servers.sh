#!/usr/bin/env bash
# Installs only the MCP servers, non-interactively. Kept as its own entry point
# because callers outside this repo reference it by name; install.sh does the
# work, so there is one implementation.
#
# Usage: install-mcp-servers.sh [path/to/mcp-servers.json]
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
SRC="$(cd "$(dirname "$SELF")/.." && pwd)"

if [ $# -gt 0 ]; then
    exec bash "$SRC/install.sh" --yes --template "$1"
fi
exec bash "$SRC/install.sh" --yes
