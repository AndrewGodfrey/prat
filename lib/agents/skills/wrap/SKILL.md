---
name: wrap
description: Finalize the completed plan step. /wrap closes a step; /wrap-session closes a
  session. User-invocable only — do not trigger autonomously.
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## 0. Is the step complete?

If the session is ending but the step is still in progress, don't wrap — invoke `/wrap-session`
instead.

## 1. Finalize current step

- **Check the wrap list.** Look for a "## Wrap list" section near the top of the active plan.
  If present, work through each item in it.

- **Public repo check.** If any changes in this step touch a public repo (prefs, prat),
  invoke `/check-prat-layers`.

## 2. Update plan

- **Move the completed step.** Cut the completed step from the active plan and append it to the
  end of the corresponding `*_done.md` file, condensed to final outcomes — what changed and why,
  not the step's task list or how conclusions were reached. Do not leave a copy in both files.

- **If the plan is now complete:**
  - Consider the remaining content in the plan file (title, background, design section, etc.)
    It might have permanent design info that belongs in a document - move that if so.
  - Then, move all remaining content to the done file as a header block, then delete the plan
    file. Skip section 4 — there is nothing to advance.

## 3. Reflect

Invoke `/reflect` — review learnings; the implementation `/reflect` already ran at code-complete.

## 4. Advance the pointer

Only once open questions (including any from the `/reflect` conversation) are resolved — never in
the same turn as an open question:

```powershell
. "$home/prat/lib/agents/Set-PlanState.ps1"
Set-PlanState -PlanFile <active plan> -Advance
```

Defaults to the next remaining step; if the user named a different step to do next, add
`-ToStep 'Step N'`. The script sets `state` itself: `ready-to-implement` if the new pointer was
already refined, else `ready-to-plan`.
