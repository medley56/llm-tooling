# LLM Tooling

Skills, sub-agents, and rules that Gavin installs into other repositories. **The files here are the product** — they are instructions other repos will load, not code that runs. Keep them project-agnostic: no paths, names, or conventions specific to this repo.

## Gotchas

- **`.claude/skills`, `.claude/agents`, and `.claude/rules` are symlinks** to the top-level directories of the same name. One copy of every file; edit the top-level one. The duplication is not real — do not "fix" it.
- **Frontmatter changes need a new session.** Body edits are picked up on next use; `name`, `description`, and `tools` are read at load.
- **A skill's `name` is its slash command.** Renaming a skill means renaming its directory, its `name:`, and every cross-reference. After any rename, `grep -rn '<old-name>' --include=*.md .` — the README and other skills point at each other by name.
- **Rule frontmatter is `paths:` and nothing else** — a list of globs. No `name`, no `description`. A rule with no `paths:` loads in *every* session, so omit it only for something that genuinely always applies.
- **Sub-agents cannot ask the user anything.** They run without a user present and return to their caller. An agent that needs a decision returns it as a question for the calling session to ask.

## Conventions These Files Share

- **GitHub work goes through the MCP server.** The `gh` CLI is used only when the user explicitly approves it, per run. On MCP failure, tools stop, report, and name a stale auth token as the likely cause — they never troubleshoot `gh` or drag the user into a CLI debugging session.
- **The 🤖 attribution header on posted comments is defined once**, in `skills/pr-review/SKILL.md`. Other files point at it rather than restating the wording.
- **Write for a capable model.** Spend words on what is not discoverable — the ordering constraint, the tool that mangles multi-line input, the failure that looks like a different failure. Cut anything the model would learn faster by reading the repo. Reserve hard rules for destructive, irreversible, or outward-facing actions; elsewhere describe the goal and let judgment do the work.
