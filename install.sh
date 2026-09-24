#!/usr/bin/env bash
# Installs this repo's MCP servers.
#
# Interactive by default; --yes (or a missing tty, or CI=true) runs it straight
# through, which is how a devcontainer postStart hook uses it. Nothing here
# aborts the caller: a tooling problem is worth a loud message, not a container
# that will not come up.
#
# Servers install at user scope through `claude mcp add-json`, because an OAuth
# client secret cannot be expressed in a project .mcp.json or a plugin at all.
# Skills and agents install as a plugin.
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
DRY_RUN=0
DOCTOR=0
UPDATE=0
FORCE=0
INTERACTIVE=""
MCP_FILTERED=0
MCP_INSTALLED=0
declare -a AUTH_MODES=()
declare -a MCP_ONLY=()
declare -a REMOVED=()
NO_MCP=0

[ "${BASH_VERSINFO[0]}" -ge 4 ] ||
    { printf 'ERROR: needs bash 4 or later (this is %s)\n' "$BASH_VERSION" >&2; exit 1; }

usage() {
    sed -n '2,15p' "$SELF" | sed 's/^# \{0,1\}//'
    cat <<'USAGE'

Options:
  -y, --yes                 Run without prompting (implied by no tty or CI=true)
  -i, --interactive         Prompt even when stdin is not a tty
      --update              git fetch/reset this checkout, then re-run
      --scope user|project  Where prompted secrets are saved, and which secret
                            files are read first (default: user). Servers are
                            always user scope.
      --target DIR          Project scope only (default: the working directory)
      --config-dir DIR      Overrides $CLAUDE_CONFIG_DIR
      --secrets-from DIR    Repo to read ${VAR} values from (default: --target)
      --template FILE       MCP template (default: mcp-servers.json beside this)
      --mcp-servers LIST    Only install these servers
      --auth NAME=MODE      Force one server's auth: primary, fallback, or skip
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
        # Removed when skills and agents moved to plugins. Ignored rather than
        # rejected, so an existing hook that passes one still installs servers.
        --components)
            REMOVED+=("$1")
            case ",${2:-}," in *,mcp,*) ;; *) NO_MCP=1 ;; esac
            shift
            ;;
        --keep-backups) REMOVED+=("$1"); shift ;;
        --link | --no-backup) REMOVED+=("$1") ;;
        --scope) SCOPE="${2:?--scope needs a value}"; shift ;;
        --target) TARGET="${2:?--target needs a value}"; shift ;;
        --config-dir) CONFIG_DIR="${2:?--config-dir needs a value}"; shift ;;
        --secrets-from) SECRETS_FROM="${2:?--secrets-from needs a value}"; shift ;;
        --template) TEMPLATE="${2:?--template needs a value}"; shift ;;
        --mcp-servers)
            IFS=, read -ra MCP_ONLY <<<"${2:?--mcp-servers needs a value}"
            MCP_FILTERED=1
            shift
            ;;
        --auth) AUTH_MODES+=("${2:?--auth needs NAME=MODE}"); shift ;;
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

for lib in ui env mcp; do
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
    if [ "$DRY_RUN" = 1 ]; then
        info "would hard-reset $SRC to origin/main"
    elif [ -d "$SRC/.git" ]; then
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

# Past the update, so reported once rather than again by the re-exec.
for flag in "${REMOVED[@]}"; do
    warn "$flag is ignored - skills and agents install as a plugin (see README)"
done
# A --components list without mcp used to install no servers; keep it that way.
[ "$NO_MCP" = 1 ] && { info "--components has no mcp - nothing to do"; exit 0; }

[ -n "$SECRETS_FROM" ] || SECRETS_FROM="$TARGET"
if [ "$SCOPE" = user ]; then
    SECRET_STORE="$CONFIG_DIR/settings.json"
else
    SECRET_STORE="$SECRETS_FROM/.claude/settings.local.json"
fi

# The claude CLI reads CLAUDE_CONFIG_DIR from the environment, not from our
# flags, so export it for --config-dir. But only when set: unset, the CLI keeps
# its servers in ~/.claude.json, and exporting ~/.claude would move them to
# ~/.claude/.claude.json, which a default session never reads.
if [ -n "${CLAUDE_CONFIG_DIR:-}" ] || [ "$CONFIG_DIR" != "$HOME/.claude" ]; then
    export CLAUDE_CONFIG_DIR="$CONFIG_DIR"
    GLOBAL_CONFIG="$CONFIG_DIR/.claude.json"
else
    GLOBAL_CONFIG="$HOME/.claude.json"
fi
build_sources

command -v jq >/dev/null 2>&1 || die "jq is not on PATH - install it and re-run"

FAILED=0

if [ "$DOCTOR" != 1 ]; then
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
            warn "installed MCP configs hold real tokens in cleartext in $GLOBAL_CONFIG - do not share it"
        fi
    fi
    finished
fi

if [ "$DOCTOR" = 1 ]; then
    section "Doctor"
    info "source $SRC"
    if command -v claude >/dev/null 2>&1; then
        claude mcp list 2>&1 | sed 's/^/INFO:   /'
        claude plugin list 2>&1 | grep -A3 '@llm-tooling' | sed 's/^/INFO:   /'
    else
        warn "claude is not on PATH"
    fi
    finished
fi

exit "$FAILED"
