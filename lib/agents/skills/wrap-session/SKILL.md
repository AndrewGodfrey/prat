---
name: wrap-session
description: Close out a session whose step is still in progress — checkpoint done/remaining into
  the plan, reflect, set state checkpointed. /wrap-session closes a session; /wrap advances the
  plan a lifecycle notch. User-invocable only — do not trigger autonomously.
---

Use before abandoning or pausing a session mid-step — e.g. before a long break, or when a session
has grown too long and the step will continue in a fresh one.

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## 1. Checkpoint the step

Update the in-progress step's body in the active plan: what's done, what remains. This is also the
last opportunity to record anything unique or interesting from this session's transcript — for
plan purposes it is never revisited. These notes are agent claims, not user agreement.

## 2. Reflect

Invoke `/reflect`.

## 3. Set state

```powershell
. "$home/prat/lib/agents/Set-PlanState.ps1"
Set-PlanState -PlanFile <active plan> -State checkpointed
```

The launcher consumes `checkpointed` on its next launch for this plan: a fresh "do the next step"
session, with older sessions kept for reference only.
