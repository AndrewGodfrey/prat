---
name: plan-refine-next-step
description: Set up the next step in a plan.
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear. State-script calls below assume `. "$home/prat/lib/agents/PlanState.ps1"` has been
dot-sourced; read the current state with `Get-PlanState -PlanFile <plan>`.

- **Verify the next-step pointer.** `/wrap` already advanced the frontmatter `next-step` when the
  previous step closed — normally there is nothing to set. Before proceeding, scan the plan's
  other steps for a done-marker (✓) or explicit "not done" language: an earlier, unrelated open
  item can be higher priority than the default order, and is easy to miss. If the pointer should
  move (or the user names a different step), run
  `Set-PlanState -PlanFile <plan> -Advance -ToStep 'Step N'`.
  If the plan has no pointer yet (a brand-new plan), run
  `Set-PlanState -PlanFile <plan> -Advance` — with no prior pointer it targets the first step.
  If the plan has no `## Step` headings at all (e.g. a notes/design doc being promoted to a
  working plan), it needs structure before a pointer can exist: invoke `plan-format`, then
  `start-plan`, instead of continuing here.
  If the user says the plan is complete but the plan file still shows an unfinished step, read the
  code before deferring it — prior sessions may have implemented it without wrapping.

  Older plans may carry a `## Next step:` heading instead of frontmatter — treat it as the
  pointer, migrate it via `Set-PlanState -PlanFile <plan> -First '<step id: label>'`, and
  delete the heading.

- **Flesh out the pointed-at step.** Expand it from terse bullets into actionable detail — enough
  that a fresh agent session starting with "do the next step of this plan" can proceed without
  ambiguity, and without reading the plan's background file. Where the design rests on a factual
  claim about the codebase or about a dependency's behaviour — how often a pattern occurs, whether a case exists,
  what a library does on this platform, relevant platform behavior — measure it and record the number in the
  step, rather than asserting it from intuition. A decision recorded in a plan file is not a
  substitute: plans record what was decided, not the evidence for it.

  Measure against the real dependency when one is reachable — ask for it to be started if it isn't.
  A stand-in reproduces the happy path but rarely the failure modes, and error-handling branches
  on exactly those: two stand-ins for the same condition can raise different exception types. If
  only a stand-in is available, label the number as a proxy in the step.

  Where the step fixes a **constant** — a timeout, poll interval, retry count, cap, threshold — measure the
  quantity it has to accommodate and derive the value from that. Confirming that the first value you tried
  works is not a derivation, and the two are indistinguishable in the finished step, so record the measurement
  next to the constant ("the process settles in 37–50ms, so poll at 10ms"). A validated guess is usually both
  larger than it needs to be and untethered to the thing that would invalidate it.

- **Check the level of the change.** Before a step adds a mechanism — a retry, a connection or
  resource lifecycle, a cache, cancellation plumbing — to one module, count the sibling call sites
  that already own that concern. Grep for it; don't estimate. If several do, the step is probably
  an extraction, and planning it as a local tweak silently commits every future sibling to
  reimplementing the mechanism.

- **Add a sub-item to check test coverage for modified lines.**

- **Decide whether to apply /review-changes at the end of the step.** This is particularly
  expensive in token costs. Worth it for complex changes that could benefit from an independent
  review, and doing it before the user's turn increases throughput. Skip it after small,
  well-planned steps with little ambiguity.

  If you decide it's worth it, conclude the plan step with:
    - Run `/review-changes`, and address its feedback. If there's a lot of ambiguity left,
      consider running it **one** more time.

- **If you refined further steps beyond the pointer** *and the user asked to plan ahead*, record
  them: read the current `Refined` list via `Get-PlanState`, append the newly refined step ids,
  and write the result back with `Set-PlanState -PlanFile <plan> -Refined <updated list>`.

- **Report and hand off.** Tell the user the pointed-at step is refined and ready for their
  review. State stays `ready-to-plan` until they've reviewed it; `/wrap` is how they record their
  approval and advance to `ready-to-implement` — don't propose running it, that's the user's call
  to make and initiate. If any further steps were refined ahead, name them in the report so the
  user knows more than one step got planned.
