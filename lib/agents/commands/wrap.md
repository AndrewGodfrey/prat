---
description: Finalize the completed plan phase and set up the next one
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## 1. Finalize current task

- **Check the wrap list.** Look for a "## Wrap list" section near the top of the active plan
  (typically just after the "## Next step" line). If present, work through each item in it.

- **Public repo check.** If any changes in this phase touch a public repo (prefs, prat), run
  `Find-SensitiveData` against each affected repo and verify the results against the checklist in
  `prat/lib/agents/agent-user.md`.

## 2. Update plan

- **Update the next-step pointer.** Set the "## Next step" line at the top of the active plan to
  the next phase.

- **Move the completed phase.** Cut the completed phase description from the active plan and append
  it to the corresponding `*_done.md` file. Do not leave a copy in both files.

- **Flesh out the next step.** Expand the next phase entry from terse bullets into actionable
  detail — enough that a fresh Claude starting with "do the next item in this plan" can proceed
  without ambiguity.

## 3. Reflect

Invoke `/reflect`.
