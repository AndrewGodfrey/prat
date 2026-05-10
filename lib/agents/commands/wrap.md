---
description: Finalize the completed plan step and set up the next one. User-invocable only — do not trigger autonomously.
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## 1. Finalize current step

- **Check the wrap list.** Look for a "## Wrap list" section near the top of the active plan
  (typically just after the "## Next step" line). If present, work through each item in it.

- **Public repo check.** If any changes in this step touch a public repo (prefs, prat),
  invoke `/check-prat-layers`.

## 2. Update plan

- **Update the next-step pointer.** Set the "## Next step" line at the top of the active plan to
  the next step.

- **Move the completed step.** Cut the completed step description from the active plan and append
  it to the corresponding `*_done.md` file. Do not leave a copy in both files.

- **Flesh out the next step.** Expand the next step entry from terse bullets into actionable
  detail — enough that a fresh Claude starting with "do the next step of this plan" can proceed
  without ambiguity.

- **Add a step to check test coverage for modified lines**

- **Decide whether to apply /review-changes at the end of the next step.** Subagents are particularly
  expensive in token costs - they seem to cause extra main-agent turns and also waste time regaining context
  the main agent already had. The /review-changes subagent is worth it for complex changes that could benefit
  from an independent review. And doing that before the user's turn really increases our throughput.
  But we don't want to do it after small, well-planned steps with little ambiguity.

  If you decide it's worth it, conclude the plan step with:
    - Run `/review-changes`, and address its feedback. If there's a lot of ambiguity left, consider running it **one** more time.

## 3. Reflect

Invoke `/reflect`.
