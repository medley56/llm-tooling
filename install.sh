#!/usr/bin/env bash
# Installs this repo's skills, agents, rules, and MCP servers.
#
# Interactive by default; --yes (or a missing tty, or CI=true) runs it straight
# through, which is how a devcontainer postStart hook uses it. Nothing here
# aborts the caller: a tooling problem is worth a loud message, not a container
# that will not come up.
#
# Skills, agents, and rules install at user scope, into $CLAUDE_CONFIG_DIR, so
# every repo on the machine gets them. That is also the only place a path-scoped
# rule loads from without a per-project approval prompt. MCP servers install at
# user scope too, through `claude mcp add-json`, because an OAuth client secret
# cannot be expressed in a project .mcp.json at all.
#
# It does not install the Claude Code CLI. That belongs to whatever provisions
# the machine.
#
# Usage: install.sh [options]   (--help for the full list)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
SRC="$(cd "$(dirname "$SELF")" && pwd)"

SCOPE=user
TARGET="$PWD"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SECRETS_FROM=""
TEMPLATE="$SRC/mcp-servers.json"
COMPONENTS="skills,agents,rules,mcp"
LINK=0
DRY_RUN=0
DOCTOR=0
UPDATE=0
KEEP_BACKUPS=30
BACKUP=1
FORCE=0
INTERACTIVE=""
MCP_FILTERED=0
MCP_INSTALLED=0
declare -a AUTH_MODES=()
declare -a MCP_ONLY=()
declare -a SKIP=()

usage() {
    sed -n '2,18p' "$SELF" | sed 's/^# \{0,1\}//'
    cat <<'USAGE'

Options:
  -y, --yes                 Run without prompting (implied by no tty or CI=true)
  -i, --interactive         Prompt even when stdin is not a tty
      --update              git fetch/reset this checkout, then re-run
      --components LIST     Comma-separated: skills,agents,rules,mcp
      --scope user|project  Where skills/agents/rules go (default: user).
                            MCP servers are always user scope.
      --target DIR          Project scope only (default: the working directory)
      --config-dir DIR      Overrides $CLAUDE_CONFIG_DIR
      --secrets-from DIR    Repo to read ${VAR} values from (default: --target)
      --template FILE       MCP template (default: mcp-servers.json beside this)
      --link                Symlink components instead of copying
      --mcp-servers LIST    Only install these servers
      --auth NAME=MODE      Force one server's auth: primary, fallback, or skip
      --keep-backups DAYS   Prune backups older than this (default: 30)
      --no-backup           Overwrite components without backing anything up
      --force               Reinstall MCP servers even when nothing changed
      --dry-run             Report every action, change nothing
      --doctor              Report current state, change nothing
  -h, --help                This
USAGE
}

# The option loop below consumes $@, so --update's re-exec has nothing left
# to pass on. Capture the arguments first: a dropped --dry-run installs for
# real, and a dropped --config-dir installs somewhere else entirely.
declare -a ARGV=("$@")

while [ $# -gt 0 ]; do
    case "$1" in
        -y | --yes) INTERACTIVE=0 ;;
        -i | --interactive) INTERACTIVE=1 ;;
        --update) UPDATE=1 ;;
        --components) COMPONENTS="${2:?--components needs a value}"; shift ;;
        --scope) SCOPE="${2:?--scope needs a value}"; shift ;;
        --target) TARGET="${2:?--target needs a value}"; shift ;;
        --config-dir) CONFIG_DIR="${2:?--config-dir needs a value}"; shift ;;
        --secrets-from) SECRETS_FROM="${2:?--secrets-from needs a value}"; shift ;;
        --template) TEMPLATE="${2:?--template needs a value}"; shift ;;
        --link) LINK=1 ;;
        --mcp-servers)
            IFS=, read -ra MCP_ONLY <<<"${2:?--mcp-servers needs a value}"
            MCP_FILTERED=1
            shift
            ;;
        --auth) AUTH_MODES+=("${2:?--auth needs NAME=MODE}"); shift ;;
        --keep-backups) KEEP_BACKUPS="${2:?--keep-backups needs a value}"; shift ;;
        --no-backup) BACKUP=0 ;;
        --force) FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --doctor) DOCTOR=1; DRY_RUN=1 ;;
        -h | --help) usage; exit 0 ;;
        *) printf 'ERROR: unknown option %s (--help for usage)\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

# No tty means no one to answer, which is exactly the hook case.
if [ -z "$INTERACTIVE" ]; then
    if [ -t 0 ] && [ "${CI:-}" != true ]; then INTERACTIVE=1; else INTERACTIVE=0; fi
fi
[ "$DOCTOR" = 1 ] && INTERACTIVE=0

case "$SCOPE" in
    user | project) ;;
    *) printf 'ERROR: --scope must be user or project\n' >&2; exit 2 ;;
esac

for lib in ui env sync mcp; do
    # shellcheck disable=SC1090
    . "$SRC/scripts/lib/$lib.sh" || {
        printf 'ERROR: could not load %s\n' "$SRC/scripts/lib/$lib.sh" >&2
        exit 1
    }
done

# --update rewrites this script, so re-exec rather than carry on through a file
# that changed under us. The guard stops a loop if the new copy still sees it.
if [ "$UPDATE" = 1 ] && [ -z "${LLM_TOOLING_UPDATED:-}" ]; then
    section "Updating llm-tooling"
    if [ -d "$SRC/.git" ]; then
        if git -C "$SRC" fetch -q --depth 1 origin main &&
            git -C "$SRC" reset -q --hard origin/main &&
            git -C "$SRC" clean -qfd; then
            info "updated to $(git -C "$SRC" rev-parse --short HEAD)"
        else
            warn "could not update llm-tooling - using the existing checkout"
        fi
    else
        warn "$SRC is not a git checkout - nothing to update"
    fi
    finished
    export LLM_TOOLING_UPDATED=1
    exec bash "$SELF" "${ARGV[@]}"
fi

[ -n "$SECRETS_FROM" ] || SECRETS_FROM="$TARGET"
if [ "$SCOPE" = user ]; then
    DEST_ROOT="$CONFIG_DIR"
    SECRET_STORE="$CONFIG_DIR/settings.json"
else
    DEST_ROOT="$TARGET/.claude"
    SECRET_STORE="$SECRETS_FROM/.claude/settings.local.json"
fi
BACKUP_DIR="$DEST_ROOT/llm-tooling-backups/$(date -u +%Y%m%dT%H%M%SZ)"

# The claude CLI reads CLAUDE_CONFIG_DIR from the environment, not from our
# flags. Exporting it is what keeps `claude mcp add-json` writing to the same
# config directory the components were installed into.
export CLAUDE_CONFIG_DIR="$CONFIG_DIR"
build_sources

command -v jq >/dev/null 2>&1 || die "jq is not on PATH - install it and re-run"

FAILED=0

# wants <component> — true if it was asked for and not declined at the prompt.
wants() {
    local s
    for s in "${SKIP[@]}"; do [ "$s" = "$1" ] && return 1; done
    case ",$COMPONENTS," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

if [ "$DOCTOR" != 1 ] && { wants skills || wants agents || wants rules; }; then
    section "AI Agent Tooling (skills / subagents / rules)"
    info "source $SRC"
    info "target $DEST_ROOT"
    if [ "$INTERACTIVE" = 1 ]; then
        for type in skills agents rules; do
            wants "$type" || continue
            confirm "Install $type ($(list_names "$SRC/$type" | tr '\n' ' '))?" yes ||
                SKIP+=("$type")
        done
    fi
    for type in skills agents rules; do
        wants "$type" || continue
        sync_component "$type" || FAILED=1
    done
    prune_backups
    finished
fi

if [ "$DOCTOR" != 1 ] && wants mcp; then
    section "Shared MCP Servers"
    if [ ! -f "$TEMPLATE" ]; then
        warn "no template at $TEMPLATE - skipping MCP servers"
        FAILED=1
    elif ! command -v claude >/dev/null 2>&1; then
        warn "claude is not on PATH - skipping MCP servers"
        FAILED=1
    else
        info "template $TEMPLATE"
        info "secrets from $(printf '%s ' "${SOURCES[@]}")"
        if [ "$INTERACTIVE" = 1 ] && [ "$MCP_FILTERED" != 1 ]; then
            MCP_FILTERED=1
            for name in $(server_names); do
                confirm "Install $name ($(jq -r --arg n "$name" \
                    '.servers[] | select(.name == $n) | .description // ""' "$TEMPLATE"))?" yes &&
                    MCP_ONLY+=("$name")
            done
        fi
        install_mcp || FAILED=1
        if [ "$DRY_RUN" != 1 ] && [ "$MCP_INSTALLED" -gt 0 ]; then
            warn "installed MCP configs hold real tokens in cleartext under $CONFIG_DIR - do not share them"
        fi
    fi
    finished
fi

if [ "$DOCTOR" = 1 ]; then
    section "Doctor"
    info "source $SRC"
    info "target $DEST_ROOT"
    for type in skills agents rules; do
        if [ -e "$DEST_ROOT/$type" ]; then
            info "$type: $(list_names "$DEST_ROOT/$type" | tr '\n' ' ')"
        else
            warn "$type: not installed at $DEST_ROOT/$type"
        fi
    done
    if command -v claude >/dev/null 2>&1; then
        claude mcp list 2>&1 | sed 's/^/INFO:   /'
    else
        warn "claude is not on PATH"
    fi
    finished
fi

exit "$FAILED"
