---
name: wrap
description: Advances the active plan one lifecycle notch — records the user's approval of a
  refined step (at ready-to-plan) or closes a completed one (at code-complete) — and always runs
  /reflect. /wrap-session closes a session instead. User-invocable only — do not trigger
  autonomously.
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## 0. Read the state

```powershell
. "$home/prat/lib/agents/PlanState.ps1"
Get-PlanState -PlanFile <active plan>
```

Dispatch on `state`:

## `ready-to-plan` → advance to ready-to-implement

Invoking `/wrap` here is itself the user's approval of the refined step — this skill doesn't ask,
it acts.

Before writing anything, sanity-check that the pointed-at step's spec is implementable — if it's
still terse bullets or has open design questions, say so and stop rather than advance.

Otherwise:
1. Invoke `/reflect` — planning lessons.
2. Only once open questions (including any raised during that `/reflect` conversation) are
   resolved — never in the same turn as an open question:
   ```powershell
   Set-PlanState -PlanFile <active plan> -State ready-to-implement
   ```

## `code-complete` → close the step

- **Check the wrap list.** Look for a "## Wrap list" section near the top of the active plan.
  If present, work through each item in it.

- **Public repo check.** If any changes in this step touch a public repo (prefs, prat),
  invoke `/check-prat-layers`.

- **Move the completed step.** Cut the completed step from the active plan and append it to the
  end of the corresponding `*_done.md` file, condensed to final outcomes — what changed and why,
  not the step's task list or how conclusions were reached. Do not leave a copy in both files.

- **If the plan is now complete:**
  - Consider the remaining content in the plan file (title, background, design section, etc.)
    It might have permanent design info that belongs in a document - move that if so.
  - Then, move all remaining content to the done file as a header block, then delete the plan
    file. Skip the pointer-advance step below — there is nothing to advance.

- Invoke `/reflect` — review lessons; the implementation `/reflect` already ran at code-complete.

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

The step is mid-lifecycle — don't proceed. Point the user at `/code-complete` (implementation
finished this session) or `/wrap-session` (pausing mid-step).

## No frontmatter block → treat as ready-to-plan

If `Get-PlanState` reports `HasFrontmatter` false, the plan predates the state mechanism and is
being wrapped for the first time. Treat it as `ready-to-plan` and run that flow — `Set-PlanState`
initializes the frontmatter. This is safe under the convention that implementation goes through
`/code-complete` first (which sets a state), so a plan reaching `/wrap` with no frontmatter is one
where planning just finished. Exception: if this session actually wrote implementation code for the
step, use the `code-complete` close instead.

## Unrecognized state → ask

`HasFrontmatter` is true but `state` is a value this skill doesn't handle. Ask the user which close
applies rather than guessing.
