# LLM Tooling

Reusable skills and agents for LLM-powered coding assistants, shipped as a Claude Code plugin. Everything here is project-agnostic — written to drop into any repository.

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
| [implement-change](skills/implement-change/) | `/llm-tooling:implement-change` — end-to-end change delivery: reads the request from a file, Jira ticket, Notion page, GitHub issue, or the prompt, runs the implementation-planner agent to draft an approach and the implementation-plan-reviewer to challenge it, agrees a plan with you before anything is written, implements it, loops the implementation-reviewer until it is satisfied, offers to open the PR, and offers to archive the plan and outcome to a Notion database of implementation artifacts |
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
| [implementation-plan-reviewer](agents/implementation-plan-reviewer.md) | Adversarially reviews a draft implementation plan for unnecessary complexity and missed detail before it goes to the user |
| [implementation-reviewer](agents/implementation-reviewer.md) | Verifies a finished implementation: runs the tests and linters, judges the diff against the plan and scope, and enforces the repo's style, test-suite factoring, and coverage |
| [pytest-runner](agents/pytest-runner.md) | Runs pytest and reports results: a short summary on success, full stack traces on failure |

---

## Installation

This repo is its own plugin marketplace, with one plugin, `llm-tooling`. It
needs the Claude Code CLI already installed:

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

### In a devcontainer

Put this in a **postStart** hook, so the first start installs and every start
after that updates:

```bash
{ claude plugin marketplace add medley56/llm-tooling &&
    claude plugin install llm-tooling@llm-tooling &&
    claude plugin marketplace update llm-tooling &&
    claude plugin update llm-tooling@llm-tooling; } ||
    echo "WARNING: llm-tooling plugin did not install or update"
```

`add` and `install` are no-ops once done; `update` is what moves the plugin
forward. The `||` keeps a tooling problem from stopping the container.

### Upgrading From the Old Installers

Earlier versions of this repo shipped `install.sh`, `install-rules.sh`, and
`mcp-servers.json`. They are gone; remove any hook line that calls them.

- Skills or agents they put in `~/.claude/skills/` or `~/.claude/agents/`: delete
  them, or every skill appears twice — once bare, once namespaced.
- `general-rules.md`, `test-suite-factoring.md`, and `.llm-tooling-rules` in
  `~/.claude/rules/` or a project's `.claude/rules/`: delete them.
- MCP servers they installed keep working and need nothing from this repo.

---

## Usage

Invoke a skill as a slash command — `/llm-tooling:commit`, `/llm-tooling:pr-create`, `/llm-tooling:pr-review`, `/llm-tooling:pr-fix` — or just describe what you want and let Claude match your request to a skill or agent description:

```
Run the tests.
Open a PR for this branch as a draft, and put @alice on it.
```

### MCP Servers

This plugin installs no MCP servers. Some skills need one you install yourself,
with `claude mcp add` or in your own devcontainer hook:

| Server | Used by |
|---|---|
| GitHub | pr-create, pr-review, pr-fix, and their agents; implement-change for GitHub issues |
| Jira, Notion | implement-change, when the request lives there or you archive to Notion |

Register a server under any name. Skills and agents find its tools by what they
do, not by server name, and the GitHub agents are granted every MCP tool the
session has.

The PR skills and agents use GitHub through MCP, not the `gh` CLI. If MCP is
unavailable they stop and tell you — usually a stale auth token, and refreshing
it is the fastest fix. They use `gh` only if you explicitly say so, and they
will not troubleshoot `gh` for you.

---

## Developing These Tools

The repo root is the plugin: `.claude-plugin/plugin.json` picks up `skills/` and
`agents/`. This repo develops the plugin it ships, so it registers its own
checkout as the marketplace:

```bash
claude plugin marketplace add .
claude plugin install llm-tooling@llm-tooling
```

A marketplace added from a local directory loads its plugin in place, so an edit
is live in the next session; frontmatter changes need a new session.
`claude --plugin-dir .` loads it for one session without installing.
[.devcontainer/post-create.sh](.devcontainer/post-create.sh) installs the Claude
Code CLI and runs those two commands at container creation.

### New Skill

Create a directory under `skills/` with a `SKILL.md`:

1. Frontmatter with `name` (this is the slash command), `description`, and optional `metadata`. The `description` decides when the skill is matched automatically — write the phrases a user would actually say.
2. Write the workflow in the body.
3. Put supporting assets in the same directory.

### New Agent

Create a Markdown file in `agents/`:

1. Frontmatter with `name`, `description`, `model`, and either `tools` (an allowlist) or `disallowedTools` (everything else, MCP included). An agent that uses an MCP server takes `disallowedTools`: a `tools:` entry must name the server, and server names differ between machines. Set `model` to a specific model when the work does not need the session's default — `pytest-runner` uses `sonnet`.
2. The `description` determines when the agent is triggered — write clear activation phrases.
3. Write the steps in the body.

---

## License

This project is open source. See the repository for license details.
