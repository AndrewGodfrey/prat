---
name: plan-refine-next-step
description: Set up the next step in a plan — verify the pointer, flesh out detail, add coverage
  and review-changes steps, then mark it ready to implement.
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear. State-script calls below assume `. "$home/prat/lib/agents/Set-PlanState.ps1"` has been
dot-sourced; read the current state with `Get-PlanState -PlanFile <plan>`.

- **Verify the next-step pointer.** `/wrap` already advanced the frontmatter `next-step` when the
  previous step closed — normally there is nothing to set. Before proceeding, scan the plan's
  other steps for a done-marker (✓) or explicit "not done" language: an earlier, unrelated open
  item can be higher priority than the default order, and is easy to miss. If the pointer should
  move (or the user names a different step), run
  `Set-PlanState -PlanFile <plan> -Advance -ToStep 'Step N'`.
  If the plan has no pointer yet (a brand-new plan), run
  `Set-PlanState -PlanFile <plan> -Advance` — with no prior pointer it targets the first step.
  If the user says the plan is complete but the plan file still shows an unfinished step, read the
  code before deferring it — prior sessions may have implemented it without wrapping.

  Older plans may carry a `## Next step:` heading instead of frontmatter — treat it as the
  pointer, migrate it via `Set-PlanState -PlanFile <plan> -NextStep '<step id: label>'`, and
  delete the heading.

- **Flesh out the pointed-at step.** Expand it from terse bullets into actionable detail — enough
  that a fresh agent session starting with "do the next step of this plan" can proceed without
  ambiguity, and without reading the plan's background file.

- **Add a sub-item to check test coverage for modified lines.**

- **Decide whether to apply /review-changes at the end of the step.** This is particularly
  expensive in token costs. Worth it for complex changes that could benefit from an independent
  review, and doing it before the user's turn increases throughput. Skip it after small,
  well-planned steps with little ambiguity.

  If you decide it's worth it, conclude the plan step with:
    - Run `/review-changes`, and address its feedback. If there's a lot of ambiguity left,
      consider running it **one** more time.

- **Mark it ready.** `Set-PlanState -PlanFile <plan> -State ready-to-implement`.

- **If you refined further steps beyond the pointer** (to the same fresh-session standard), record
  them: read the current `Refined` list via `Get-PlanState`, append the newly refined step ids,
  and write the result back with `Set-PlanState -PlanFile <plan> -Refined <updated list>`.
