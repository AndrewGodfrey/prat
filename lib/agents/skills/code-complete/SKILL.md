---
name: code-complete
description: Use before the end of the turn where you have completed coding for the current plan step,
  and tests are green. Or, when picking up a plan already in code-complete state
  (see "Review mode").
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## Marking code-complete

At the end of the turn where you believe the step's coding is done:

1. Invoke `/reflect` — implementation lessons, captured now while the implementation context is
   loaded; the review that follows may happen in a different session.
2. Mark the state:
   ```powershell
   . "$home/prat/lib/agents/PlanState.ps1"
   Set-PlanState -PlanFile <active plan> -State code-complete
   ```

## Review mode

Once a step is code-complete, the user reviews and/or manually tests it. Expect a user-directed
pass that isn't written in the plan, typically including one or more of: bug reports (investigate;
fix immediately if small, report back otherwise), edits made directly by the user, change requests
(cleanup, refactoring — including pre-existing issues that only surface during this pass — or even
additional features in the same step), test-coverage work (including pre-existing gaps), and plan
additions. The user may stage and commit some changes while keeping others under review/test.

Do not push toward `/wrap`. Only the user closes a step — an explicit approval (e.g. "lgtm") or
invoking `/wrap` themselves.

Before starting additional work connected to the step (a requested change, a bug fix), first write
at least a one-line description of it into the step's body in the plan.
