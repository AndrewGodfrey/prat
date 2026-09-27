---
name: wrap-session
description: Close out a session whose unit is still in progress. User-invocable only — do not trigger autonomously.
---

Use before abandoning or pausing a session mid-unit — e.g. before a long break, or when a session
has grown too long and the unit will continue in a fresh one.

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## 1. Checkpoint the unit

Update the in-progress unit's step body/bodies in the active plan: what's done, what remains. This
is also the last opportunity to record anything unique or interesting from this session's
transcript — for plan purposes it is never revisited. These notes are agent claims, not user
agreement.

This is the whole handover. The lifecycle state stays where it is: it records how far the unit got,
and pausing a session doesn't change that.

## 2. Reflect

Invoke `/reflect`.
