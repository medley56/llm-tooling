# LLM Tooling

Reusable agents, skills, and rules for LLM-powered coding assistants. Everything here is project-agnostic — written to drop into any repository.

Built for **Claude Code**. The files are plain Markdown with YAML frontmatter, so other assistants can read them, but the discovery mechanisms below are Claude Code's.

---

## What's Inside

### Skills

Skills are user-facing workflows, invoked by name as a slash command or matched automatically from their description. Each lives in its own directory with a `SKILL.md` and any supporting assets.

| Skill | Description |
|---|---|
| [commit](skills/commit/) | `/llm-tooling:commit` — works out what in the tree belongs in the commit from session context, writes a Conventional Commits message, and commits locally; never pushes |
| [pr-create](skills/pr-create/) | `/llm-tooling:pr-create` — writes a reviewer-focused description for the current branch and opens the pull request on GitHub, with draft, label, reviewer, and assignee options |
| [pr-review](skills/pr-review/) | `/llm-tooling:pr-review` — end-to-end PR review: runs the github-pr-reviewer agent, iterates with you finding-by-finding, and posts the review to GitHub with a severity badge on every finding and an AI-assistance attribution on every comment. Carries `comment-style.md`, the comment-writing conventions the pr-fix skill and reviewer agent also follow |
| [pr-fix](skills/pr-fix/) | `/llm-tooling:pr-fix` — end-to-end response to review feedback: rebases onto the base branch if it has moved, plans a reply to every comment, walks you through them, implements, verifies, pushes, and replies on each thread |
| [implement-change](skills/implement-change/) | `/llm-tooling:implement-change` — end-to-end change delivery: reads the request from a file, Jira ticket, Notion page, GitHub issue, or the prompt, runs the implementation-planner agent to draft an approach, agrees a plan with you before anything is written, implements and verifies it, offers to open the PR, and offers to archive the plan and outcome to a Notion database of implementation artifacts |
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

Three pieces, because Claude Code plugins can carry skills and agents but not
rules, and cannot hand an MCP server an OAuth client secret. None of the three
installs the Claude Code CLI; that belongs to whatever provisions the machine.

### Skills and agents: the plugin

This repo is its own plugin marketplace, with one plugin, `llm-tooling`:

```
/plugin marketplace add medley56/llm-tooling
/plugin install llm-tooling@llm-tooling
```

To install for everyone who works in a project, use `claude plugin install
--scope project` from a shell. That records only `enabledPlugins`, so also run
`claude plugin marketplace add medley56/llm-tooling --scope project`, or a
teammate's clone has nowhere to resolve the plugin from. It writes this to the
project's committed `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "llm-tooling": { "source": { "source": "github", "repo": "medley56/llm-tooling" } }
  }
}
```

Components are namespaced by the plugin: skills run as `/llm-tooling:commit`,
`/llm-tooling:pr-review`, and so on, and agents load as
`llm-tooling:github-pr-reviewer`.

Auto-update is off by default for a third-party marketplace. Turn it on in
`/plugin` → Marketplaces → llm-tooling → Enable auto-update, or update by hand
with `/plugin marketplace update llm-tooling` and then
`/plugin update llm-tooling@llm-tooling`.

If an older version of this repo's installer put skills or agents in
`~/.claude/skills/` or `~/.claude/agents/`, delete those entries, or every skill
appears twice — once bare, once namespaced.

### Rules: `install-rules.sh`

Clone the repo, then:

```bash
git clone https://github.com/medley56/llm-tooling.git ~/src/llm-tooling
~/src/llm-tooling/install-rules.sh                     # user scope
~/src/llm-tooling/install-rules.sh --scope project     # ./.claude/rules
```

At **user scope** each rule is symlinked into `$CLAUDE_CONFIG_DIR/rules/`
(default `~/.claude/rules/`), so `git pull` in the clone updates every project.

At **project scope** it symlinks only when the clone sits inside the project,
say as a submodule, and then with a relative link that survives a commit.
Otherwise it copies. Claude Code treats a project rule linked outside the
working directory as an external import: it does not load until external imports
are approved, it never asks for that approval over a symlink alone, and even
approved, a rule with `paths:` — [test-suite-factoring](rules/test-suite-factoring.md)
— never loads.

Re-run it after pulling to pick up upstream changes: a copy it made and nobody
has edited since is updated, and one whose rule was deleted upstream is removed.
It records what it copied in `.claude/rules/.llm-tooling-rules`. Anything else
that differs from upstream is kept with a warning; `--force` moves it to
`<name>.bak-<timestamp>` and replaces it. `--dry-run` reports without changing
anything.

### MCP servers: `install.sh`

```bash
~/src/llm-tooling/install.sh
```

It walks you through which servers to install and how each should authenticate.
`--yes` runs it straight through with no questions, which is what a container
hook wants; it also switches to that mode on its own when there is no tty, or
when `CI=true`. Servers go to **user scope** via `claude mcp add-json`, in
`~/.claude.json`, or `$CLAUDE_CONFIG_DIR/.claude.json` when that is set. See [MCP Servers](#mcp-servers) for the template and
where secrets come from.

**Servers are left alone when nothing changed.** Each server's expanded config is
compared against what is already installed, along with its stored client secret.
If both match, the server is skipped entirely.

That check matters more than it looks: `claude mcp remove` deletes the server's
stored *authorization* along with the server, and installing over an existing
name requires removing it first. Without the check, a hook that runs on every
container start would make you re-authorize every OAuth server every start.
`--force` reinstalls regardless, and costs exactly that re-authorization.

A consequence worth knowing when editing [mcp-servers.json](mcp-servers.json):
the comparison is strict, and `claude mcp add-json` silently discards some keys —
`transport` on a stdio server, for one. A key the CLI drops can never compare
equal, so the server would reinstall on every run. Leave such keys out.

```
--mcp-servers LIST    only these servers
--auth NAME=MODE      force one server's auth: primary, fallback, or skip
--secrets-from DIR    repo to read ${VAR} values from
--scope project       save prompted secrets in the repo, and read its files first
--force               reinstall servers even when nothing changed
--update              hard-reset the clone to origin/main, then re-run
--dry-run             report every action, change nothing
--doctor              report what is currently installed, change nothing
```

`--help` lists all of them.

### In a devcontainer

Put this in a **postStart** hook, so the first start installs and every start
after that updates:

```bash
LLM_TOOLING_DIR="${LLM_TOOLING_DIR:-/workspaces/llm-tooling}"
[ -d "$LLM_TOOLING_DIR/.git" ] ||
    git clone -q --depth 1 git@github.com:medley56/llm-tooling.git "$LLM_TOOLING_DIR" ||
    echo "WARNING: Could not clone llm-tooling - Is your SSH agent forwarded?"
bash "$LLM_TOOLING_DIR/install.sh" --yes --update ||
    echo "WARNING: llm-tooling MCP install failed - servers may be missing or stale"
bash "$LLM_TOOLING_DIR/install-rules.sh" ||
    echo "WARNING: llm-tooling rules install failed - rules may be missing or stale"
{ claude plugin marketplace add medley56/llm-tooling &&
    claude plugin install llm-tooling@llm-tooling &&
    claude plugin marketplace update llm-tooling &&
    claude plugin update llm-tooling@llm-tooling; } ||
    echo "WARNING: llm-tooling plugin did not install or update"
```

`install.sh --update` pulls the clone, so the rules links pick up the new
content too. `add` and `install` are no-ops once done; `update` is what moves
the plugin forward. Nothing here aborts the caller: a tooling problem is a loud
message, not a container that will not come up.

---

## Usage

Invoke a skill as a slash command — `/llm-tooling:commit`, `/llm-tooling:pr-create`, `/llm-tooling:pr-review`, `/llm-tooling:pr-fix` — or just describe what you want and let Claude match your request to a skill or agent description:

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

Servers always go to **user scope**, regardless of `--scope`: a project-scope
server lives in a `.mcp.json`, which cannot carry an OAuth client secret.
`--scope project` only changes where prompted secrets are saved and which files
are read first, so it neither removes nor duplicates an existing install — it
compares and skips.

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
cleartext**. It lives in `~/.claude.json` (or under `$CLAUDE_CONFIG_DIR`), outside any repo, but
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

The repo root is the plugin: `.claude-plugin/plugin.json` picks up `skills/` and
`agents/`, and rules live in `rules/`. This repo develops the plugin it ships, so
it registers its own checkout as the marketplace:

```bash
claude plugin marketplace add .
claude plugin install llm-tooling@llm-tooling
```

A marketplace added from a local directory loads its plugin in place, so an edit
is live in the next session; frontmatter changes need a new session.
`claude --plugin-dir .` loads it for one session without installing.
`.claude/rules` is a tracked symlink to `rules/`.
[.devcontainer/post-create.sh](.devcontainer/post-create.sh) runs those two
commands and `install.sh` at container creation and pre-fetches the pinned stdio
MCP servers; `uv` comes from a devcontainer feature.

`install.sh` sources three modules in [scripts/lib/](scripts/lib/): `ui.sh`
(output and prompting, also used by `install-rules.sh`), `env.sh` (placeholder
resolution and secret storage), and `mcp.sh` (server installation). Their only
dependencies are `bash`, `jq`, `git`, and the `claude` CLI.

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
