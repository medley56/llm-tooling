# Output and prompting. Sourced by install.sh; not executable on its own.
#
# Every prompt returns its default when INTERACTIVE is not 1, so the same code
# path serves a walkthrough and a container hook. Prompts go to stderr because
# most of these run inside $( ), where stdout is the return value.

section() { printf '\n=== %s ===\n' "$*"; }
info() { printf 'INFO: %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
finished() { printf 'Done\n'; }

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit "${2:-1}"
}

# confirm <prompt> [yes|no] — the second argument is the answer a
# non-interactive run gives, and the one an empty reply takes.
confirm() {
    local prompt="$1" default="${2:-no}" hint reply
    if [ "$INTERACTIVE" != 1 ]; then
        [ "$default" = yes ]
        return
    fi
    hint="[y/N]"
    [ "$default" = yes ] && hint="[Y/n]"
    printf '%s %s ' "$prompt" "$hint" >&2
    read -r reply || reply=""
    reply="${reply:-$default}"
    case "$reply" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

# ask <prompt> [default] — prints the answer.
ask() {
    local prompt="$1" default="${2:-}" reply
    if [ "$INTERACTIVE" != 1 ]; then
        printf '%s' "$default"
        return
    fi
    if [ -n "$default" ]; then
        printf '%s [%s]: ' "$prompt" "$default" >&2
    else
        printf '%s: ' "$prompt" >&2
    fi
    read -r reply || reply=""
    printf '%s' "${reply:-$default}"
}

# ask_secret <prompt> — prints the answer without ever echoing it. Returns 1 on
# an empty reply or a non-interactive run, so callers can treat "no value" and
# "cannot ask" the same way.
ask_secret() {
    local prompt="$1" reply
    [ "$INTERACTIVE" = 1 ] || return 1
    printf '%s: ' "$prompt" >&2
    read -rs reply || reply=""
    printf '\n' >&2
    [ -n "$reply" ] || return 1
    printf '%s' "$reply"
}

# choose <default-index> <prompt> <option>... — prints the 1-based index picked.
# Anything unparseable falls back to the default rather than re-prompting; this
# is a setup script, not a shell.
choose() {
    local default="$1" prompt="$2"
    shift 2
    local opts=("$@") i reply
    if [ "$INTERACTIVE" != 1 ]; then
        printf '%s' "$default"
        return
    fi
    printf '%s\n' "$prompt" >&2
    for i in "${!opts[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${opts[$i]}" >&2
    done
    printf 'Choice [%s]: ' "$default" >&2
    read -r reply || reply=""
    reply="${reply:-$default}"
    case "$reply" in
        '' | *[!0-9]*) printf '%s' "$default" ;;
        *)
            if [ "$reply" -ge 1 ] && [ "$reply" -le "${#opts[@]}" ]; then
                printf '%s' "$reply"
            else
                printf '%s' "$default"
            fi
            ;;
    esac
}

# note <message> — info that is safe inside $( ). A function whose stdout is its
# return value must never log there.
note() { printf 'INFO: %s\n' "$*" >&2; }
