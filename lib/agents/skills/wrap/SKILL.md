---
name: wrap
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

- **Move the completed step.** Cut the completed step description from the active plan and append
  it to the corresponding `*_done.md` file. Do not leave a copy in both files.

- Invoke `/plan-refine-next-step`.

## 3. Reflect

Invoke `/reflect`.
