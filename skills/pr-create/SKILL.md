---
name: pr-create
description: >
  Writes a reviewer-focused description for the current branch and opens the
  pull request on GitHub. Invoked as /llm-tooling:pr-create, or when the user asks to "open
  a PR", "put up a PR", "create a pull request", or "write a PR description".
  Opens a draft by default, for a self-review with pr-review before colleagues
  are asked. Accepts draft status, title, base branch, labels, reviewers, and
  assignees. Uses the GitHub MCP server; falls back to the gh CLI only with the
  user's explicit approval.
metadata:
  author: llm-tooling
  version: 3.1.0
---

# Open a Pull Request

Describe what this branch does, then open the PR. The description is written for a reviewer who knows the project but not this change.

## Options

Take these from the user's request when present; otherwise use the default:

| Option | Default |
|---|---|
| Draft | Draft, unless the user asks for it ready for review |
| Title | Derived from the change; a single-commit branch may use its subject |
| Base branch | The repo's default branch |
| Assignees | The PR author — the login `get_me` returns |
| Labels, reviewers | None |

What the user or a calling skill supplies wins over what you infer, including their framing of *why* the change exists. Supplement it from the code; do not second-guess it.

## GitHub Access

Resolve the MCP tools with `ToolSearch` keyword searches (`get me`, plus `create pull request`) before any other work. Search by what the tool does, not a server prefix: the server can be registered under any name. Names vary by server version. You will need tools to create a PR, update one, and set labels and reviewers.

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

**Find the why before writing.** The diff cannot supply it. Take it from what the user or caller gave you, the linked ticket (the branch name and commit messages usually name it), and the commit messages. Where the problem, what it cost, or the goal is still unknown, ask the author before drafting: a why reconstructed from the diff only restates the what.

## Changelog and Version

Infer from what exists (`CHANGELOG.md`, `.changeset/`, `changelog.d/`; the version in `pyproject.toml`, `package.json`, `Cargo.toml`) and what comparable merges touched whether this branch owes an entry or a bump. Where release tooling — release-please, changesets, towncrier — generates them, nothing is owed.

If one is owed and missing, name it and offer to add it in the existing format before opening the PR. Never edit those files silently. Nothing to infer from, nothing to say.

## Write the Description

Write for a colleague who knows the project and will read the diff next. A reviewer can judge whether a change achieves its goal only if they know the goal, and the diff cannot tell them. A change can pass every test and still miss the point; the description is what lets a reviewer catch that.

**Lead with why:**

- **The problem as it stood**: what was broken, missing, or undefined, and what it cost. A decision nobody had made counts — name it as open, then give the answer.
- **How bad each problem was**, by impact, not by how it was found. Where a defect survived because it is expensive to test, say so, and name the test that now guards it.
- **The goal**: what is true once this merges, stated so a reviewer can check the diff against it.

**Then what changed, tied back to the why.** For each goal, how the change meets it, and the reasoning behind any approach a reviewer might question. Mechanics the diff shows plainly need no words.

**Incidental changes** go in their own section after that: broken windows fixed along the way, such as a latent bug, a refactor that made the goal easier to reach, or cleanup at the edges of the work. Give each a line on what it fixes and, where it is not obvious, why it rode along. A serious latent bug is still called serious here.

Wherever they apply, also say:

- **Behavior changes that reach other services or callers**, such as an event now emitted again.
- **Known limits, and prerequisites not yet verified** for deploying or using the change.
- **A small change that widens what can be committed, deployed, or exposed** (`.gitignore`, permissions, public endpoints): flag it with its reason, or ask the author for one. Never list it as a neutral one-liner.

Check every number the description states ("two defects") against what it counts.

Write it to be read:

- Size it to what a reviewer needs to judge the goal, not to the diff. Cut mechanics before motivation; a small fix to a serious problem still gets its why.
- Write the why as prose, so the "because" and "so" survive. Use lists for parallel items in the what.
- Name headings for goals and problems, not files or components, so each section reads as the answer to a why.
- Describe things plainly and candidly, in the words you would use with a teammate at their desk. Say how bad a problem was.
- Argue why the goal matters; do not argue that the change is good. The reviewer judges that against the goal.
- Leave pass/fail to CI and line counts to the diff, but say what was not verified and which test guards the goal.
- Link tickets and issues inline, where the prose refers to them.

Before showing it, reread only the why. If a reviewer could not judge the diff from it alone, or it restates the what, rewrite it.

## Confirm, Then Open

Show the full description, the title, the base branch, and every option — draft status, labels, reviewers, assignees — as they will be submitted. **Opening a PR notifies people and starts CI, so it happens only on an unambiguous yes.**

Every time, with that summary, remind the author to review their own diff before any colleague does.

On approval:

1. `git push -u origin <branch>` if the branch has no upstream or has unpushed commits.
2. Create the PR through the MCP tools with the title, body, base, and draft flag.
3. Apply labels, reviewers (only if explicitly requested), and assignees. A label that does not exist, or a reviewer without access, will be rejected — report which one and leave the PR open without it rather than failing the whole operation.
4. Report the PR URL and number.

On a draft, close with the self-review step, so the last round of AI-assisted review is on GitHub for colleagues to see: run `/llm-tooling:pr-review` on this PR and have it post its comments, review the draft yourself on GitHub, answer and fix all of it with `/llm-tooling:pr-fix`, then mark the PR ready for review.

If creation fails, print the full description in a code block so the work is not lost, and report the error verbatim.

Never merge the PR, never force-push, and never push to the base branch.
