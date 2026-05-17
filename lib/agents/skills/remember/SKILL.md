---
name: remember
description: Use when the user asks the agent to remember or note something for future sessions ("remember that",
  "note that", "don't forget"), or when capturing a behavioral correction. Do NOT invoke for 
  one-time task direction within the current task (e.g. "please also include X").
---

## Where to save

- **harness-specific** → `prat/lib/agents/harness-specific/` (e.g. `cc/prat-cc.md`). See "What is not
  harness-specific" below — don't over-classify.
- **Truly universal** (any prat user on any machine) → `prat/lib/agents/agent-user_prat.md`
  Note: this file loads in **every session**, not just when working in prat/prefs/de. Don't put
  guidance here that's only relevant when editing those repos — it will pollute unrelated sessions.
- **Repo-specific facts** → that repo's `AGENTS.md`
- **User-specific preferences** → the user's prefs repo (`prefs/lib/agents/agent-user_prefs.md`), if they have one
- **User-specific, or only relevant when editing prat/prefs/de** → the user's de repo
  (`de/lib/agents/agent-user_de.md`), if they have one
- **Triggerable procedures** → create or modify a skill

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

State the rule. Omit obvious implications — if the consequence follows directly from the
instruction, a reader will infer it. One sentence where possible.
