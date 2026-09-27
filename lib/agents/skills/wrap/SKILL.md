---
name: wrap
description: Wraps up the active unit of work in the active plan. User-invocable only, except in a
  `branch-review` run, where the agent invokes it itself at the close of each step — otherwise do
  not trigger autonomously.
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear. A "unit" is the plan's current-unit pointer — a contiguous run of one or more steps
(`first`..`last`); see PlanState.ps1's header for the design rationale.

This skill advances the active plan one lifecycle notch — records the user's approval of a
refined unit (at ready-for-refined-step-review) or closes a completed one (at ready-for-user-review) — and
always runs /reflect, which at this point records findings rather than making changes. /wrap-session closes a
session instead.

## 0. Read the state

```powershell
. "$home/prat/lib/agents/PlanState.ps1"
Get-PlanState -PlanFile <active plan>
```

Dispatch on `state`:

## `ready-for-refined-step-review` (or `ready-to-refine`) → advance to ready-to-implement

Invoking `/wrap` here is itself the user's approval of the refined unit — this skill doesn't ask,
it acts. `ready-to-refine` lands in this arm too: a unit refined by hand or in conversation reaches
`/wrap` without the refine pass that would have set the other state.

Before writing anything, sanity-check that the pointed-at unit (`first`..`last`) is
implementable — if it's still terse bullets or has open design questions, say so and stop rather
than advance.

Otherwise:
1. 
```powershell
Set-PlanState -PlanFile <active plan> -State ready-to-implement
```

2. Invoke `/reflect` — planning lessons.

## `ready-for-user-review` → close the unit

`/ready-for-user-review` already ran the wrap list and any inline step requirements before recording this
state — don't re-run them here.

- **Move the completed unit.** Cut the unit's step(s) — `first` through `last` — from the active
  plan and prepend them to the start of the corresponding `*_done.md` file, condensed to final
  outcomes — what changed and why, not the task list or how conclusions were reached. Do not leave
  a copy in both files. If the done file doesn't exist yet, create it where the `plan-format`
  skill's "Companion files" section says it lives — not alongside the plan — and add the opening
  pointer line to the plan.
  - **Match the done file's own heading convention**, not just the active plan's current one — it
    may keep a numbering sequence the active plan stopped maintaining (e.g. older steps numbered,
    newer ones named-only). Check the done file's existing entries and continue that sequence. If
    the active plan itself keeps a one-line index of completed steps, add this unit to it and trim
    the list to the 5 most recent entries — the full list is already in the done file, and every
    session that reads the plan pays for the rest. Keep the numbers on the survivors so they still
    match the done file. If a trimmed line carried an annotation the done file lacks ("later
    retired in favor of X"), move it into the done entry first.

- **Re-point what's left.** Grep the remaining steps for references to the moved unit ("see the X
  step", "previous step", "once X lands") and for claims it just settled — a later step may still
  warn about a cause the unit disproved, or rest on a measurement it invalidated. Update both in
  place; a reference to a step now in the done file should name it by its done-file number.

- **Grep the other active plans too**, for the moved step's name (and, when closing the whole plan,
  the plan's own filename). Distinguish provenance notes ("moved from X on DATE", "split out of X's
  Y step" — safe to leave, meaningful even once X is gone) from live pointers ("see X's step N for
  the full design" — redirect these to the done file, e.g. `<name>_done.md` step N, so the
  reference still resolves). A live pointer also decides what the done entry has to keep: condensing
  to final outcomes doesn't license dropping data another plan stands on. A file whose own header
  says it's a point-in-time snapshot regenerated periodically (not continuously maintained) doesn't
  need hand-patching — it self-corrects at the next regeneration.

- **If the plan is now complete:**
  - Consider the remaining content in the plan file (title, background, design section, etc.)
    It might have permanent design info that belongs in a document - move that if so.
  - Then, move all remaining content to the done file as a header block, then delete the plan
    file. Skip the pointer-advance step below — there is nothing to advance.

- Invoke `/reflect` — review lessons; the implementation `/reflect` already ran at ready-for-user-review.
  Here it records findings and makes no code changes: the user has just reviewed a diff, and an edit landing
  behind them is one they did not review. A fix you are sure of belonged in the work itself. The same rule
  holds in a `branch-review` run, where this arm runs with nobody having reviewed a diff yet — see
  `plan-format`'s workflow section for why.

- **Advance the pointer.** Only once open questions (including any from the `/reflect`
  conversation) are resolved — never in the same turn as an open question:
  ```powershell
  Set-PlanState -PlanFile <active plan> -Advance
  ```
  Defaults to the next remaining step; if the user named a different step to do next, add
  `-ToStep 'Step N'`. The script sets `state` itself: `ready-to-implement` if the new pointer was
  already refined, else `ready-to-refine`.
  - **Closing the last remaining step lands at `ready-for-user-review`.** The step's body is cut to
    the done file before the advance, so the pointer names a step that is no longer in the file and
    nothing is left to point at. The advance returns cleanly (it does not throw) and leaves the plan
    at `ready-for-user-review` with the pointer on the closed step — that is a finished plan, and the
    whole branch is what the user reviews. Don't treat the missing heading as an error, and don't
    re-point or delete the frontmatter.

- **Report the result.** Name the new pointer and its resulting state. If the pointer came off
  the `refined` list (state now `ready-to-implement`), say so explicitly — the user should know
  the next step was pre-planned.

## `ready-to-implement` → misfire guard

The unit is mid-lifecycle — don't proceed. Point the user at `/ready-for-user-review` (implementation
finished this session) or `/wrap-session` (pausing mid-unit).

## No frontmatter block → treat as ready-to-refine

If `Get-PlanState` reports `HasFrontmatter` false, the plan predates the state mechanism and is
being wrapped for the first time. Treat it as `ready-to-refine` and run that flow — `Set-PlanState`
initializes the frontmatter. This is safe under the convention that implementation goes through
`/ready-for-user-review` first (which sets a state), so a plan reaching `/wrap` with no frontmatter is one
where planning just finished. Exception: if this session actually wrote implementation code for the
unit, use the `ready-for-user-review` close instead.

## Unrecognized state → ask

`HasFrontmatter` is true but `state` is a value this skill doesn't handle. Ask the user which close
applies rather than guessing.
