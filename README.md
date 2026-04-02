# LLM Tooling

A collection of reusable AI agents and skills designed to supercharge your development workflow. These tools work with **Claude Code**, **GitHub Copilot**, and other LLM-powered coding assistants — and are written to be project-agnostic so they can drop into any repository.

---

## What's Inside

### Agents

Agents are autonomous task runners that handle multi-step workflows. Each agent is a Markdown file with YAML frontmatter defining its name, description, available tools, and detailed step-by-step instructions.

| Agent | Description |
|---|---|
| [github-pr-reviewer](agents/github-pr-reviewer.md) | Reviews GitHub pull requests and provides structured feedback |
| [github-pr-fixer](agents/github-pr-fixer.md) | Fetches PR review comments and produces a structured fix plan for every unresolved comment |
| [pytest-runner](agents/pytest-runner.md) | Runs pytest with smart defaults, returns concise pass/fail reports with stack traces on failure |
| [llm-instructions-updater](agents/llm-instructions-updater.md) | Audits LLM instruction files against the codebase and produces an update plan for anything stale or missing |

### Skills

Skills are interactive, user-facing capabilities that guide the LLM through a specific creative or technical task. They live in their own directories and may include supporting assets.

| Skill | Description |
|---|---|
| [markdown-to-slidy](skills/markdown-to-slidy/) | Converts a Markdown document into a W3C Slidy2 HTML presentation using the Assertion-Evidence slide design methodology |

---

## Installation

Clone the repo directly into your workspace:

```bash
git clone https://github.com/medley56/llm-tooling.git
```

That's it. No build step, no package manager, no configuration. Your LLM assistant will discover the agents and skills automatically from the file structure.

### Updating

```bash
cd llm-tooling && git pull
```

---

## Usage

### With Claude Code

Agents are invoked automatically when Claude matches your request to an agent's description, or you can reference them explicitly:

```
Use the pytest-runner agent to run my tests.
```

Skills work the same way — ask Claude to convert a Markdown file to slides and the `markdown-to-slidy` skill activates.

### With GitHub Copilot

Copilot discovers Claude-format agent and skill definitions. Point your workspace to include this repo and the tools become available in Copilot Chat.

### With Other LLM Assistants

The agent and skill files are plain Markdown with YAML frontmatter. Any LLM tool that can read Markdown instructions can use them. The frontmatter schema:

```yaml
---
name: agent-name
description: >
  What the agent does and when to invoke it.
tools: Bash, Read, Edit, ...
model: inherit
---
```

---

## Adding Your Own

### New Agent

Create a Markdown file in `agents/` following the existing pattern:

1. Add YAML frontmatter with `name`, `description`, `tools`, and `model`
2. Write step-by-step instructions in the body
3. The `description` field determines when the agent gets triggered — write clear activation phrases

### New Skill

Create a directory under `skills/` with a `SKILL.md` file:

1. Add YAML frontmatter with `name`, `description`, and optional `metadata`
2. Write interactive instructions (skills typically involve user dialogue)
3. Include any supporting assets (templates, configs) in the same directory

---

## License

This project is open source. See the repository for license details.
