# LLM Tooling

Skills, sub-agents, and rules that Gavin installs into other repositories. **The files here are the product** — they are instructions other repos will load, not code that runs. Keep them project-agnostic: no paths, names, or conventions specific to this repo.

## Gotchas

- **`.claude/skills`, `.claude/agents`, and `.claude/rules` are symlinks** to the top-level directories of the same name. One copy of every file; edit the top-level one. The duplication is not real — do not "fix" it.
- **Frontmatter changes need a new session.** Body edits are picked up on next use; `name`, `description`, and `tools` are read at load.
- **A skill's `name` is its slash command.** Renaming a skill means renaming its directory, its `name:`, and every cross-reference. After any rename, `grep -rn '<old-name>' --include=*.md .` — the README and other skills point at each other by name.
- **Rule frontmatter is `paths:` and nothing else** — a list of globs. No `name`, no `description`. A rule with no `paths:` loads in *every* session, so omit it only for something that genuinely always applies. `rules/general-rules.md` omits it deliberately; everything narrower belongs in a skill instead, where it loads only when that workflow runs.
- **Sub-agents cannot ask the user anything.** They run without a user present and return to their caller. An agent that needs a decision returns it as a question for the calling session to ask.
- **MCP tool names carry the server name.** The GitHub tools are written `mcp__github-mcp__*`, matching the `github-mcp` key in `mcp-servers.json`. Rename the server and every `tools:` list and `ToolSearch` selector has to move with it.
- **`mcp-servers.json` is a template Claude Code never loads.** `scripts/install-mcp-servers.sh` installs each server into user scope with `claude mcp add-json`. The name is deliberate: a project-scope `.mcp.json` cannot pass an OAuth client secret, and `github-mcp` does not authenticate without one. Editing the template changes nothing until the script is re-run.
- **Secrets live in the `env` block of `.claude/settings.local.json`** because that path is gitignored in every repo. The install script resolves placeholders against the **working directory** — `$PWD/.claude/settings.local.json`, `settings.json`, `$PWD/.env`, then `$CLAUDE_CONFIG_DIR` — not against the template's directory, so one template serves many repos. It parses those files rather than trusting the environment because its main caller is a devcontainer `postCreate` hook, which runs before any Claude session and has nothing exported.
- **Placeholders are substituted before the config reaches the CLI.** Claude Code expands `${VAR}` only for a project-scope `.mcp.json`; a user-scope server keeps the literal string, which surfaces as a 404 against a URL containing `${VAR}`. Installed configs therefore hold cleartext tokens. `claude mcp add-json` also type-checks numeric fields, so `callbackPort` must be a literal number — even `"7878"` is rejected.

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
