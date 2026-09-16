# LLM Tooling

Skills, sub-agents, and rules that Gavin installs into other repositories. **The files here are the product** — they are instructions other repos will load, not code that runs. Keep them project-agnostic: no paths, names, or conventions specific to this repo.

## Gotchas

- **`.claude/skills`, `.claude/agents`, and `.claude/rules` are symlinks** to the top-level directories of the same name. One copy of every file; edit the top-level one. The duplication is not real — do not "fix" it.
- **Frontmatter changes need a new session.** Body edits are picked up on next use; `name`, `description`, and `tools` are read at load.
- **A skill's `name` is its slash command.** Renaming a skill means renaming its directory, its `name:`, and every cross-reference. After any rename, `grep -rn '<old-name>' --include=*.md .` — the README and other skills point at each other by name.
- **Rule frontmatter is `paths:` and nothing else** — a list of globs. No `name`, no `description`. A rule with no `paths:` loads in *every* session, so omit it only for something that genuinely always applies. `rules/general-rules.md` omits it deliberately; everything narrower belongs in a skill instead, where it loads only when that workflow runs.
- **Sub-agents cannot ask the user anything.** They run without a user present and return to their caller. An agent that needs a decision returns it as a question for the calling session to ask.
- **GitHub MCP tool access is matched by a wildcard.** Repos register the server as `github` or `github-mcp`, so the agents grant `mcp__github*` rather than exact tool names, and the skills resolve schemas with `ToolSearch` keyword queries (`+github ...`) rather than `select:` names that would pin one server name.
- **`mcp-servers.json` is a template for *creating* MCP configs, not a config.** Claude Code never loads it. `install.sh` reads it and installs each server into user scope with `claude mcp add-json`. Only each entry's `config` reaches the CLI; `description`, `clientSecretVar`, `fallback`, and the top-level `prompts` drive the installer and are stripped. A project-scope `.mcp.json` cannot pass an OAuth client secret, and `github-mcp` does not authenticate without one. Editing the template changes nothing until the installer runs again.
- **A `fallback` must keep the server's name.** `github-mcp`'s fallback swaps OAuth for an `Authorization` header under the same key. Any name still has to start with `github` for the `mcp__github*` allowlists to match.
- **Secrets resolve against the working directory, and their order follows the scope.** User scope checks `$CLAUDE_CONFIG_DIR/settings.json` first, then `<--secrets-from>/.claude/settings.local.json`, `settings.json`, `.env`; project scope reverses those two groups. A real environment variable beats all of them. The installer parses these files rather than trusting the environment because its main caller is a container hook, which runs before any Claude session exists.
- **Placeholders are substituted before the config reaches the CLI.** Claude Code expands `${VAR}` only for a project-scope `.mcp.json`; a user-scope server keeps the literal string, which surfaces as a 404 against a URL containing `${VAR}`. Installed configs therefore hold cleartext tokens. `claude mcp add-json` also type-checks numeric fields, so `callbackPort` must be a literal number — even `"7878"` is rejected.
- **`claude mcp remove` deletes the server's stored authorization**, and installing over an existing name requires removing it first. `install.sh` therefore compares the expanded config and the stored client secret against what is installed and skips the server when both match — otherwise a hook running on every container start would de-authorize every OAuth server every start. `--force` reinstalls anyway and costs that re-auth. The comparison is strict and `add-json` silently discards some keys (`transport` on a stdio server), so a key the CLI drops can never compare equal and would reinstall forever. Keep them out of the template.
- **In `scripts/lib/`, a function whose stdout is its return value must not log to stdout.** Use `note`, not `info` — an `info` inside `pick_mode` ends up concatenated into the value the caller captures. For the same reason, collect a list with `mapfile` before a loop that prompts: `while read ... done < <(...)` points the loop's stdin at the process substitution, and the prompt reads from there instead of the user. And `install.sh`'s option loop consumes `$@`, so anything needing the original arguments later — the `--update` re-exec — must read the `ARGV` array captured before it, or every flag is silently dropped.

## Writing Skills, Agents, and Rules

Every file here is a prompt for a Claude 5-generation model, so [the rules of context engineering](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models) are the house style. The target is the **minimum token count that preserves behavior**.

- **Cut any sentence whose removal does not change what the model does.** Justification, restatement, and encouragement are all cost with no behavior attached.
- **Write the gotcha, not the manual.** Spend words on what is not discoverable: the ordering constraint, the tool that mangles multi-line input, the failure that looks like a different failure. Anything the model learns faster by reading the repo is waste.
- **Do not over-constrain.** Describe the goal and let judgment do the work. Reserve hard rules for destructive, irreversible, or outward-facing actions — pushing, posting, deleting.
- **Disclose progressively.** `SKILL.md` holds the workflow; detail that only one step needs goes in a sibling file that step reads, the way `skills/pr-review/comment-style.md` does.
- **One source of truth.** Point at the canonical file rather than restating it. Text duplicated in two files drifts.
- **A `Rules` section carries only what the steps do not already say.** Restating a step as a rule doubles its cost and halves its authority.
- **The `description` is the trigger, not a summary.** It decides when a skill or agent gets matched, so write the phrases a user would actually say.

## Conventions These Files Share

- **GitHub work goes through the MCP server.** The `gh` CLI is used only when the user explicitly approves it, per run. On MCP failure, tools stop, report, and name a stale auth token as the likely cause — they never troubleshoot `gh` or drag the user into a CLI debugging session.
- **PR comment conventions live in `skills/pr-review/comment-style.md`**, the severity badges and the 🤖 attribution line included. The pr-review and pr-fix skills and the github-pr-reviewer agent point at it rather than restating it.
