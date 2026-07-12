---
name: remember
description: Use when the user asks the agent to remember or note something for future sessions ("remember that",
  "note that", "don't forget"), or when capturing a behavioral correction. Do NOT invoke for 
  one-time task direction within the current task (e.g. "please also include X").
---

## Where to save

Prefer homes that load only when relevant over always-loaded files. Always-loaded context degrades
the agent's work as it grows: each rule dilutes attention on the others, and contradictory
instructions are especially costly. Reserve always-loaded agent-user files for rules that must be
active before their trigger could be recognized.

- **harness-specific** → `prat/lib/agents/harness-specific/` (e.g. `prat-cc.md`). A workaround for
  observed harness behavior defaults here even if it looks general — promote to a harness-agnostic
  home only once the same behavior is seen in another harness. Concepts and conventions are
  different: see "What is not harness-specific" below — don't over-classify those.
- **Truly universal** (any prat user on any machine) → `prat/lib/agents/agent-user_prat.md`
  Note: this file loads in **every session**, not just when working in prat/prefs/de. Don't put
  guidance here that's only relevant when editing those repos — it will pollute unrelated sessions.
- **Repo-specific facts** → that repo's `AGENTS.md`
- **User-specific preferences** → the user's prefs repo (`prefs/lib/agents/agent-user_prefs.md`), if they have one
- **User-specific, or only relevant when editing prat/prefs/de** → the user's de repo
  (`de/lib/agents/agent-user_de.md`), if they have one
- **Triggerable procedures** → create or modify a skill. Write the trigger as concrete
  symptoms/situations, and check that a proactive "before X" clause doesn't match every session in
  practice — that makes the skill effectively always-loaded
- **Tool-usage notes** → the tool's own description where the mechanism allows (e.g. an MCP tool) —
  it loads exactly when the tool does

## What is not harness-specific

Agent harnesses tend to present their features as unique, which biases agents toward
over-classifying content as harness-specific. These are NOT harness-specific:

- **Slash notation** (`/skill-name`) — a naming convention for invoking skills, not a harness-specific construct
- **"User-invocable only — do not trigger autonomously"** — applicable to any harness
- **The skill abstraction** — not harness-specific
- **Hooks** — running code on agent events is a general concept; only the harness-specific format,
  paths, and event names belong in `harness-specific/`

## What to capture

Capture behavioral corrections — things where a fresh agent session would make the same mistake without
the note. Skip one-time task direction ("please also include X in this document").

Test: would a fresh agent session have made this mistake without the direction? If yes, capture it.
If no, it was context-specific — skip.

Edge case: "please ask me before doing X" sounds one-time but is usually a standing preference —
flag for confirmation before capturing.

## How to write entries

Before adding, search the target file for an existing entry on the same theme. If one exists,
generalize it — restate the shared principle and keep the one or two sharpest examples — rather
than appending another instance. Prefer pairing an addition with a removal: propose an entry the
addition subsumes, or one that looks stale, as a candidate to retire.

State the rule. Omit obvious implications — if the consequence follows directly from the
instruction, a reader will infer it. One sentence where possible. Don't tack on a closing
explanatory sentence unless it heads off a specific competing interpretation — if the rule's
reasoning is obvious from the rule itself, the closer is filler.
