---
name: pr-create
description: >
  Writes a reviewer-focused description for the current branch and opens the
  pull request on GitHub. Invoked as /llm-tooling:pr-create, or when the user asks to "open
  a PR", "put up a PR", "create a pull request", or "write a PR description".
  Accepts draft status, title, base branch, labels, reviewers, and assignees.
  Uses the GitHub MCP server; falls back to the gh CLI only with the user's
  explicit approval.
metadata:
  author: llm-tooling
  version: 2.2.0
---

# Open a Pull Request

Describe what this branch does, then open the PR. The description is written for a reviewer who knows the project but not this change.

## Options

Take these from the user's request when present; otherwise use the default:

| Option | Default |
|---|---|
| Draft | Not a draft, unless the user says draft or the branch has obvious WIP commits |
| Title | Derived from the change; a single-commit branch may use its subject |
| Base branch | The repo's default branch |
| Labels, reviewers, assignees | None |

What the user supplies wins over what you infer, including their framing of *why* the change exists. Supplement it from the code; do not second-guess it.

## GitHub Access

Resolve the MCP tools with `ToolSearch` keyword searches (`+github get me`, plus `+github create pull request`) before any other work. The `+github` prefix matches whether the server is registered as `github` or `github-mcp`. Names vary by server version. You will need tools to create a PR, update one, and set labels and reviewers.

If MCP cannot be reached or authenticated, **stop**. Do not diagnose it, and do not fall back on your own:

> GitHub MCP is unavailable — <the error, verbatim>. `ToolSearch` finding nothing for every query means no GitHub MCP server is connected; one that resolves but errors is usually a stale auth token, and refreshing it is the fastest fix. If you would rather open this PR with the `gh` CLI, say so and I will use it.

Then wait. `gh` is used **only** on explicit approval in this session, and approval does not carry to a later run. If `gh` is missing or unauthenticated, say so in one line, name `gh auth login`, and stop.

## Branch and Changeset

1. `git branch --show-current`. If HEAD is detached, stop and say so. If the tree has uncommitted changes, say what they are — they will not be in the PR — and ask whether to proceed or commit first.
2. Resolve the base branch, then `git fetch origin <base>` and `git merge-base HEAD origin/<base>`.
3. `git log --oneline <merge-base>..HEAD` and `git diff <merge-base>...HEAD`. With no commits ahead of the base, stop — there is nothing to open a PR for.
4. Check whether a PR is already open for this branch. If one is, do not create a second: offer to update its description, title, and options instead.

## Understand the Change

Read `CLAUDE.md` (and what it imports), `README.md`, and any roadmap file **before** the diff — that ordering is what lets the description say how the change fits the project instead of restating the diff.

Then read the changed files for surrounding context and cluster the changes into the conceptual groups a reviewer would form. Past ~50 files, cover the significant groups and give the mechanical ones a line.

## Changelog and Version

Infer from what exists (`CHANGELOG.md`, `.changeset/`, `changelog.d/`; the version in `pyproject.toml`, `package.json`, `Cargo.toml`) and what comparable merges touched whether this branch owes an entry or a bump. Where release tooling — release-please, changesets, towncrier — generates them, nothing is owed.

If one is owed and missing, name it and offer to add it in the existing format before opening the PR. Never edit those files silently. Nothing to infer from, nothing to say.

## Write the Description

A reviewer reads this once, before the diff, to learn what the branch does and why. Everything past that has to earn its space.

Lead with a one-sentence headline of what the PR accomplishes — what it makes possible, not the title reworded — then the why: the goal it serves, not the local trigger. Add more only where a reviewer would otherwise have to reconstruct it from the diff:

- **What changed**, grouped by concept, when the branch spans more than one group and the headline cannot carry it.
- **A decision** a reviewer would otherwise reverse-engineer: the choice and the goal it serves. Not the alternatives considered or the paths abandoned.
- **How to review** — reading order, what deserves scrutiny, what can be skimmed — on a branch big enough to get lost in. Not a test plan; CI is the correctness gate.

Use `##` headings only once there are several of these to separate. A few paragraphs need none.

- **Length tracks the change.** A one-concept branch is a headline and two or three sentences. Padding to fill out a shape is the failure to avoid.
- **Lead with intent, and never enumerate changed files.** The diff has the mechanics.
- Prose and register follow `.claude/rules/general-rules.md`.
- Link tickets and issues inline, where the prose refers to them.

## Confirm, Then Open

Show the full description, the title, the base branch, and every option — draft status, labels, reviewers, assignees — as they will be submitted. **Opening a PR notifies people and starts CI, so it happens only on an unambiguous yes.**

On approval:

1. `git push -u origin <branch>` if the branch has no upstream or has unpushed commits.
2. Create the PR through the MCP tools with the title, body, base, and draft flag.
3. Apply labels, reviewers, and assignees. A label that does not exist, or a reviewer without access, will be rejected — report which one and leave the PR open without it rather than failing the whole operation.
4. Report the PR URL and number.

If creation fails, print the full description in a code block so the work is not lost, and report the error verbatim.

Never merge the PR, never force-push, and never push to the base branch.
