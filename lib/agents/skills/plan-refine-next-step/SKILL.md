---
name: plan-refine-next-step
description: Set up the next step in a plan — update the pointer, flesh out detail, add coverage and review-changes steps.
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

- **Update the next-step pointer.** Set the "## Next step" line at the top of the active plan to
  the next step. If the pointer doesn't exist yet, create it pointing to Phase 1. If the user says
  the plan is complete but the plan file still shows an unfinished step, read the code before
  deferring it — prior sessions may have implemented it without wrapping.

- **Flesh out the next step.** Expand the next step entry from terse bullets into actionable
  detail — enough that a fresh agent session starting with "do the next step of this plan" can
  proceed without ambiguity.

- **Add a step to check test coverage for modified lines.**

- **Decide whether to apply /review-changes at the end of the next step.** This is particularly
  expensive in token costs. Worth it for complex changes that could benefit from an independent
  review, and doing it before the user's turn increases throughput. Skip it after small,
  well-planned steps with little ambiguity.

  If you decide it's worth it, conclude the plan step with:
    - Run `/review-changes`, and address its feedback. If there's a lot of ambiguity left,
      consider running it **one** more time.
