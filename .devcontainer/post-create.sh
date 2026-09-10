#!/usr/bin/env bash
# Runs once, when the container is created — not on restart or attach.
#
# uv itself comes from the devcontainer feature. This installs the Claude Code
# CLI, then pre-fetches the stdio MCP servers pinned in .mcp.json, so the first
# Claude Code session does not stall on a cold download, and so a bad pin shows
# up now rather than as a silent server failure later.
#
# Nothing here aborts container creation: a failed install is worth a loud
# message, not an unusable container.
set -uo pipefail

# The native installer drops a standalone binary in ~/.local/bin as the current
# user — no Node, no root-owned npm prefix, so `claude update` works without
# sudo. Never run it under sudo; it would install into root's home instead.
#
# It may warn here that ~/.local/bin is not on PATH. Ignore it: postCreate runs
# a bare shell, but /etc/zsh/zshrc and ~/.profile in the base image both add
# that directory, so `claude` resolves in a real shell.
if command -v claude >/dev/null 2>&1; then
    echo "post-create: claude already present ($(claude --version 2>/dev/null))"
elif curl -fsSL https://claude.ai/install.sh | bash -s stable; then
    echo "post-create: Claude Code installed to ~/.local/bin"
else
    echo "post-create: Claude Code install failed. Install it by hand with:" >&2
    echo "post-create:   curl -fsSL https://claude.ai/install.sh | bash -s stable" >&2
fi

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
