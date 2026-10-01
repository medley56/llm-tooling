---
name: ticket-refine
description: >
  Audits a draft ticket against the code and systems it will touch before it is
  assigned, so its scope holds up when a developer starts: confirms the goal,
  sends read-only investigators across every repo, doc, and ticket likely to
  be involved, trims the extra scope they claim down to what the goal cannot be
  met without, and recommends what to change in the ticket and what, if
  anything, belongs in a separate one. Reads the ticket from Jira, GitHub, Notion,
  a markdown file, or the prompt. Invoked as /llm-tooling:ticket-refine, or when
  the user asks to "refine this ticket", "review this ticket", "is this ticket
  ready", "audit the scope of this ticket", "groom this ticket", or "what is
  this ticket missing".
metadata:
  author: llm-tooling
  version: 1.0.0
---

# Ticket Refine

Find out what a draft ticket understates — wrong claims, missing requirements, knock-on work in this repo and others — before a developer finds it mid-implementation. Then cut that list hard: the output is the few changes that keep the ticket honest, not every problem the investigation saw.

Steps 1–5 run in order. After that the user drives.

## 1. The Ticket

Read the ticket from where the user points:

- **Jira** — an issue key or URL. Search `jira get issue`. Read the description, acceptance criteria, comments, and linked issues.
- **GitHub** — search `github issue read`.
- **Notion** — search `notion page`.
- **A markdown file**, or text in the prompt.

Find remote tools with a `ToolSearch` keyword search for what the tool does, never a server prefix. If the server cannot be resolved or reached, stop and say which, with the error verbatim; offer to work from pasted text. Follow a link one level deep when the ticket leans on it.

## 2. Confirm the Goal — Gate

Invoke the built-in **Explore** agent with `model: "sonnet"` and `run_in_background: false` on the repo most relevant to the ticket, with the ticket text. Ask it what the code in that area does today and what problem the ticket solves there — not how to solve it.

Restate the goal to the user as the motivation, never the implementation: "We need X because Y." One sentence for a simple goal, two or three usually, five at most. Where the ticket gives no why, say so — that is the first hole.

In the same message, name in one line the repos and sources step 3 will investigate, so the user can add or strike one. Then **wait**: nothing fans out until the user confirms the goal. A corrected goal replaces the ticket's framing for every later step.

## 3. Investigate

The goal of this phase is to find what the ticket is missing or gets wrong that will change the scope of implementation: context it lacks, claims about the code that are false, knock-on work it does not mention. Investigators go as deep into implementation detail as that takes — which call sites break, which schema field moves, which consumer pins what. That detail is evidence, not output: step 4 distills it back to ticket requirements.

Decide which repos, docs, tickets, and web pages the implementation is likely to touch: those the ticket names, those the step 2 agent found coupled to the area (imports, shared schemas, API consumers, dependency pins), and any the user added. Prefer a local checkout — look beside the current repo — and fall back on remote reads and MCP tools.

Send **ticket-scope-investigator** agents, all in one message, each with `run_in_background: false`: at most **5 with `model: "sonnet"`** and **10 with `model: "haiku"`**. Sonnet takes assignments that need judgment — the repo where the change lands, a cross-repo contract; Haiku takes narrow lookups — who consumes this endpoint, what version does this repo pin. Put two investigators on a part of the scope that is complex or that the ticket is vaguest about. Give each the ticket text, the confirmed goal, its assignment, and the specific question for it.

Note an investigator that fails and continue with the rest.

Then read the reports for what is still open: conflicting answers, an `unverifiable` claim, a coupling nobody traced to its end, an item in **Unresolved**. Loop until none bears on the goal. Prefer continuing the investigator that already holds the context — `SendMessage` to it, with the specific question — over starting a fresh one; send a new one, within the caps, only for ground no investigator has covered. The caps count agents, not rounds.

## 4. Trim

Merge the investigators' undocumented ticket scope and wrong-claim findings into one list, one entry per distinct item however many agents reported it. Drop anything plainly unrelated to the goal before going further.

Send **ticket-scope-trimmer** agents on the rest — at most 5, `model: "sonnet"`, all in one message with `run_in_background: false`, related items grouped onto one agent. Give each the ticket text, the confirmed goal, and its items with the investigators' evidence. Each item comes back `REQUIRED`, `DEFER`, or `DROP`.

Where a trimmer's verdict contradicts strong investigator evidence, read the code and decide.

What survives is stated as a requirement — what must be true when the ticket is done — not as the implementation steps the investigators traced. "Existing exports keep loading" is a ticket requirement; "add a fallback in `load_export()`" is the developer's call.

## 5. Recommend

Keep everything centered on the confirmed goal. Show:

```
**Goal:** <as confirmed>
**Ticket:** ready | needs changes | materially larger than it reads

### Changes to This Ticket
- <add | correct | clarify> <what> — why the goal needs it — <evidence>

### Separate Tickets
1. <title> — <goal, 1–3 sentences>

### Set Aside
<N> findings not needed for the goal — ask to see them.
```

- **Changes to This Ticket** carries the `REQUIRED` items, the wrong claims the ticket must correct, the holes an implementer would otherwise have to decide, and the scope that will be forced on the implementer anyway. Most important first.
- **Separate Tickets** is optional and usually empty: only a `DEFER` item someone will actually need to do. **Never more than 5**, and no full drafts — high level goals only.
- Everything else is **Set Aside**: counted, not listed, and plans no fix.

End with the one ask: which changes to take into the redraft.

## 6. Iterate

The user drives from here: questions about any finding, including set-aside ones; pushback on a verdict; a request to check something further, which goes to the investigator or trimmer that already holds the context, as in step 3. When asked, redraft the ticket, and any separate ticket the user wants, showing the full text.

## 7. Persist — Only on Request

The user decides whether the redraft goes anywhere. On request, write it to a markdown file, or update the ticket or create the separate ones in Jira (search `jira update issue`, `jira create issue`) or GitHub (search `github issue write`).

**Before any write to a ticketing system, show the exact final text and get an explicit yes.** Report the ticket key or URL after. A GitHub issue never links an internal Jira issue or Confluence page. If the write fails, report the error verbatim and do not retry.

## Rules

- **The confirmed goal is the boundary.** A problem the goal does not need is not a finding, however real it is.
- **Never invent a requirement.** A gap goes to the user as a hole or a question, not into the redraft as a decision.
