# Gauntlet Loop Prompt Template

Fill every `{{PLACEHOLDER}}`. Delete any section marked *optional* that does not apply.
Do not soften or trim the "How to Run This Loop" section — those instructions are the method.

---

```markdown
I want to run a Gauntlet Loop for this goal.

## Goal

{{GOAL_PARAGRAPH}}

<!-- One paragraph, in the terms of whoever uses the result. No mechanism words.
     Describe the destination; the route is yours to choose. -->

## Context

**Project type:** {{GREENFIELD_OR_EXISTING}}

{{CONTEXT_BODY}}

<!-- Greenfield: target platform/runtime, deployment target, anything already scaffolded,
     stated technology preferences.
     Existing codebase: where the relevant code lives, what it currently does, the
     conventions to follow (point at CLAUDE.md / AGENTS.md / README), and the subsystems
     this touches. -->

**Build, run, and test:**

{{BUILD_RUN_TEST_COMMANDS}}

<!-- The critic must be able to produce and observe real output. If it cannot run the
     thing, it cannot judge it. List the exact commands. -->

## The Bar

This is the standard the work is measured against. Do not stop when the output is
merely good — stop when it stops losing to this bar.

### Reference artifacts

{{BAR_SOURCES}}

<!-- For each: what it is, why it is the standard, and exactly how to reach it —
     a URL, a path, a checkout, a screenshot directory, a command that produces
     the golden output. Omit this subsection only if there is genuinely no reference. -->

### Specification

Each line is judged by running its probe against real output.

| # | Dimension | Requirement | Probe | Losing looks like | Pri |
|---|-----------|-------------|-------|-------------------|-----|
{{SPEC_TABLE_ROWS}}

<!-- 5-9 rows. Requirements are observable from outside. Probes are concrete actions.
     "Losing looks like" names the specific failure to hunt for. Pri is P0/P1/P2. -->

{{DO_NOT_REGRESS_BLOCK}}

<!-- Existing codebases only. A P0 list of behavior that must survive unchanged:
     test suites that must still pass, API contracts that must not change,
     performance that must not degrade, data that must not be migrated. -->

## Constraints

{{CONSTRAINTS}}

<!-- Non-negotiable facts about the environment. These bound the search space.
     Violations are rejected outright rather than graded. -->

## Out of Scope — Do Not Optimize

{{OUT_OF_SCOPE}}

<!-- What the loop must not spend rounds on. Be specific; this is how the loop
     stays pointed at the goal instead of polishing whatever the critic finds
     interesting. -->

## How to Run This Loop

1. **Choose your own approach.** You have the goal and the bar. The route is yours.
   Do not ask me to specify architecture, libraries, or file layout.

2. **Split the work.** Divide the goal into the smallest pieces that can be improved
   and judged independently. Every piece must map to at least one line of the
   specification above. Write the split down before you start building.

3. **Build each piece with a dedicated builder subagent.** Give it the goal for its
   piece, the bar lines that apply to it, and the constraints.

4. **Critique with a separate agent, every round.** The critic:
   - starts with **fresh context** and never sees the builder's reasoning or self-assessment
   - **inspects real output** — runs the command, opens the page, feeds the input,
     takes the screenshot. Reading the diff is not inspection.
   - compares directly against the bar, using a **blind A/B against the reference
     artifact** wherever one exists
   - names **the single biggest remaining gap**, concretely
   - sends the work back to the builder with that gap

5. **Keep looping.** {{STOP_CONDITION}}

   Do not stop because the output is "pretty good", "impressive", or "good enough
   for an AI". Those are the failure modes this loop exists to prevent.

6. **Maintain a live progress document** at `{{PROGRESS_DOC_PATH}}`. Update it after
   every round: which piece, which round, what the critic said, what changed, and
   the current standing against each bar line. I will read it while you work — do
   not stop to ask me for direction.

7. **Smoothing pass.** When every piece has converged, run one final pass across the
   whole result for consistency between independently built pieces — naming, visual
   language, error handling, tone, interaction patterns. Judge the whole against the
   bar one more time.

Use subagents throughout. {{ULTRACODE_LINE}}
```

---

## Filling notes

- `{{STOP_CONDITION}}` — write out the chosen condition in full, e.g.:
  *"Continue until, for two consecutive rounds, the critic rates the work at or above the bar on every P0 and P1 line and cannot name a new gap above trivial severity."*
- `{{PROGRESS_DOC_PATH}}` — default `GAUNTLET-PROGRESS.md` in the repo root.
- `{{ULTRACODE_LINE}}` — include `Use ultracode.` when the user's harness supports it; otherwise drop the line rather than substituting a lookalike.
- `{{DO_NOT_REGRESS_BLOCK}}` — delete entirely for greenfield.
- If a spec row has no real probe, do not ship the row. Fix it or cut it.
