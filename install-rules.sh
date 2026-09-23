#!/usr/bin/env bash
# Installs this repo's rules, which Claude Code plugins cannot ship.
#
# User scope symlinks each rule into $CLAUDE_CONFIG_DIR/rules, so a git pull
# here updates every project. Project scope symlinks into <target>/.claude/rules
# only when this checkout sits inside the target, with a relative link that
# survives a commit. Otherwise it copies: Claude Code treats a project rule
# linked outside the working directory as an external import, which stays
# unloaded without an approval it never asks for, and never loads a `paths:`
# rule even after one.
#
# An entry already there is replaced when it matches upstream, or when it is a
# copy this script made and nobody has edited since. Anything else is kept
# unless --force, which first moves it to <name>.bak-<timestamp>.
#
# Usage: install-rules.sh [options]   (--help for the full list)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
SRC="$(cd "$(dirname "$SELF")" && pwd -P)"

SCOPE=user
TARGET="$PWD"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
FORCE=0
DRY_RUN=0

[ "${BASH_VERSINFO[0]}" -ge 4 ] ||
    { printf 'ERROR: needs bash 4 or later (this is %s)\n' "$BASH_VERSION" >&2; exit 1; }

usage() {
    sed -n '2,16p' "$SELF" | sed 's/^# \{0,1\}//'
    cat <<'USAGE'

Options:
      --scope user|project  Where rules go (default: user)
      --target DIR          Project scope only (default: the working directory)
      --config-dir DIR      Overrides $CLAUDE_CONFIG_DIR
      --force               Replace entries edited locally, keeping a backup
      --dry-run             Report every action, change nothing
  -h, --help                This
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --scope) SCOPE="${2:?--scope needs a value}"; shift ;;
        --target) TARGET="${2:?--target needs a value}"; shift ;;
        --config-dir) CONFIG_DIR="${2:?--config-dir needs a value}"; shift ;;
        --force) FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h | --help) usage; exit 0 ;;
        *) printf 'ERROR: unknown option %s (--help for usage)\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

# shellcheck disable=SC1091
. "$SRC/scripts/lib/ui.sh" || {
    printf 'ERROR: could not load %s\n' "$SRC/scripts/lib/ui.sh" >&2
    exit 1
}

# relpath <from-dir> <to-path> — both absolute and canonical.
relpath() {
    local from="$1" to="$2" up=""
    while [ "${to#"$from"/}" = "$to" ] && [ "$from" != / ]; do
        from="$(dirname "$from")"
        up="../$up"
    done
    printf '%s%s\n' "$up" "${to#"$from"/}"
}

# digest <path> — a content checksum of a file, or of every file in a directory.
digest() {
    if [ -d "$1" ]; then
        (cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do
            printf '%s ' "$f"
            cksum <"$f"
        done) | cksum
    else
        cksum <"$1"
    fi | tr -s ' ' '-'
}

# run <command...> — runs it, or under --dry-run only reports it.
run() {
    if [ "$DRY_RUN" = 1 ]; then
        info "would run: $*"
    else
        "$@"
    fi
}

case "$SCOPE" in
    user) DEST="$CONFIG_DIR/rules"; MODE=link ;;
    project)
        real="$(cd "$TARGET" 2>/dev/null && pwd -P)" || die "no such directory: $TARGET" 2
        TARGET="$real"
        DEST="$TARGET/.claude/rules"
        case "$SRC/" in "$TARGET"/*) MODE=relative-link ;; *) MODE=copy ;; esac
        ;;
    *) die "--scope must be user or project" 2 ;;
esac

section "Rules"
info "source $SRC/rules"

# A rules directory that is itself a symlink - to dotfiles, say - is followed.
# One that already points at rules/, as this repo's own does, is done.
if [ -L "$DEST" ]; then
    if [ "$(readlink -f "$DEST")" = "$SRC/rules" ]; then
        if [ "$MODE" = copy ]; then
            warn "$DEST links to $SRC/rules, outside the project, so Claude Code will not load it - remove the link and re-run to copy"
            exit 1
        fi
        info "$DEST is a symlink to $SRC/rules - nothing to do"
        finished
        exit 0
    fi
    DEST="$(readlink -f "$DEST")"
fi
info "target $DEST ($MODE)"

run mkdir -p "$DEST" || die "could not create $DEST"
DEST_REAL="$(cd "$DEST" 2>/dev/null && pwd -P || printf '%s' "$DEST")"

# Copies this script made, with the checksum each had when made. A copy that
# still has it was never edited, so it can be replaced when upstream changes.
MANIFEST="$DEST/.llm-tooling-rules"
declare -A MADE=()
if [ -f "$MANIFEST" ]; then
    while IFS=$'\t' read -r name sum; do
        [ -n "$name" ] && MADE["$name"]="$sum"
    done <"$MANIFEST"
fi
declare -a RECORD=()

FAILED=0
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
shopt -s nullglob
for src in "$SRC"/rules/*; do
    name="$(basename "$src")"
    dest="$DEST/$name"

    if [ "$MODE" = copy ]; then
        if [ ! -L "$dest" ] && diff -rq "$src" "$dest" >/dev/null 2>&1; then
            RECORD+=("$name"$'\t'"$(digest "$src")")
            info "$name up to date"
            continue
        fi
    elif [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$src" ]; then
        info "$name up to date"
        continue
    fi

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if diff -rq "$src" "$dest" >/dev/null 2>&1; then
            run rm -rf "$dest" || { FAILED=1; continue; }
        elif [ ! -L "$dest" ] && [ -n "${MADE[$name]:-}" ] &&
            [ "$(digest "$dest")" = "${MADE[$name]}" ]; then
            run rm -rf "$dest" || { FAILED=1; continue; }
        elif [ "$FORCE" = 1 ]; then
            run mv "$dest" "$dest.bak-$STAMP" || { FAILED=1; continue; }
            warn "$name differed from upstream - moved to $dest.bak-$STAMP"
        else
            warn "$name differs from upstream - kept (--force replaces it)"
            [ -n "${MADE[$name]:-}" ] && RECORD+=("$name"$'\t'"${MADE[$name]}")
            FAILED=1
            continue
        fi
    fi

    case "$MODE" in
        link) run ln -s "$src" "$dest" ;;
        relative-link) run ln -s "$(relpath "$DEST_REAL" "$src")" "$dest" ;;
        copy) run cp -R "$src" "$dest" && RECORD+=("$name"$'\t'"$(digest "$src")") ;;
    esac || { warn "could not install $name"; FAILED=1; continue; }
    [ "$DRY_RUN" = 1 ] || info "installed $name"
done

# Copies of a rule renamed or deleted upstream: removed if never edited.
for name in "${!MADE[@]}"; do
    [ -e "$SRC/rules/$name" ] && continue
    dest="$DEST/$name"
    [ -e "$dest" ] && [ ! -L "$dest" ] || continue
    if [ "$(digest "$dest")" = "${MADE[$name]}" ]; then
        run rm -rf "$dest" && info "removed $name - no longer upstream"
    else
        warn "$name is no longer upstream but was edited locally - kept"
        FAILED=1
        RECORD+=("$name"$'\t'"${MADE[$name]}")
    fi
done

# Links into rules/ whose target is gone: a rule renamed or deleted upstream.
for dest in "$DEST"/*; do
    [ -L "$dest" ] && [ ! -e "$dest" ] || continue
    case "$(readlink -f "$dest" 2>/dev/null || readlink "$dest")" in
        "$SRC"/rules/*) run rm -f "$dest" && info "removed $(basename "$dest") - no longer upstream" ;;
    esac
done

if [ "$DRY_RUN" != 1 ]; then
    if [ "${#RECORD[@]}" -gt 0 ]; then
        printf '%s\n' "${RECORD[@]}" >"$MANIFEST" || warn "could not write $MANIFEST"
    else
        rm -f "$MANIFEST"
    fi
fi

finished
exit "$FAILED"
