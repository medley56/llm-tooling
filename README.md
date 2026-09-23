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
| [pr-review](skills/pr-review/) | `/pr-review` — end-to-end PR review: runs the github-pr-reviewer agent, iterates with you finding-by-finding, and posts the review to GitHub with a severity badge on every finding and an AI-assistance attribution on every comment. Carries `comment-style.md`, the comment-writing conventions the pr-fix skill and reviewer agent also follow |
| [pr-fix](skills/pr-fix/) | `/pr-fix` — end-to-end response to review feedback: rebases onto the base branch if it has moved, plans a reply to every comment, walks you through them, implements, verifies, pushes, and replies on each thread |
| [implement-change](skills/implement-change/) | `/implement-change` — end-to-end change delivery: reads the request from a file, Jira ticket, Notion page, GitHub issue, or the prompt, runs the implementation-planner agent to draft an approach, agrees a plan with you before anything is written, implements and verifies it, offers to open the PR, and offers to archive the plan and outcome to a Notion database of implementation artifacts |
| [create-presentation](skills/create-presentation/) | Creates a reveal.js HTML presentation from markdown, a topic description, or rough notes using the Assertion-Evidence slide design methodology |
| [create-gauntlet-loop-prompt](skills/create-gauntlet-loop-prompt/) | Interactively builds a "Gauntlet Loop" prompt — extracts the real requirements, sets an inspectable quality bar, and emits a builder/critic loop prompt |

### Agents

Agents are sub-agents that run a multi-step task in their own context and report back. They are invoked by a skill or by name, and several of the skills above delegate to them.

| Agent | Description |
|---|---|
| [github-pr-reviewer](agents/github-pr-reviewer.md) | Reviews a pull request and produces a review document organized by concept, with a severity on every finding |
| [github-pr-fix-planner](agents/github-pr-fix-planner.md) | Fetches unresolved PR comments and plans a response to each, separating clear actions from ones needing clarification |
| [implementation-planner](agents/implementation-planner.md) | Explores the codebase and drafts an implementation approach for a proposed change — files involved, options with trade-offs, ordered steps, tests, risks, and the questions that block implementation |
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

Clone the repo, then run the installer from it:

```bash
git clone https://github.com/medley56/llm-tooling.git ~/src/llm-tooling
~/src/llm-tooling/install.sh
```

It walks you through which components to install and how each MCP server should
authenticate. `--yes` runs it straight through with no questions, which is what
a container hook wants; it also switches to that mode on its own when there is
no tty, or when `CI=true`.

Everything installs at **user scope**, into `$CLAUDE_CONFIG_DIR` (default
`~/.claude`), so every repo on the machine picks it up:

```
$CLAUDE_CONFIG_DIR/skills/    copied from skills/
$CLAUDE_CONFIG_DIR/agents/    copied from agents/
$CLAUDE_CONFIG_DIR/rules/     copied from rules/
$CLAUDE_CONFIG_DIR/.claude.json   MCP servers, via `claude mcp add-json`
```

User scope is not just convenience for rules. A `.claude/rules/` symlink whose
target sits outside the working directory counts as an external import: it needs
per-project approval, and even then only rules *without* a `paths:` field load —
which would silently drop [test-suite-factoring](rules/test-suite-factoring.md).
Rules in `$CLAUDE_CONFIG_DIR/rules/` have neither problem.

It does **not** install the Claude Code CLI. That belongs to whatever provisions
the machine.

### What it does to what is already there

**Skills, agents, and rules are mirrored — upstream always wins.** The component
directory is replaced wholesale on every run, so an upstream edit or deletion
always lands. Nothing is destroyed quietly, though: before replacing, anything
that would be lost is moved to
`$CLAUDE_CONFIG_DIR/llm-tooling-backups/<timestamp>/` and named in a warning.
That covers both entries this repo does not have (deleted upstream, renamed, or
hand-created) and entries it does have whose content you changed locally.
Backups older than 30 days are pruned; `--keep-backups DAYS` changes that.

`--no-backup` skips the moving, not the warning — you still get told what was
overwritten, it just is not kept. Use it when the config dir is disposable.

**MCP servers are left alone when nothing changed.** Each server's expanded
config is compared against what is already installed, along with its stored
client secret. If both match, the server is skipped entirely.

That check matters more than it looks: `claude mcp remove` deletes the server's
stored *authorization* along with the server, and installing over an existing
name requires removing it first. Without the check, a hook that runs on every
container start would make you re-authorize every OAuth server every start.
`--force` reinstalls regardless, and costs exactly that re-authorization.

A consequence worth knowing when editing [mcp-servers.json](mcp-servers.json):
the comparison is strict, and `claude mcp add-json` silently discards some keys —
`transport` on a stdio server, for one. A key the CLI drops can never compare
equal, so the server would reinstall on every run. Leave such keys out.

### Useful flags

```
--components LIST     skills, agents, rules, mcp (default: all)
--scope project       put skills/agents/rules in ./.claude instead of the config
                      dir; MCP servers are always user scope either way
--link                symlink components instead of copying them
--mcp-servers LIST    only these servers
--auth NAME=MODE      force one server's auth: primary, fallback, or skip
--secrets-from DIR    repo to read ${VAR} values from
--no-backup           overwrite components without keeping a backup
--force               reinstall MCP servers even when nothing changed
--dry-run             report every action, change nothing
--doctor              report what is currently installed, change nothing
```

`--help` lists all of them.

### Updating

```bash
~/src/llm-tooling/install.sh --update
```

`--update` fetches and hard-resets the checkout to `origin/main`, then re-runs
itself. Without it, `git pull` in the clone followed by a plain run does the
same thing in two steps.

### In a devcontainer

Put this in a **postStart** hook, so the first start installs and every start
after that updates:

```bash
LLM_TOOLING_DIR="${LLM_TOOLING_DIR:-/workspaces/llm-tooling}"
[ -d "$LLM_TOOLING_DIR/.git" ] ||
    git clone -q --depth 1 git@github.com:medley56/llm-tooling.git "$LLM_TOOLING_DIR" ||
    echo "WARNING: Could not clone llm-tooling - Is your SSH agent forwarded?"
bash "$LLM_TOOLING_DIR/install.sh" --yes --update ||
    echo "WARNING: llm-tooling install failed - Tooling may be missing or stale"
```

Nothing the installer does aborts the caller: a tooling problem is a loud
message, not a container that will not come up.

---

## Usage

Invoke a skill as a slash command — `/commit`, `/pr-create`, `/pr-review`, `/pr-fix` — or just describe what you want and let Claude match your request to a skill or agent description:

```
Run the tests.
Open a PR for this branch as a draft, and put @alice on it.
```

Rules need no invocation. A rule with `paths:` loads when Claude reads a file matching its globs; one without loads every session.

### MCP Servers

[mcp-servers.json](mcp-servers.json) is a **template for creating MCP configs**,
not a config Claude Code loads. Each entry's `config` is the JSON handed to
`claude mcp add-json`; every key outside `config` drives the installer and is
stripped before the CLI sees it. Editing it changes nothing until `install.sh`
runs again.

It is not a `.mcp.json` on purpose: a project-scope `.mcp.json` has no way to
pass an OAuth client secret, and `github-mcp` will not authenticate without one.
Installing through the CLI is the only path that can hand one over.

To install only the servers:

```bash
./install.sh --components mcp
```

They always go to **user scope**, regardless of `--scope`: a project-scope
server lives in a `.mcp.json`, which cannot carry an OAuth client secret, and
`--scope project` is about where skills, agents, and rules land. So running the
project-scope variant alongside an existing user-scope install neither removes
those servers nor duplicates them — it compares and skips them.

#### Where ${VAR} values come from

Best first. A real environment variable beats every file:

```
<the environment>
$CLAUDE_CONFIG_DIR/settings.json            env block
<--secrets-from>/.claude/settings.local.json  env block
<--secrets-from>/.claude/settings.json        env block
<--secrets-from>/.env                         KEY=value, `export` and quotes allowed
```

`--secrets-from` defaults to the working directory, so by default the repo you
are standing in supplies the values. At user scope the config dir is checked
first, so a stale token left in some repo cannot shadow the real one. A
project-scope install (`--scope project`) reverses those two.

`.env` files are parsed, never sourced. The installer reads files rather than
trusting the environment because its main caller is a container hook, which runs
before any Claude session exists and has none of these variables set.

Prefer `.claude/settings.local.json` for a per-repo secret: it is gitignored
everywhere. An interactive run offers to save anything it has to ask for —
into `$CLAUDE_CONFIG_DIR/settings.json` at user scope, into
`.claude/settings.local.json` at project scope, and it refuses to write there if
the path is not actually gitignored.

#### Placeholders are substituted before install

Claude Code expands `${VAR}` only for a project-scope `.mcp.json`. A user-scope
server keeps the literal string it was installed with, which surfaces as a 404
against a URL containing `${GITHUB_MCP_CLIENT_ID}`. The installer therefore
substitutes real values first, which means **the installed config holds tokens in
cleartext**. It lives in `$CLAUDE_CONFIG_DIR/.claude.json`, outside any repo, but
do not share it.

`claude mcp add-json` also type-checks numeric fields, so `callbackPort` has to
be a literal number — even `"7878"` is rejected as `Invalid configuration`.

### GitHub Access

The PR skills and agents use the **GitHub MCP server**, not the `gh` CLI. If MCP
is unavailable they stop and tell you — usually a stale auth token, and
refreshing it is the fastest fix. They will use `gh` only if you explicitly say
so, and they will not troubleshoot `gh` for you.

The agents allowlist twelve read-only tools under both the `mcp__github__` and
`mcp__github-mcp__` prefixes, so a server registered under either name resolves
— [mcp-servers.json](mcp-servers.json) installs it as `github-mcp`. **Under any
other name nothing resolves**, and the agent then reports the server as
unavailable; add that prefix to the `tools:` lists in `agents/` to fix it.

It authenticates two ways, and keeps the name `github-mcp` either way:

**OAuth against a personal GitHub App** (the default). Put
`GITHUB_MCP_CLIENT_ID` and `GITHUB_MCP_CLIENT_SECRET` where the installer will
find them, give the app a callback URL on port 7878 to match `callbackPort`, run
the installer, then authorize once with `/mcp`.

**A personal access token**, if the client secret is missing. An interactive run
offers this as a choice; a non-interactive one takes it automatically when
`GITHUB_MCP_PAT` resolves and the client secret does not. Force it either way
with `--auth github-mcp=fallback`. Setting an `Authorization` header disables
OAuth for that server, so it is one mode or the other, never both.

This is the template's generic `fallback` mechanism, not a GitHub special case:
any server can declare a `fallback` with the variable it `requires` and the
`config` to use instead. A server whose `requires` variable stays unset is
skipped rather than installed broken.

---

## Developing These Tools

This repo develops the tooling it ships, so it installs its own components at
**project** scope as symlinks rather than copying them into the config dir:

```bash
./install.sh --yes --scope project --link --target .
```

```
.claude/skills -> ../skills
.claude/agents -> ../agents
.claude/rules  -> ../rules
```

Edits take effect immediately — there is one copy of each file, and `.claude/` is
only a view onto it. Start a new session to pick up frontmatter changes.
[.devcontainer/post-create.sh](.devcontainer/post-create.sh) runs that command at
container creation, installs `uv` as a feature, and pre-fetches the pinned stdio
MCP servers.

The installer itself is `install.sh` plus four sourced modules in
[scripts/lib/](scripts/lib/): `ui.sh` (output and prompting), `env.sh`
(placeholder resolution and secret storage), `sync.sh` (component mirroring), and
`mcp.sh` (server installation). Its only dependencies are `bash`, `jq`, `git`,
and the `claude` CLI.

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
