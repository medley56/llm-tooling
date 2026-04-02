---
name: commit-message
description: >
  Generates a plain-text commit message for currently staged changes. Use when
  the user asks to "write a commit message", "generate a commit message",
  "draft a commit message", "summarize my staged changes", or "what should my
  commit message be". Do NOT use when the user asks to actually make a commit,
  amend a commit, or generate a PR description.
metadata:
  author: llm-tooling
  version: 1.0.0
---

# Commit Message Generator

Generate a plain-text commit message describing the currently staged changes.

## Instructions

### Step 1: Gather Staged Changes

Run `git diff --cached` to obtain the full diff of staged changes.

If there are no staged changes, tell the user there is nothing staged and stop.

### Step 2: Check for Unstaged Changes

Run `git diff --name-only` to list files with unstaged modifications. Run
`git ls-files --others --exclude-standard` to list untracked files.

If either command returns results, notify the user before presenting the commit
message:

> Note: The following files have unstaged changes and are NOT included in this
> commit message:
>
> - path/to/file1
> - path/to/file2

### Step 3: Analyze the Diff

Read the staged diff carefully. Identify:

- Which files were added, modified, or deleted
- The nature of each change (new feature, bug fix, refactor, config change,
  documentation, test, dependency update, etc.)
- Concrete details: function names, config keys, error messages, endpoints

Do NOT speculate about intent or motivation. Describe only what the diff shows.

### Step 4: Write the Commit Message

Compose a commit message following these formatting rules exactly:

**Title line:**
- Maximum 50 characters
- Imperative mood ("Add", "Fix", "Remove", "Update", not "Added", "Fixes")
- No trailing period
- Capitalize the first word
- Summarize the overall change in one phrase

**Blank line** separating title from body.

**Body:**
- Wrap every line at 72 characters
- Use a bulleted list (`- `) of specific changes, one per line
- Each bullet describes one concrete change (file, function, or behavior)
- Keep bullets factual and concise — what changed, not why
- Order bullets by importance or logical grouping
- Omit trivial changes (whitespace, import reordering) unless they are the
  only changes
- For large diffs (more than 20 files), group related changes under
  sub-headings using blank lines between groups, but keep the single
  title line

**Example output:**

```
Add user authentication endpoints

- Add POST /auth/login and POST /auth/register routes
- Add JWT token generation and validation in auth/tokens.py
- Add password hashing with bcrypt in auth/passwords.py
- Add auth middleware to verify tokens on protected routes
- Add user model with email and hashed_password fields
```

### Step 5: Present the Message

Display the commit message inside a plain-text fenced code block so the user
can copy it directly. Use a plain code fence with no language tag.

After the code block, state: "This message was not committed. You can copy it
and run `git commit -m '...'` or `git commit` with an editor."

## Rules

- NEVER run `git commit`. This skill only generates the message text.
- NEVER use markdown formatting (bold, headers, links) inside the commit
  message itself. The message must be plain text.
- NEVER describe why a change was made. Describe only what changed.
- NEVER include file diffs or patch content in the output.
