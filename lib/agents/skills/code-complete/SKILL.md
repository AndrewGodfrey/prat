---
name: code-complete
description: Use before the end of the turn where you have completed coding for the active unit
  of work, and tests are green. Or, when picking up a plan already in code-complete state
  (see "Review mode").
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## Marking code-complete

At the end of the turn where the active unit's coding is done and tests are green, verify before
recording the transition — once the user starts reviewing, further changes from these checks cost
a second review pass:

1. **Public repo check.** If any changes in this unit touch a public repo (prefs, prat), invoke
   `/check-prat-layers`.
2. **Wrap list + inline requirements.** Work through the plan's "## Wrap list" section (near the
   top of the active plan) if present, and any requirement stated in the unit's own step body/bodies
   (e.g. "Conclude with `/review-changes`"). Fix anything found, and re-verify tests are still green.
3. Record the transition:
   ```powershell
   . "$home/prat/lib/agents/PlanState.ps1"
   Set-PlanState -PlanFile <active plan> -State code-complete
   ```
4. Invoke `/reflect` — implementation lessons, captured now while the implementation context is
   loaded. (After that, review of the current step may continue in the current session, or may start in a new session).

## Review mode

Once a unit is code-complete, the user reviews and/or manually tests it. Expect a user-directed
pass that isn't written in the plan, typically including one or more of: bug reports (investigate;
fix immediately if small, report back otherwise), edits made directly by the user, change requests
(cleanup, refactoring — including pre-existing issues that only surface during this pass — or even
additional features in the same unit), test-coverage work (including pre-existing gaps), and plan
additions. The user may stage and commit some changes while keeping others under review/test.

Do not push toward `/wrap`. Only the user closes a unit — an explicit approval (e.g. "lgtm") or
invoking `/wrap` themselves.

Before starting additional work connected to the unit (a requested change, a bug fix), first write
at least a one-line description of it into the relevant step's body in the plan.
