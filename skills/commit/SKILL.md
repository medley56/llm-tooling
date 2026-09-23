---
name: commit
description: >
  Decides what in the working tree belongs in a commit, writes a Conventional
  Commits message, and creates the commit locally. Invoked as /llm-tooling:commit, or when
  the user asks to "commit this", "commit my changes", or "write a commit
  message". Excludes review and planning artifacts, and asks when the right
  contents are unclear. Never pushes.
metadata:
  author: llm-tooling
  version: 5.2.1
---

# Commit

Decide what belongs in the commit, write the message, commit. Invoking this skill is the authorization to commit — do not ask again unless a rule below says to.

## What Goes In

Survey the whole tree: `git status -sb`, `git diff`, `git diff --cached`, `git ls-files --others --exclude-standard`. Staging is a signal about intent, not the definition of the commit. If the tree is clean, say so and stop.

**Start from what this session did.** The files you created or edited for the user's request are the commit; anything else is a question. With no session context, describe the groupings the tree suggests and let the user pick.

Never commit, even when staged:

- Review and planning artifacts — `pr-*-review.md`, fix plans, scratch notes.
- Credentials and private configuration — `.env`, keys, tokens.
- Build output, caches, editor and OS files.

Say which paths you excluded and why.

Ask when the answer is not obvious: unrelated units of work in one tree, a file that could be artifact or deliverable, a staged subset that overlaps unstaged edits to the same files.

Stage by naming paths — never `git add -A`, `git add .`, or a bare `git add -u`. A deletion stages with `git add <deleted-path>`, or `git rm <path>` if the file is still on disk; a rename stages as both paths. Check `git diff --cached --stat` against your list before writing the message.

## Obvious Breakage

Commit what you believe works, without auditing: no test runs, no reading files this session never touched. One `grep` for a name you renamed or deleted is in scope; a wider review is not.

Stop before committing if you already know the commit breaks something — a reference you saw go stale, a caller you noticed. Name what breaks and where, then let the user fix it first, approve the breakage, or split the commit. **Committing known breakage takes explicit approval**; silence or an ambiguous answer means no. A suspicion is not enough to hold a commit — mention it and commit.

## When Not to Commit

Draft the message and hand it over instead of committing when the repo's context restricts commits, when a merge, rebase, cherry-pick, or bisect is in progress, or when HEAD is detached. Say which condition applies and what they can run themselves. On the default branch, ask first and offer to branch — unless the user has said this repo commits to its default branch, in which case commit and say you did.

## Message

Conventional Commits:

```
<type>(<optional scope>): <description>

- <what changed>
```

Type by effect, not by directory — `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`; a docstring-only edit under `src/` is `docs`. Scope only when it clarifies. Description imperative and lowercase, no trailing period, title under 72 characters. A breaking change takes `!` before the colon and a `BREAKING CHANGE:` footer.

Body bullets wrap at 72 characters, one concrete change each, most significant first. Skip whitespace and import churn. A small change needs no body.

Describe what the diff shows. Give a reason only when the user gave you one this session; never reconstruct intent from the code.

## Commit

Show the message, then:

```bash
git commit -F - <<'MSG'
<message>
MSG
```

Use `-F`, never `-m` — `-m` mangles multi-line bodies and breaks on quotes and backticks.

Report the short SHA and branch. **Never push**, and never amend unless asked for an amend by name.

If the commit fails, the run ends there. Report what happened, leave the message on screen, and tell the user to re-run `/llm-tooling:commit` once they have looked at the state. Never retry with `--no-verify` — the hook is the repo objecting. If a hook reformatted files, show what it rewrote.
