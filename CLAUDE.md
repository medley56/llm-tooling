# LLM Tooling

Skills and sub-agents that Gavin installs into other repositories. **The files here are the product** — they are instructions other repos will load, not code that runs. Keep them project-agnostic: no paths, names, or conventions specific to this repo.

## Gotchas

- **The repo root is the plugin, and the repo is its own marketplace.** `.claude-plugin/plugin.json` picks up the default `skills/` and `agents/`; `.claude-plugin/marketplace.json` lists it with `source: "./"`. The devcontainer hook registers this checkout as a local marketplace and installs `llm-tooling`, which loads it in place, so edits are live; `claude --plugin-dir .` does the same for one session.
- **A plugin skill loads from the plugin cache, or in place from a local marketplace**, at user or project scope, so a path to another file never assumes `.claude/skills/`, `~/.claude/`, or this repo's layout. Use `${CLAUDE_SKILL_DIR}`, which Claude Code substitutes in skill content. A sibling skill is at `${CLAUDE_SKILL_DIR}/../<skill>`. Agents get no such variable; the calling skill passes them any path they need.
- **Frontmatter changes need a new session.** Body edits are picked up on next use; `name`, `description`, `tools`, and `disallowedTools` are read at load.
- **A skill's slash command is `/llm-tooling:<name>`.** Renaming a skill means renaming its directory, its `name:`, and every cross-reference. After any rename, `grep -rn '<old-name>' --include=*.md .` — the README and other skills point at each other by name.
- **Sub-agents cannot ask the user anything.** They run without a user present and return to their caller. An agent that needs a decision returns it as a question for the calling session to ask.
- **MCP server names differ between machines, so nothing here names one.** Skills and agents find tools with a `ToolSearch` keyword search for what the tool does (`pull request read`), never a server prefix like `+github`. An agent that uses MCP omits `tools:` and lists `disallowedTools` instead, which grants every MCP tool: a `tools:` entry must be a literal tool name, `mcp__<server>`, or `mcp__<server>__*` — there is no wildcard across servers. Those agents can therefore reach write tools, so their body forbids writing to the service.
- **Users get an update only when `version` in `.claude-plugin/plugin.json` changes.** Bump it in the same commit as any change to a skill, agent, or manifest, by semver from the commit type: `feat` minor, `fix` and `refactor` patch, `!` or `BREAKING CHANGE` major. Keep it out of `marketplace.json` — the two would drift. Run `claude plugin validate .` after changing either manifest.
- **The repo ships only skills and agents.** No MCP servers: they belong to whatever provisions the machine. No rules: plugins cannot ship them, so prose and conventions go in the skill or agent that needs them, where they load only when that workflow runs.

## Writing Skills and Agents

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
- **Code-review standards live in `agents/implementation-reviewer.md`**, severities included. Tests and linters run in the local-ci-runner agent. The github-pr-reviewer agent runs it first, then three reviewers primed with its results, two on Sonnet and one on its own model, rather than keeping criteria of its own; add a review criterion there, not in a caller.
- **PR comment conventions live in `skills/pr-review/comment-style.md`**, the severity badges and the 🤖 attribution line included. The pr-review and pr-fix skills and the github-pr-reviewer agent point at it rather than restating it. pr-create does not load it, so it repeats the one rule a PR description shares with comments — never link an internal Jira issue or Confluence page; change both together.
