---
name: code-complete
description: Use at the end of the turn where you believe the current plan step's implementation
  is complete (reflect, then mark the state), and when picking up a plan already in code-complete
  (review-mode expectations apply).
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## Marking code-complete

At the end of the turn where you believe the step is done:

1. Invoke `/reflect` — implementation lessons, captured now while the implementation context is
   loaded; the review that follows may happen in a different session.
2. Mark the state:
   ```powershell
   . "$home/prat/lib/agents/Set-PlanState.ps1"
   Set-PlanState -PlanFile <active plan> -State code-complete
   ```

The mark is an agent claim that implementation is done, not user agreement. If it turns out
premature, the user will ask for a flip back — run the script with `-State ready-to-implement`,
and treat the misfire as input for the next `/reflect`.

## Review mode

Once a step is code-complete, the user reviews and/or manually tests it. Expect a user-directed
pass that isn't written in the plan, typically including one or more of: bug reports (investigate;
fix immediately if small, report back otherwise), edits made directly by the user, change requests
(cleanup, refactoring — including pre-existing issues that only surface during this pass — or even
additional features in the same step), test-coverage work (including pre-existing gaps), and plan
additions.

Do not push toward `/wrap`. Only the user closes a step — an explicit approval (e.g. "lgtm") or
invoking `/wrap` themselves. Don't infer completion from commits: a single step commonly spans
several, staged and committed incrementally as review progresses.

Before starting additional work connected to the step (a requested change, a bug fix), first write
at least a one-line description of it into the step's body in the plan. `/wrap` and
`/plan-refine-next-step` act only on the plan file's content — unrecorded work is invisible to
them and gets silently dropped.
