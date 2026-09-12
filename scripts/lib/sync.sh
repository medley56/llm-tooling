# Mirroring skills, agents, and rules into a Claude config directory.
# Sourced by install.sh.
#
# Components are identified by name, and upstream always wins. Anything in the
# destination that upstream does not have, and anything upstream does have but
# whose content differs, is moved into a timestamped backup directory before the
# destination is replaced. That second case is the one worth being loud about:
# it is a local edit to a file this repo also ships, and without the backup the
# replace would destroy it silently.

# list_names <dir> — one entry name per line, dotfiles included, C-sorted.
list_names() {
    local dir="$1" path
    [ -d "$dir" ] || return 0
    (
        shopt -s nullglob dotglob
        cd "$dir" 2>/dev/null || exit 0
        for path in *; do printf '%s\n' "$path"; done
    ) | LC_ALL=C sort
}

# stash_path <path> <backup-relative-path> <reason> — moves one path aside.
stash_path() {
    local path="$1" rel="$2" reason="$3" dir
    dir="$BACKUP_DIR/$(dirname "$rel")"
    if [ "$DRY_RUN" = 1 ]; then
        warn "$rel $reason - would move to $BACKUP_DIR/$rel"
        return 0
    fi
    mkdir -p "$dir" || return 1
    mv "$path" "$BACKUP_DIR/$rel" || return 1
    warn "$rel $reason - moved to $BACKUP_DIR/$rel"
}

# stash <type> <name> <reason> — moves one component entry aside.
stash() {
    stash_path "$DEST_ROOT/$1/$2" "$1/$2" "$3"
}

# sync_component <type> — mirrors SRC/<type> into DEST_ROOT/<type>.
sync_component() {
    local type="$1" src="$SRC/$type" dest="$DEST_ROOT/$type" name reason
    local -a upstream=() local_entries=()

    if [ ! -d "$src" ]; then
        warn "no $type/ in $SRC - skipping"
        return 0
    fi

    if [ "$LINK" = 1 ]; then
        link_component "$type" "$src" "$dest"
        return
    fi

    mapfile -t upstream < <(list_names "$src")
    mapfile -t local_entries < <(list_names "$dest")

    # Detection runs either way. --no-backup skips the move, not the warning:
    # overwriting without saying so is the thing this is here to prevent.
    for name in "${local_entries[@]}"; do
        [ -n "$name" ] || continue
        if ! printf '%s\n' "${upstream[@]}" | grep -qxF -- "$name"; then
            reason="is not in llm-tooling"
        elif ! diff -rq "$src/$name" "$dest/$name" >/dev/null 2>&1; then
            reason="differs from llm-tooling"
        else
            continue
        fi
        if [ "$BACKUP" = 1 ]; then
            stash "$type" "$name" "$reason" || return 1
        else
            warn "$type/$name $reason - discarded (--no-backup)"
        fi
    done

    if [ "$DRY_RUN" = 1 ]; then
        info "would install $type: ${upstream[*]}"
        return 0
    fi

    # Guarded because the replace below is an rm -rf built from two variables.
    if [ -z "$DEST_ROOT" ] || [ -z "$type" ]; then
        warn "refusing to replace $dest - empty path component"
        return 1
    fi

    # cp -R needs the parent to exist; on a fresh machine the config dir does not.
    mkdir -p "$DEST_ROOT" || {
        warn "could not create $DEST_ROOT"
        return 1
    }

    rm -rf "$dest" && cp -R "$src" "$dest" || {
        warn "could not install $type into $dest"
        return 1
    }
    info "installed $type: ${upstream[*]}"
}

# link_component <type> <src> <dest> — the --link alternative to copying. Only
# safe where the checkout outlives the config dir, so it is not the default.
link_component() {
    local type="$1" src="$2" dest="$3"
    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
        info "$type already linked to $src"
        return 0
    fi
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        if [ "$BACKUP" = 1 ]; then
            stash_path "$dest" "$type" "would be replaced by a symlink" || {
                warn "$dest exists and is not a symlink - skipping $type"
                return 1
            }
        else
            warn "$dest discarded (--no-backup) - replacing it with a symlink"
        fi
    fi
    if [ "$DRY_RUN" = 1 ]; then
        info "would link $dest -> $src"
        return 0
    fi
    mkdir -p "$(dirname "$dest")" || return 1
    rm -rf "$dest" && ln -s "$src" "$dest" || {
        warn "could not link $dest -> $src"
        return 1
    }
    info "linked $type -> $src"
}

# prune_backups — drops backup directories older than KEEP_BACKUPS days, so a
# container that reinstalls on every start does not accumulate them forever.
prune_backups() {
    local root="$DEST_ROOT/llm-tooling-backups"
    [ -d "$root" ] || return 0
    [ "$DRY_RUN" = 1 ] && return 0
    find "$root" -mindepth 1 -maxdepth 1 -type d -mtime "+$KEEP_BACKUPS" \
        -exec rm -rf {} + 2>/dev/null || true
    rmdir "$root" 2>/dev/null || true
}
