---
name: pr-summary
description: >
  Generates a concise, reviewer-focused PR summary for the current branch.
  Use when the user asks to "summarize this PR", "write a PR summary",
  "generate a PR description", "create a review summary for this branch",
  or similar requests. Accepts optional context about the motivation or
  focus areas for the changes. Outputs a markdown file at the repo root.
metadata:
  author: llm-tooling
  version: 1.0.0
---

# PR Summary Generator

Generate a concise, markdown-formatted PR summary designed to help code reviewers quickly contextualize the changes on the current branch.

## Instructions

The user may optionally provide context about the changes — motivation, ticket references, areas of concern, or anything else that helps explain the "why" behind the work. If no context is provided, infer it from the commit messages and diff.

### Step 1: Parse User Input

Extract any context the user provides:

- **Motivation** — why this change is being made (bug report, feature request, tech debt, etc.)
- **Ticket or issue references** — links or identifiers for related issues
- **Areas of concern** — specific parts of the change the author wants reviewers to focus on
- **Anything else** — additional background that would help a reviewer

All of these are optional. If the user provides nothing beyond "generate a PR summary", proceed with git-derived context only.

### Step 2: Discover GitHub Tools

Check for available GitHub tools to enrich the summary with PR metadata. Try sources in this priority order:

1. **GitHub MCP server** — use `ToolSearch` to search for MCP tools matching keywords like "github pull request". Look for tools such as `mcp__github__get_pull_request`, `mcp__github__list_pull_request_files`, or similar.
2. **VSCode GitHub extension** — use `ToolSearch` to look for tools with names containing `mcp__vscode__` related to GitHub pull requests.
3. **`gh` CLI** — verify `gh` CLI is installed and authenticated by running `gh auth status` via Bash.
4. **No tools available** — this is fine. Proceed in git-only mode. PR metadata enrichment (title, labels, linked issues) will be skipped.

Record which tool source is available, if any. Prefer MCP > VSCode > `gh` CLI.

### Step 3: Determine Branch and Diff

#### 3a: Get the current branch

Run `git branch --show-current` to get the current branch name. If in detached HEAD state, exit with:

> Cannot generate PR summary: HEAD is detached. Please check out a branch first.

#### 3b: Identify the base branch

Determine the base branch using these sources in priority order:

1. **PR metadata** — if GitHub tools are available (Step 2), search for an open PR from the current branch and use its base branch.
2. **Default branch** — run `git remote show origin` and parse the default branch, or fall back to `main` then `master`.

#### 3c: Fetch and compute the diff

1. Run `git fetch origin <base_branch>` to ensure the remote tracking ref is current.
2. Run `git merge-base HEAD origin/<base_branch>` to find the common ancestor.
3. Run these commands to gather the changeset:
   - `git diff <merge-base>...HEAD` — the full diff
   - `git diff --stat <merge-base>...HEAD` — file change summary
   - `git log --oneline <merge-base>...HEAD` — commit history on this branch

### Step 4: Gather Context and Analyze Changes

Build an understanding of both the changes and the larger system they live in. The goal is to be able to explain how this PR fits into the project, not just what lines moved.

1. **Read repo-level context first** — before diving into the diff, scan repository-level documentation that frames the codebase:
   - `CLAUDE.md` and any files it `@`-includes (commonly `.github/instructions/*.md`, `.github/copilot-instructions.md`, or `AGENTS.md`)
   - `README.md` at the repo root
   - Any `ROADMAP.md` or roadmap-style instruction files referenced from the above
   Use these to understand the project's purpose, architecture, ongoing roadmap items, and conventions. This is what lets you write a "Why" section that situates the change instead of merely describing it.
2. **Read changed files** — for each file in the diff, use the Read tool to examine surrounding context. For large files (>500 lines), read only the changed regions with +-50 lines of context.
3. **Categorize the change** — determine the nature of the work: new feature, bug fix, refactor, performance improvement, documentation, configuration, test coverage, etc.
4. **Identify logical groupings** — cluster related changes across files into coherent units of work. Think about how a reviewer would naturally group these changes in their head.
5. **Identify goal-aligned decisions** — note the *final* choices that shape the change, framed in terms of the goal each one serves. Do not capture the decision tree — alternatives considered, paths abandoned, intermediate refactors. Only record the resulting choice and the user-facing or system-level goal it advances. Skip anything that is the obvious implementation of the stated goal.
6. **Determine review focus areas** — based on the complexity and risk profile of each change group, suggest where reviewers should spend the most attention.

### Step 5: Generate PR Summary

Compose the PR summary using the analysis from Step 4 and any user-provided context from Step 1. Use this structure:

```markdown
# PR: <title>

<One-sentence headline of what this PR accomplishes.>

## Why

<2-5 sentences situating the change within the project. Draw on repo-level documentation (CLAUDE.md, README, roadmap/instruction files) to explain how this PR fits the system's goals or architecture — not just the local trigger. A reviewer who already knows the project but not this PR should finish this section understanding why the change matters, not merely what prompted it.>

## What Changed

### <Logical group 1>

<Concept-level description of this group of related changes. Describe what the change *accomplishes*, not which files were edited or which lines moved. Reviewers see the file list in the diff. Skip mechanical or obvious work.>

### <Logical group 2>

<...repeat for each logical group...>

## Key Decisions (optional)

<Include only when the PR makes a non-obvious *final* choice whose rationale a reviewer would otherwise have to guess at. State the chosen approach and the goal it serves, in one or two sentences each. Do not recap alternatives weighed or paths abandoned — only the resulting decision and what goal it advances. Omit this section entirely if everything in the diff is the obvious implementation of the stated motivation.>

## How to Review

<Suggest a review strategy: recommended reading order, areas that deserve close scrutiny, mechanical/low-risk areas that can be skimmed, dependencies between change groups. Do NOT include a test plan or task checklist — automated unit and integration tests are the canonical correctness gate, and reviewers will run them as part of CI.>

## Suggested Manual Verification (optional)

<Include only when the change has behavior that automated tests don't easily cover — UI changes, deploy-time behavior, external integration touch points, etc. Frame each item as a suggestion ("you may want to check…", "consider verifying…"), never as a required checklist. Omit this section entirely if the automated test suite already covers the change.>
```

Guidelines for writing the summary:

- **Lead with intent, not mechanics.** Describe what the changes accomplish, not which functions were edited. The diff already shows the mechanics.
- **Contextualize, don't just describe.** Use repo-level documentation to ground the "Why" section. A reader should see how the PR fits the project — its roadmap, architecture, or current goals — not just the immediate trigger.
- **Group by concept, not by file.** Related changes across multiple files belong together. A single file may appear in multiple conceptual groups.
- **Don't enumerate changed files.** Reviewers see the file list in the diff. The "What Changed" section should describe intent and impact, not which files moved.
- **Final decisions only.** In "Key Decisions", state the chosen approach and the goal it serves. Never narrate the decision tree, alternatives considered, or paths abandoned — that is noise for a reviewer.
- **No test plans, no checklists.** Unit and integration tests are the source of truth for correctness. If a behavior genuinely benefits from a human spot-check, put it under "Suggested Manual Verification" and phrase items as suggestions, not requirements. "How to Review" is for reading strategy, not for things-to-test.
- **Be concise.** Each section should be as short as possible while still useful. Aim for a summary a reviewer can scan in under 2 minutes.
- **Use plain language.** Avoid jargon unless it is domain-specific terminology the team already uses.
- **Link to context.** If there are relevant issue numbers, ticket IDs, or documentation links (from user input or PR metadata), include them naturally in the prose.
- **Omit optional sections that add no value.** Drop "Key Decisions" and/or "Suggested Manual Verification" entirely if you have nothing notable to flag in them. Do not include empty sections or placeholder text.

### Step 6: Write Output File

#### 6a: Compute the filename

Take the current branch name and truncate it to at most 32 characters. Construct the filename as `PR-<truncated-branch>.md`.

Examples:
- Branch `fix/login-redirect` -> `PR-fix-login-redirect.md`
- Branch `feature/add-user-authentication-flow-v2` -> `PR-feature-add-user-authenticati.md`

Replace any characters that are not alphanumeric, hyphens, or dots with hyphens. Collapse consecutive hyphens into one.

#### 6b: Write the file

Write the generated PR summary to the repository root using the Write tool.

#### 6c: Report to the user

Tell the user:
- The output file path
- A one-line summary of the PR (e.g., "PR summary for branch `feature/foo` written to `PR-feature-foo.md`")
- If any sections were omitted and why (e.g., "Omitted Key Decisions section — no non-obvious trade-offs identified")

## Important Behavioral Rules

- **You are a summarizer, not a reviewer.** Do not critique the code, flag bugs, or suggest improvements. Your job is to help reviewers understand what changed and why — not to judge whether the changes are correct.
- **Contextualize within the larger system.** Read repo-level documentation (CLAUDE.md, README, roadmap/instruction files) before writing the summary. The "Why" should help a reviewer who knows the project understand the PR's place in the architecture or roadmap, not just its local effect.
- **Group by concept, not by file.** Organize the "What Changed" section around logical units of work. A single group may span multiple files; a single file may appear in multiple groups.
- **Do not enumerate changed files.** The diff itself is the file list. Listing files line-by-line wastes reviewer time and obscures intent.
- **Final decisions only, not the decision tree.** In "Key Decisions", describe the chosen approach and the goal it serves. Never narrate alternatives weighed or paths abandoned. Omit the section if everything is the obvious implementation of the stated motivation.
- **Never include a test plan or task checklist.** Unit and integration tests are the canonical correctness gate. If a behavior genuinely needs a human spot-check, use "Suggested Manual Verification" and phrase items as suggestions, not requirements. "How to Review" is for reading strategy, not for things-to-test.
- **Respect the user's context.** If the user explains the motivation, use it. Do not contradict or second-guess their framing. You may supplement it with details from the code.
- **Stay concise.** Verbosity is the enemy of reviewer efficiency. Every sentence should earn its place. If a section can be one sentence, do not make it three.
- **Handle large diffs pragmatically.** If the branch has more than 50 changed files, focus the "What Changed" section on the most significant changes and note that minor or mechanical changes were summarized briefly. Do not attempt to describe every file individually.
- **Always write the output file.** Even for a single-commit branch with one changed file, write the summary file. The file is the deliverable.
