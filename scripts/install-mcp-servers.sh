#!/usr/bin/env bash
# Installs the MCP servers described by mcp-servers.json into Claude Code's
# user scope, so every repo on this machine gets them.
#
# Run it from the repo whose secrets you want to use — the template travels with
# this script, but the values for its placeholders are read from the current
# directory. That is what lets one template serve several repos.
#
# mcp-servers.json is a template, not a live config. Naming it .mcp.json would
# make Claude Code load it directly, and a project-scope .mcp.json has no way to
# supply an OAuth client secret — github-mcp does not authenticate without one.
# Installing through the CLI is the only path that can hand one over.
#
# Every ${VAR} in the template is substituted here, before the config reaches
# the CLI. Claude Code expands placeholders only for a project-scope .mcp.json;
# a user-scope server keeps whatever string it was installed with, which shows
# up as a 404 against a URL containing a literal ${VAR}.
#
# That means the installed config holds real tokens in cleartext. It lands in
# ~/.claude.json (or $CLAUDE_CONFIG_DIR), not in any repo, but it is no longer
# safe to share.
#
# Usage: install-mcp-servers.sh [path/to/mcp-servers.json]
set -uo pipefail

for tool in claude jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "install-mcp-servers: $tool is not on PATH — nothing installed." >&2
        exit 1
    fi
done

# readlink -f so the default still resolves when the script is reached through a
# symlink, the way this repo's tooling is normally installed.
SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
TEMPLATE="${1:-$(cd "$(dirname "$SELF")/.." && pwd)/mcp-servers.json}"

if [ ! -f "$TEMPLATE" ]; then
    echo "install-mcp-servers: no template at $TEMPLATE — nothing installed." >&2
    exit 1
fi

# Where the ${VAR} values come from, best first. These are relative to the
# working directory, not to the template: run the script from the repo whose
# secrets should be used. settings.local.json leads because it is gitignored in
# every repo, which makes it the one safe place for a token. A real environment
# variable still wins over all of them.
SOURCES=(
    "$PWD/.claude/settings.local.json"
    "$PWD/.claude/settings.json"
    "$PWD/.env"
    "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
)

found_source=""
for file in "${SOURCES[@]}"; do
    [ -f "$file" ] && found_source=1 && break
done
if [ -z "$found_source" ]; then
    echo "install-mcp-servers: none of these exist under $PWD:" >&2
    printf 'install-mcp-servers:   %s\n' "${SOURCES[@]}" >&2
    echo "install-mcp-servers:   Every placeholder will resolve to its default or empty." >&2
fi

# read_env_file <file> <VAR> — last assignment wins, `export` and surrounding
# quotes are tolerated. The file is parsed, never sourced.
read_env_file() {
    local file="$1" var="$2" line val
    line="$(grep -E "^[[:space:]]*(export[[:space:]]+)?${var}=" "$file" 2>/dev/null | tail -n 1)"
    [ -n "$line" ] || return 1
    val="${line#*=}"
    val="${val%"${val##*[![:space:]]}"}"
    case "$val" in
        '"'*'"') val="${val#\"}"; val="${val%\"}" ;;
        "'"*"'") val="${val#\'}"; val="${val%\'}" ;;
    esac
    printf '%s' "$val"
}

# lookup <VAR_NAME> — prints the value and returns 0, or returns 1 if unset.
lookup() {
    local var="$1" val file
    val="${!var:-}"
    if [ -n "$val" ]; then printf '%s' "$val"; return 0; fi
    for file in "${SOURCES[@]}"; do
        [ -f "$file" ] || continue
        case "$file" in
            *.json) val="$(jq -r --arg v "$var" '.env[$v] // empty' "$file" 2>/dev/null)" ;;
            *)      val="$(read_env_file "$file" "$var")" ;;
        esac
        if [ -n "$val" ]; then printf '%s' "$val"; return 0; fi
    done
    return 1
}

# expand <json> — prints it with every ${VAR} and ${VAR:-default} replaced.
# Substitution goes through jq rather than sed so the value is JSON-escaped, and
# uses split/join rather than gsub so `${`, `}` and `-` stay literal.
expand() {
    local json="$1" ph var default value
    while IFS= read -r ph; do
        [ -n "$ph" ] || continue
        var="${ph#\$\{}"
        var="${var%\}}"
        default=""
        if [[ "$var" == *":-"* ]]; then
            default="${var#*:-}"
            var="${var%%:-*}"
        fi
        if ! value="$(lookup "$var")"; then
            value="$default"
            if [ -z "$value" ]; then
                echo "install-mcp-servers: $var is unset with no default — using an empty string." >&2
            fi
        fi
        json="$(jq -c --arg ph "$ph" --arg val "$value" \
            'walk(if type == "string" then split($ph) | join($val) else . end)' <<<"$json")"
    done < <(grep -o '\${[A-Za-z_][A-Za-z0-9_]*\(:-[^}]*\)\?}' <<<"$json" | sort -u)
    printf '%s' "$json"
}

failed=0
while read -r name; do
    server="$(jq -c --arg n "$name" '.mcpServers[$n]' "$TEMPLATE")"
    server="$(expand "$server")"

    # add-json refuses a name that already exists, so remove first. Re-running
    # this script is therefore how a template edit reaches an installed server.
    # The stored OAuth client secret is keyed by a hash of the server config, so
    # a changed config re-keys and needs the secret handed over again anyway.
    claude mcp remove -s user "$name" >/dev/null 2>&1 || true

    secret=""
    if jq -e '.oauth.clientId' >/dev/null 2>&1 <<<"$server"; then
        var="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9' '_')_CLIENT_SECRET"
        if ! secret="$(lookup "$var")"; then
            secret=""
            echo "install-mcp-servers: $name authenticates over OAuth but $var is unset" >&2
            echo "install-mcp-servers:   in the environment, any settings env block, or .env." >&2
            echo "install-mcp-servers:   Installing without it — the server will not authorize." >&2
        fi
    fi

    if [ -n "$secret" ]; then
        MCP_CLIENT_SECRET="$secret" \
            claude mcp add-json -s user --client-secret "$name" "$server" >/dev/null \
            && echo "install-mcp-servers: installed $name (client secret from $var)" \
            || { echo "install-mcp-servers: could not install $name" >&2; failed=1; }
    else
        claude mcp add-json -s user "$name" "$server" >/dev/null \
            && echo "install-mcp-servers: installed $name" \
            || { echo "install-mcp-servers: could not install $name" >&2; failed=1; }
    fi
done < <(jq -r '.mcpServers // {} | keys[]' "$TEMPLATE")

exit "$failed"
