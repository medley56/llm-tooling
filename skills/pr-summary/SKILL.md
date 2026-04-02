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

### Step 4: Analyze Changes

Read the diff and changed files to build an understanding of the changes:

1. **Read changed files** — for each file in the diff, use the Read tool to examine surrounding context. For large files (>500 lines), read only the changed regions with +-50 lines of context.
2. **Categorize the change** — determine the nature of the work: new feature, bug fix, refactor, performance improvement, documentation, configuration, test coverage, etc.
3. **Identify logical groupings** — cluster related changes across files into coherent units of work. Think about how a reviewer would naturally group these changes in their head.
4. **Note key decisions** — identify any non-obvious architectural choices, trade-offs, or patterns that a reviewer would benefit from understanding upfront.
5. **Determine review focus areas** — based on the complexity and risk profile of each change group, suggest where reviewers should spend the most attention.

### Step 5: Generate PR Summary

Compose the PR summary using the analysis from Step 4 and any user-provided context from Step 1. Follow this structure:

```markdown
# PR: <title>

<One-sentence summary of what this PR accomplishes.>

## Why

<1-3 sentences explaining the motivation. What problem does this solve? What need does it address? Draw from user-provided context, PR description, commit messages, and the code itself.>

## What Changed

### <Logical group 1>

<Brief description of this group of related changes. Mention key files and what was done to them, but stay at the level of intent — what the change accomplishes, not a line-by-line walkthrough.>

### <Logical group 2>

<...repeat for each logical group...>

## Key Decisions

<Include this section only if there are non-obvious choices worth calling out. Use a bulleted list. Each item should state the decision and briefly explain the rationale. Omit this section entirely if there are no notable decisions.>

## How to Review

<Suggest a review strategy. This might include: recommended file reading order, areas that deserve close scrutiny, areas that are mechanical/low-risk, dependencies between change groups, or anything else that makes the review more efficient.>

## Changed Files

<Paste the `git diff --stat` output here, inside a code block.>
```

Guidelines for writing the summary:

- **Lead with intent, not mechanics.** Describe what the changes accomplish, not what functions were edited.
- **Group by concept, not by file.** Related changes across multiple files belong together.
- **Be concise.** Each section should be as short as possible while still being useful. Aim for a summary a reviewer can scan in under 2 minutes.
- **Use plain language.** Avoid jargon unless it is domain-specific terminology the team uses.
- **Link to context.** If there are relevant issue numbers, ticket IDs, or documentation links (from user input or PR metadata), include them naturally in the text.
- **Omit sections that add no value.** If there are no key decisions to call out, drop that section. Do not include empty sections or placeholder text.

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
- **Group by concept, not by file.** Organize the "What Changed" section around logical units of work. A single group may span multiple files; a single file may appear in multiple groups.
- **Respect the user's context.** If the user explains the motivation, use it. Do not contradict or second-guess their framing. You may supplement it with details from the code.
- **Stay concise.** Verbosity is the enemy of reviewer efficiency. Every sentence should earn its place. If a section can be one sentence, do not make it three.
- **Handle large diffs pragmatically.** If the branch has more than 50 changed files, focus the "What Changed" section on the most significant changes and note that minor or mechanical changes were summarized briefly. Do not attempt to describe every file individually.
- **Always write the output file.** Even for a single-commit branch with one changed file, write the summary file. The file is the deliverable.
