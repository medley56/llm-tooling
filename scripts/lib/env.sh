# Resolving ${VAR} placeholders and storing secrets. Sourced by install.sh.

# build_sources — fills SOURCES, best first.
#
# The order follows the scope. A user-scope install puts the config dir first so
# a stale token in some repo's settings.local.json cannot shadow the real one on
# the persistent volume; a project-scope install wants the repo's own files to
# win. A real environment variable beats every file either way — lookup() checks
# it before opening anything.
build_sources() {
    SOURCES=()
    [ "$SCOPE" = user ] && SOURCES+=("$CONFIG_DIR/settings.json")
    SOURCES+=(
        "$SECRETS_FROM/.claude/settings.local.json"
        "$SECRETS_FROM/.claude/settings.json"
        "$SECRETS_FROM/.env"
    )
    [ "$SCOPE" = user ] || SOURCES+=("$CONFIG_DIR/settings.json")
}

# read_env_file <file> <VAR> — last assignment wins, `export` and surrounding
# quotes are tolerated. The file is parsed, never sourced.
read_env_file() {
    local file="$1" var="$2" line val
    line="$(grep -E "^[[:space:]]*(export[[:space:]]+)?${var}=" "$file" 2>/dev/null | tail -n 1)"
    [ -n "$line" ] || return 1
    val="${line#*=}"
    val="${val%"${val##*[![:space:]]}"}"
    case "$val" in
        '"'*'"')
            val="${val#\"}"
            val="${val%\"}"
            ;;
        "'"*"'")
            val="${val#\'}"
            val="${val%\'}"
            ;;
    esac
    printf '%s' "$val"
}

# lookup <VAR> — prints the value and returns 0, or returns 1 if unset.
lookup() {
    local var="$1" val file
    val="${!var:-}"
    if [ -n "$val" ]; then
        printf '%s' "$val"
        return 0
    fi
    for file in "${SOURCES[@]}"; do
        [ -f "$file" ] || continue
        case "$file" in
            *.json) val="$(jq -r --arg v "$var" '.env[$v] // empty' "$file" 2>/dev/null)" ;;
            *) val="$(read_env_file "$file" "$var")" ;;
        esac
        if [ -n "$val" ]; then
            printf '%s' "$val"
            return 0
        fi
    done
    return 1
}

# placeholders <json> — one ${VAR} or ${VAR:-default} per line, deduplicated.
placeholders() {
    grep -o '\${[A-Za-z_][A-Za-z0-9_]*\(:-[^}]*\)\?}' <<<"$1" | LC_ALL=C sort -u
}

# var_of <placeholder> — the bare variable name.
var_of() {
    local var="${1#\$\{}"
    var="${var%\}}"
    printf '%s' "${var%%:-*}"
}

# default_of <placeholder> — the default, or the empty string if it has none.
default_of() {
    local var="${1#\$\{}"
    var="${var%\}}"
    case "$var" in
        *:-*) printf '%s' "${var#*:-}" ;;
    esac
}

# missing_vars <json> — names of variables with neither a value nor a default.
missing_vars() {
    local json="$1" ph var
    while IFS= read -r ph; do
        [ -n "$ph" ] || continue
        [ -n "$(default_of "$ph")" ] && continue
        var="$(var_of "$ph")"
        lookup "$var" >/dev/null || printf '%s\n' "$var"
    done < <(placeholders "$json") | LC_ALL=C sort -u
}

# expand <json> — prints it with every placeholder replaced. Substitution goes
# through jq rather than sed so the value is JSON-escaped, and uses split/join
# rather than gsub so `${`, `}` and `-` stay literal.
expand() {
    local json="$1" ph var default value
    while IFS= read -r ph; do
        [ -n "$ph" ] || continue
        var="$(var_of "$ph")"
        default="$(default_of "$ph")"
        if ! value="$(lookup "$var")"; then
            value="$default"
            [ -n "$value" ] || warn "$var is unset with no default - using an empty string"
        fi
        json="$(jq -c --arg ph "$ph" --arg val "$value" \
            'walk(if type == "string" then split($ph) | join($val) else . end)' <<<"$json")"
    done < <(placeholders "$json")
    printf '%s' "$json"
}

# store_secret <VAR> <VALUE> — merges into the env block of SECRET_STORE and
# exports it, so the rest of the run resolves it without re-reading the file.
# Only an interactive run reaches this: a hook reads secrets, it never invents
# them.
store_secret() {
    local var="$1" value="$2" tmp
    export "$var=$value"
    if [ "$DRY_RUN" = 1 ]; then
        info "would save $var to $SECRET_STORE"
        return 0
    fi
    if [ "$SCOPE" != user ] && ! git -C "$SECRETS_FROM" check-ignore -q "$SECRET_STORE" 2>/dev/null; then
        warn "$SECRET_STORE is not gitignored - not saving $var there"
        return 1
    fi
    mkdir -p "$(dirname "$SECRET_STORE")" || return 1
    [ -f "$SECRET_STORE" ] || printf '{}\n' >"$SECRET_STORE"
    tmp="$(mktemp "$SECRET_STORE.XXXXXX")" || return 1
    if jq --arg k "$var" --arg v "$value" '.env = ((.env // {}) + {($k): $v})' "$SECRET_STORE" >"$tmp" &&
        chmod 600 "$tmp" && mv "$tmp" "$SECRET_STORE"; then
        info "saved $var to $SECRET_STORE (${#value} chars)"
    else
        rm -f "$tmp"
        warn "could not save $var to $SECRET_STORE"
        return 1
    fi
}
