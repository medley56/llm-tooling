# LLM Tooling

Reusable agents, skills, and rules for LLM-powered coding assistants. Everything here is project-agnostic — written to drop into any repository.

Built for **Claude Code**. The files are plain Markdown with YAML frontmatter, so other assistants can read them, but the discovery mechanisms below are Claude Code's.

---

## What's Inside

### Skills

Skills are user-facing workflows, invoked by name as a slash command or matched automatically from their description. Each lives in its own directory with a `SKILL.md` and any supporting assets.

| Skill | Description |
|---|---|
| [commit](skills/commit/) | `/commit` — works out what in the tree belongs in the commit from session context, writes a Conventional Commits message, and commits locally; never pushes |
| [pr-create](skills/pr-create/) | `/pr-create` — writes a reviewer-focused description for the current branch and opens the pull request on GitHub, with draft, label, reviewer, and assignee options |
| [pr-review](skills/pr-review/) | `/pr-review` — end-to-end PR review: runs the github-pr-reviewer agent, iterates with you finding-by-finding, and posts the review to GitHub with an AI-assistance attribution header on every comment. Carries `comment-style.md`, the comment-writing conventions the pr-fix skill and reviewer agent also follow |
| [pr-fix](skills/pr-fix/) | `/pr-fix` — end-to-end response to review feedback: rebases onto the base branch if it has moved, plans a reply to every comment, walks you through them, implements, verifies, pushes, and replies on each thread |
| [create-presentation](skills/create-presentation/) | Creates a reveal.js HTML presentation from markdown, a topic description, or rough notes using the Assertion-Evidence slide design methodology |
| [create-gauntlet-loop-prompt](skills/create-gauntlet-loop-prompt/) | Interactively builds a "Gauntlet Loop" prompt — extracts the real requirements, sets an inspectable quality bar, and emits a builder/critic loop prompt |

### Agents

Agents are sub-agents that run a multi-step task in their own context and report back. They are invoked by a skill or by name, and several of the skills above delegate to them.

| Agent | Description |
|---|---|
| [github-pr-reviewer](agents/github-pr-reviewer.md) | Reviews a pull request and produces a review document organized by concept, with a severity on every finding |
| [github-pr-fix-planner](agents/github-pr-fix-planner.md) | Fetches unresolved PR comments and plans a response to each, separating clear actions from ones needing clarification |
| [repo-instructions-update-planner](agents/repo-instructions-update-planner.md) | Audits a repo's LLM context — CLAUDE.md, `.github/` Copilot instructions, agents, skills, rules, and roadmap files — for staleness and bloat, and produces an update plan |
| [pytest-runner](agents/pytest-runner.md) | Runs pytest and reports results: a short summary on success, full stack traces on failure |

### Rules

Rules are topic-scoped instructions Claude Code loads from `.claude/rules/`. A rule with a `paths:` glob list loads only when a matching file is read; a rule without one loads at the start of every session, like `CLAUDE.md`. Use them to split conventions out of an oversized `CLAUDE.md` so each costs context only when relevant.

| Rule | Loads when | Description |
|---|---|---|
| [general-rules](rules/general-rules.md) | Every session | How responses should read — plain, concrete, no tech-marketing register, no preamble |
| [test-suite-factoring](rules/test-suite-factoring.md) | A Python test file is read | How to structure a Python test suite — layout, fixtures, and what belongs in unit vs. integration vs. e2e tests |

---

## Installation

Claude Code discovers skills, agents, and rules under `.claude/` in the repository you are working in. Clone this repo somewhere permanent, then link the pieces you want into the target repo:

```bash
git clone https://github.com/medley56/llm-tooling.git ~/src/llm-tooling

cd /path/to/your-project
mkdir -p .claude
ln -s ~/src/llm-tooling/skills .claude/skills
ln -s ~/src/llm-tooling/agents .claude/agents
ln -s ~/src/llm-tooling/rules  .claude/rules
```

Symlinking the whole directory means `git pull` in the clone updates every project at once. To take only some of it, link individual entries instead:

```bash
ln -s ~/src/llm-tooling/skills/commit .claude/skills/commit
```

Add `.claude/skills`, `.claude/agents`, and `.claude/rules` to the project's `.gitignore` if your team does not all use these tools.

### Updating

```bash
cd ~/src/llm-tooling && git pull
```

---

## Usage

Invoke a skill as a slash command — `/commit`, `/pr-create`, `/pr-review`, `/pr-fix` — or just describe what you want and let Claude match your request to a skill or agent description:

```
Run the tests.
Open a PR for this branch as a draft, and put @alice on it.
```

Rules need no invocation. A rule with `paths:` loads when Claude reads a file matching its globs; one without loads every session.

### MCP Servers

[mcp-servers.json](mcp-servers.json) is a **template**, not a config Claude Code
loads. Install the servers it describes into user scope, so they are available in
every repo on the machine:

```bash
./scripts/install-mcp-servers.sh
```

It is not named `.mcp.json` on purpose: a project-scope `.mcp.json` has no way to
pass an OAuth client secret, and `github-mcp` will not authenticate without one.
Re-run the script after editing the template — nothing picks the edit up on its
own.

Values for the template's `${VAR}` placeholders are read from the **current
directory**, not from wherever the template lives — run the script from the repo
whose secrets it should use. It looks at, best first:

```
<the environment>
$PWD/.claude/settings.local.json    env block
$PWD/.claude/settings.json          env block
$PWD/.env                           KEY=value, `export` and quotes allowed
$CLAUDE_CONFIG_DIR/settings.json    env block
```

Prefer `.claude/settings.local.json`: it is gitignored in every repo, which
makes it the one safe place for a token. The script parses these files rather
than relying on the environment because its main caller, a devcontainer
`postCreate` hook, runs before any Claude session exists and so has none of
these variables set.

It substitutes every placeholder before calling the CLI. Claude Code expands
`${VAR}` only for a project-scope `.mcp.json`; a user-scope server keeps the
literal string it was installed with, which surfaces as a 404 against a URL
containing `${GITHUB_MCP_CLIENT_ID}`. The installed config therefore holds real
tokens in cleartext. It lives in `~/.claude.json` (or `$CLAUDE_CONFIG_DIR`),
outside any repo, but do not share it.

### GitHub Access

The PR skills and agents use the **GitHub MCP server**, not the `gh` CLI. If MCP is unavailable they stop and tell you — usually a stale auth token, and refreshing it is the fastest fix. They will use `gh` only if you explicitly say so, and they will not troubleshoot `gh` for you.

Their tool references are `mcp__github-mcp__*`, matching the `github-mcp` entry in [mcp-servers.json](mcp-servers.json), which authenticates over OAuth against a personal GitHub App. Put `GITHUB_MCP_CLIENT_ID` and `GITHUB_MCP_CLIENT_SECRET` in the `env` block of `.claude/settings.local.json`, give the app a callback URL on port 7878 to match `callbackPort`, run the install script, then authorize once with `/mcp`. **A server registered under a different name will not resolve those tools** — either register it as `github-mcp`, or update the `tools:` lists in `agents/` and the `ToolSearch` selectors in `skills/`.

---

## Developing These Tools

This repo links its own tooling into `.claude/`, so the skills, agents, and rules are live while you work on them:

```
.claude/skills -> ../skills
.claude/agents -> ../agents
.claude/rules  -> ../rules
```

Edits take effect immediately — there is one copy of each file, and `.claude/` is only a view onto it. Start a new session to pick up frontmatter changes.

The devcontainer installs `uv` as a feature and pre-fetches the pinned stdio MCP servers in [.devcontainer/post-create.sh](.devcontainer/post-create.sh), which runs at container creation only.

### New Skill

Create a directory under `skills/` with a `SKILL.md`:

1. Frontmatter with `name` (this is the slash command), `description`, and optional `metadata`. The `description` decides when the skill is matched automatically — write the phrases a user would actually say.
2. Write the workflow in the body.
3. Put supporting assets in the same directory.

### New Agent

Create a Markdown file in `agents/`:

1. Frontmatter with `name`, `description`, `tools`, and `model`. Set `model` to a specific model when the work does not need the session's default — `pytest-runner` uses `sonnet`.
2. The `description` determines when the agent is triggered — write clear activation phrases.
3. Write the steps in the body.

### New Rule

Create a Markdown file in `rules/`:

1. Add a `paths:` list of globs so the rule loads only when a matching file is read. Omit `paths:` only if the rule genuinely applies to every session — it costs context in all of them.
2. Keep it short and specific. A rule is not a manual.
3. Do not restate what already lives in a skill or agent. Point at the canonical file so there is one source of truth.

---

## License

This project is open source. See the repository for license details.
