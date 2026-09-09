---
name: pr-create
description: >
  Writes a reviewer-focused description for the current branch and opens the
  pull request on GitHub. Invoked as /pr-create, or when the user asks to "open
  a PR", "put up a PR", "create a pull request", or "write a PR description".
  Accepts draft status, title, base branch, labels, reviewers, and assignees.
  Uses the GitHub MCP server; falls back to the gh CLI only with the user's
  explicit approval.
metadata:
  author: llm-tooling
  version: 2.0.1
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
| Motivation, tickets, focus areas | Inferred from commits and diff |

Anything the user supplies wins over what you infer, including their framing of *why* the change exists. Supplement it with detail from the code; do not second-guess it.

## GitHub Access

Resolve the MCP tools with `ToolSearch` (`select:mcp__github-mcp__get_me`, plus a keyword search like `github create pull request`) before any other work. Names vary by server version. You will need tools to create a PR, update one, and set labels and reviewers.

If MCP cannot be reached or authenticated, **stop**. Do not diagnose it, and do not fall back on your own:

> GitHub MCP is unavailable — <the error, verbatim>. This is usually a stale MCP auth token; refreshing it is the fastest fix. If you would rather open this PR with the `gh` CLI, say so and I will use it.

Then wait. `gh` is used **only** on explicit approval in this session, and approval does not carry to a later run. If `gh` is missing or unauthenticated, say so in one line, name `gh auth login`, and stop.

## Branch and Changeset

1. `git branch --show-current`. If HEAD is detached, stop and say so. If the tree has uncommitted changes, say what they are — they will not be in the PR — and ask whether to proceed or commit first.
2. Resolve the base branch, then `git fetch origin <base>` and `git merge-base HEAD origin/<base>`.
3. `git log --oneline <merge-base>..HEAD` and `git diff <merge-base>...HEAD`. With no commits ahead of the base, stop — there is nothing to open a PR for.
4. Check whether a PR is already open for this branch. If one is, do not create a second: offer to update its description, title, and options instead.

## Understand the Change

Read `CLAUDE.md` (and what it imports), `README.md`, and any roadmap file **before** the diff. That is what lets the description say how the change fits the project rather than restating the diff.

Then read the changed files for surrounding context and cluster the changes into the conceptual groups a reviewer would form. On a branch touching more than 50 files, cover the significant groups and summarize the mechanical ones in a line.

## Write the Description

```markdown
<One-sentence headline of what this PR accomplishes.>

## Why

<2-5 sentences placing the change in the project — the goal or roadmap item it serves, not just the local trigger.>

## What Changed

### <Conceptual group>

<What this group accomplishes. Not which files were edited.>

## Key Decisions

<Only for a non-obvious final choice a reviewer would otherwise have to reverse-engineer: the decision and the goal it serves, a sentence or two. Never the alternatives considered or paths abandoned. Omit the section when the diff is the obvious implementation of the stated motivation.>

## How to Review

<Reading order, what deserves scrutiny, what can be skimmed. Not a test plan and not a checklist — CI is the correctness gate.>
```

- **Lead with intent.** The diff already shows the mechanics.
- **Group by concept, not by file,** and never enumerate changed files.
- **Describe, do not review.** No critiques, no bug reports, no suggested improvements.
- **Scannable in under two minutes.** Drop any section you have nothing real to put in.
- Link tickets and issues in prose where they belong.

## Confirm, Then Open

Show the full description, the title, the base branch, and every option — draft status, labels, reviewers, assignees — as they will be submitted. **Opening a PR notifies people and starts CI, so it happens only on an unambiguous yes.**

On approval:

1. `git push -u origin <branch>` if the branch has no upstream or has unpushed commits.
2. Create the PR through the MCP tools with the title, body, base, and draft flag.
3. Apply labels, reviewers, and assignees. A label that does not exist, or a reviewer without access, will be rejected — report which one and leave the PR open without it rather than failing the whole operation.
4. Report the PR URL and number.

If creation fails, print the full description in a code block so the work is not lost, and report the error verbatim.

Never merge the PR, never force-push, and never push to the base branch.
