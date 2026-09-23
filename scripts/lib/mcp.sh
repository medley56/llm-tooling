# Installing MCP servers from the template. Sourced by install.sh.
#
# Servers go into Claude Code's user scope because that is the only scope that
# can carry an OAuth client secret — a project .mcp.json has nowhere to put one,
# and github-mcp does not authenticate without it.
#
# Placeholders are substituted here, before the config reaches the CLI. Claude
# Code expands ${VAR} only for a project-scope .mcp.json; a user-scope server
# keeps the literal string it was installed with, which surfaces as a 404
# against a URL containing ${GITHUB_MCP_CLIENT_ID}. The installed config
# therefore holds real tokens in cleartext.

# server_names — every name in the template, in file order.
server_names() {
    jq -r '.servers[].name' "$TEMPLATE"
}

# server_entry <name> — the whole template entry, compact.
server_entry() {
    jq -c --arg n "$1" '.servers[] | select(.name == $n)' "$TEMPLATE"
}

# label_for <VAR> — the template's prompt for it, or the bare name.
label_for() {
    local label
    label="$(jq -r --arg v "$1" '.prompts[$v] // empty' "$TEMPLATE" 2>/dev/null)"
    printf '%s' "${label:-$1}"
}

# auth_override <name> — the mode forced on the command line, if any.
auth_override() {
    local pair
    for pair in "${AUTH_MODES[@]}"; do
        [ "${pair%%=*}" = "$1" ] && printf '%s' "${pair#*=}" && return 0
    done
    return 1
}

# ask_for <VAR> — prompts for it, exports it so the rest of the run resolves it,
# and offers to save it. Returns 1 if there was no answer or no one to ask.
ask_for() {
    local var="$1" value
    value="$(ask_secret "  $(label_for "$var")")" || return 1
    if confirm "  Save $var to $SECRET_STORE?" yes; then
        store_secret "$var" "$value" || export "$var=$value"
    else
        export "$var=$value"
    fi
}

# prompt_for_missing <json> — asks for every placeholder the config still needs.
# This is the only place placeholders are prompted for, so nothing gets asked
# twice. Non-interactive runs skip it and let expand() warn instead.
#
# The names are collected before prompting, not read in the loop header: a
# `while read ... done < <(...)` would point the loop's stdin at the process
# substitution, and the prompt inside it would read from there instead of from
# the user.
prompt_for_missing() {
    local var
    local -a vars=()
    [ "$INTERACTIVE" = 1 ] || return 0
    mapfile -t vars < <(missing_vars "$1")
    for var in "${vars[@]}"; do
        [ -n "$var" ] || continue
        ask_for "$var" || true
    done
}

# pick_mode <name> <entry> — prints primary, fallback, or skip.
#
# A server declaring clientSecretVar needs that secret to work at all, so a
# missing one is the decision point: use the fallback if the template has one,
# or go ahead and install something that will not authorize.
pick_mode() {
    local name="$1" entry="$2" mode secret_var fb_desc fb_var
    if mode="$(auth_override "$name")"; then
        printf '%s' "$mode"
        return 0
    fi

    secret_var="$(jq -r '.clientSecretVar // empty' <<<"$entry")"
    if [ -z "$secret_var" ] || lookup "$secret_var" >/dev/null; then
        printf 'primary'
        return 0
    fi

    if ! jq -e '.fallback' >/dev/null 2>&1 <<<"$entry"; then
        [ "$INTERACTIVE" = 1 ] ||
            warn "$name needs $secret_var and it is unset - installing anyway, it will not authorize"
        printf 'primary'
        return 0
    fi

    fb_desc="$(jq -r '.fallback.description // "use the fallback configuration"' <<<"$entry")"
    fb_var="$(jq -r '.fallback.requires // empty' <<<"$entry")"

    if [ "$INTERACTIVE" != 1 ]; then
        if [ -n "$fb_var" ] && lookup "$fb_var" >/dev/null; then
            note "$name: $secret_var is unset, falling back to $fb_var"
            printf 'fallback'
        else
            warn "$name needs $secret_var or $fb_var and has neither - installing anyway, it will not authorize"
            printf 'primary'
        fi
        return 0
    fi

    case "$(choose 2 "  $secret_var is not set. How should $name authenticate?" \
        "enter the OAuth client secret now" \
        "$fb_desc" \
        "skip this server")" in
        1) printf 'primary' ;;
        2) printf 'fallback' ;;
        *) printf 'skip' ;;
    esac
}

# install_server <name> — returns 1 if the server was wanted but did not install.
install_server() {
    local name="$1" entry desc mode config secret secret_var required
    entry="$(server_entry "$name")"
    if [ -z "$entry" ]; then
        warn "no server named $name in $TEMPLATE"
        return 1
    fi

    desc="$(jq -r '.description // ""' <<<"$entry")"
    [ -n "$desc" ] && info "$name - $desc" || info "$name"

    mode="$(pick_mode "$name" "$entry")"
    case "$mode" in
        skip)
            info "$name skipped"
            return 0
            ;;
        fallback)
            config="$(jq -c '.fallback.config' <<<"$entry")"
            required="$(jq -r '.fallback.requires // empty' <<<"$entry")"
            secret_var=""
            ;;
        *)
            config="$(jq -c '.config' <<<"$entry")"
            required=""
            secret_var="$(jq -r '.clientSecretVar // empty' <<<"$entry")"
            ;;
    esac

    # The client secret never appears in the config — it goes to the CLI on its
    # own — so it is asked for separately from the placeholders.
    if [ "$INTERACTIVE" = 1 ] && [ -n "$secret_var" ] && ! lookup "$secret_var" >/dev/null; then
        ask_for "$secret_var" || true
    fi
    prompt_for_missing "$config"

    # A variable the template calls required is not optional: installing with it
    # empty produces a server that fails at the first request, which is harder
    # to diagnose than one that is simply absent.
    if [ -n "$required" ] && ! lookup "$required" >/dev/null; then
        warn "$name needs $required and it is still unset - not installing it"
        return 1
    fi

    secret=""
    if [ -n "$secret_var" ]; then
        secret="$(lookup "$secret_var")" || secret=""
    fi

    config="$(expand "$config")"

    if [ "$FORCE" != 1 ] && unchanged "$name" "$config" "$secret"; then
        info "$name is already installed and unchanged"
        return 0
    fi

    if [ "$DRY_RUN" = 1 ]; then
        info "would install $name ($mode)"
        return 0
    fi

    # add-json refuses a name that already exists, so remove first. Removing
    # also deletes the server's stored authorization, which is why the check
    # above exists: reaching this line always costs a re-authorization.
    claude mcp remove -s user "$name" >/dev/null 2>&1 || true

    if [ -n "$secret" ]; then
        if MCP_CLIENT_SECRET="$secret" claude mcp add-json -s user --client-secret "$name" "$config" >/dev/null; then
            info "installed $name (client secret from $secret_var)"
            MCP_INSTALLED=$((MCP_INSTALLED + 1))
        else
            warn "could not install $name"
            return 1
        fi
    elif claude mcp add-json -s user "$name" "$config" >/dev/null; then
        if [ "$mode" = fallback ]; then
            info "installed $name (token authentication)"
            MCP_INSTALLED=$((MCP_INSTALLED + 1))
        else
            info "installed $name"
            MCP_INSTALLED=$((MCP_INSTALLED + 1))
        fi
    else
        warn "could not install $name"
        return 1
    fi
}

# install_mcp — walks the whole template. Returns 1 if any server failed.
install_mcp() {
    local name w failed=0 wanted
    local -a names=()
    mapfile -t names < <(server_names)

    for w in "${MCP_ONLY[@]}"; do
        printf '%s\n' "${names[@]}" | grep -qxF -- "$w" ||
            { warn "no server named $w in $TEMPLATE"; failed=1; }
    done

    for name in "${names[@]}"; do
        [ -n "$name" ] || continue
        if [ "$MCP_FILTERED" = 1 ]; then
            wanted=0
            for w in "${MCP_ONLY[@]}"; do [ "$w" = "$name" ] && wanted=1; done
            [ "$wanted" = 1 ] || continue
        fi
        install_server "$name" || failed=1
    done

    if [ "$DRY_RUN" != 1 ]; then
        info "checking server health"
        claude mcp list 2>&1 | sed 's/^/INFO:   /' || true
    fi
    return "$failed"
}

# installed_config <name> — the config currently installed at user scope.
installed_config() {
    jq -c --arg n "$1" '.mcpServers[$n] // empty' "$GLOBAL_CONFIG" 2>/dev/null
}

# installed_secret <name> — the client secret registered for it, if any. The
# credential key is "<name>|<hash of the config>", so a config change re-keys it
# and this finds nothing, which is the answer we want.
installed_secret() {
    jq -r --arg n "$1" '
        (.mcpOAuthClientConfig // {}) | to_entries[]
        | select(.key | startswith($n + "|")) | .value.clientSecret // empty
    ' "$CONFIG_DIR/.credentials.json" 2>/dev/null | head -n 1
}

# unchanged <name> <config> <secret> — true if reinstalling would change nothing.
#
# Worth checking, because `claude mcp remove` deletes the server's stored
# authorization along with the server. Without this, a hook that runs on every
# container start would de-authorize every OAuth server on every start.
#
# The comparison is strict, so a key add-json discards — `transport` on a stdio
# server — would make it never match. Keep such keys out of the template.
unchanged() {
    local name="$1" want="$2" secret="$3" have
    have="$(installed_config "$name")"
    [ -n "$have" ] || return 1
    [ "$(jq -cS . <<<"$want" 2>/dev/null)" = "$(jq -cS . <<<"$have" 2>/dev/null)" ] || return 1
    [ "$secret" = "$(installed_secret "$name")" ] || return 1
}
