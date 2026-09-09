#!/usr/bin/env bash
# Runs once, when the container is created — not on restart or attach.
#
# uv itself comes from the devcontainer feature, so nothing is installed here.
# This only pre-fetches the stdio MCP servers pinned in .mcp.json, so the first
# Claude Code session does not stall on a cold download, and so a bad pin shows
# up now rather than as a silent server failure later.
set -uo pipefail

PINS=(
    "mcp-proxy-for-aws-cli==1.6.5"
    "mcp-atlassian@0.23.1"
)

if ! command -v uvx >/dev/null 2>&1; then
    echo "post-create: uvx not on PATH — the uv devcontainer feature did not install." >&2
    echo "post-create: stdio MCP servers in .mcp.json will not start until it does." >&2
    exit 0
fi

for pin in "${PINS[@]}"; do
    printf 'post-create: pre-fetching %s ... ' "$pin"
    if timeout 180 uvx "$pin" --help >/dev/null 2>&1; then
        echo "ok"
    else
        echo "not cached (downloads on first use)"
    fi
done
