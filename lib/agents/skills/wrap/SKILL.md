---
name: wrap
description: Wraps up the active unit of work in the active plan. User-invocable only — do not trigger autonomously.
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear. A "unit" is the plan's current-unit pointer — a contiguous run of one or more steps
(`first`..`last`); see PlanState.ps1's header for the design rationale.

This skill advances the active plan one lifecycle notch — records the user's approval of a
refined unit (at ready-to-plan) or closes a completed one (at ready-for-user-review) — and always runs
/reflect. /wrap-session closes a session instead. 

## 0. Read the state

```powershell
. "$home/prat/lib/agents/PlanState.ps1"
Get-PlanState -PlanFile <active plan>
```

Dispatch on `state`:

## `ready-to-plan` → advance to ready-to-implement

Invoking `/wrap` here is itself the user's approval of the refined unit — this skill doesn't ask,
it acts.

Before writing anything, sanity-check that the pointed-at unit's spec (`first`..`last`) is
implementable — if it's still terse bullets or has open design questions, say so and stop rather
than advance.

Otherwise:
1. Invoke `/reflect` — planning lessons.
2. Only once open questions (including any raised during that `/reflect` conversation) are
   resolved — never in the same turn as an open question:
   ```powershell
   Set-PlanState -PlanFile <active plan> -State ready-to-implement
   ```

## `ready-for-user-review` → close the unit

`/ready-for-user-review` already ran the wrap list and any inline step requirements before recording this
state — don't re-run them here.

- **Move the completed unit.** Cut the unit's step(s) — `first` through `last` — from the active
  plan and prepend them to the start of the corresponding `*_done.md` file, condensed to final
  outcomes — what changed and why, not the task list or how conclusions were reached. Do not leave
  a copy in both files.
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

- **If the plan is now complete:**
  - Consider the remaining content in the plan file (title, background, design section, etc.)
    It might have permanent design info that belongs in a document - move that if so.
  - Then, move all remaining content to the done file as a header block, then delete the plan
    file. Skip the pointer-advance step below — there is nothing to advance.

- Invoke `/reflect` — review lessons; the implementation `/reflect` already ran at ready-for-user-review.

- **Advance the pointer.** Only once open questions (including any from the `/reflect`
  conversation) are resolved — never in the same turn as an open question:
  ```powershell
  Set-PlanState -PlanFile <active plan> -Advance
  ```
  Defaults to the next remaining step; if the user named a different step to do next, add
  `-ToStep 'Step N'`. The script sets `state` itself: `ready-to-implement` if the new pointer was
  already refined, else `ready-to-plan`.

- **Report the result.** Name the new pointer and its resulting state. If the pointer came off
  the `refined` list (state now `ready-to-implement`), say so explicitly — the user should know
  the next step was pre-planned.

## `ready-to-implement` or `checkpointed` → misfire guard

The unit is mid-lifecycle — don't proceed. Point the user at `/ready-for-user-review` (implementation
finished this session) or `/wrap-session` (pausing mid-unit).

## No frontmatter block → treat as ready-to-plan

If `Get-PlanState` reports `HasFrontmatter` false, the plan predates the state mechanism and is
being wrapped for the first time. Treat it as `ready-to-plan` and run that flow — `Set-PlanState`
initializes the frontmatter. This is safe under the convention that implementation goes through
`/ready-for-user-review` first (which sets a state), so a plan reaching `/wrap` with no frontmatter is one
where planning just finished. Exception: if this session actually wrote implementation code for the
unit, use the `ready-for-user-review` close instead.

## Unrecognized state → ask

`HasFrontmatter` is true but `state` is a value this skill doesn't handle. Ask the user which close
applies rather than guessing.
