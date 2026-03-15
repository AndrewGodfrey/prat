---
name: remember
description: >
  Use when the user asks Claude to remember or note something for future sessions ("remember that",
  "note that", "don't forget"), or when capturing a behavioral correction. Also invoked as /remember.
  Do NOT invoke for one-time task direction within the current task (e.g. "please also include X").
---

## Where to save

- **Dev-environment-wide** (applies to any repo in this environment) → `prat/lib/agents/agent-user.md`
- **Repo-specific facts** → that repo's `CLAUDE.md`
- **User-specific, dev-env-specific preferences** → the user's own dev-env repro, if they have one.
- **User-specific preferences** → the user's own prefs repo, if they have one.
- **Triggerable procedures** → create or modify a command, agent, or skill

## What to capture

Capture behavioral corrections — things where a fresh Claude would make the same mistake without
the note. Skip one-time task direction ("please also include X in this document").

Test: would a fresh Claude have made this mistake without the direction? If yes, capture it.
If no, it was context-specific — skip.

Edge case: "please ask me before doing X" sounds one-time but is usually a standing preference —
flag for confirmation before capturing.

## How to write entries

State the rule. Omit obvious implications — if the consequence follows directly from the
instruction, a reader will infer it. One sentence where possible.
