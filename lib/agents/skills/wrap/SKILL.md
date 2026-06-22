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

- **If the plan is now complete:**. Consider the remaining content in the plan file (title, background, design section, etc.)
  It might have permanent design info that belongs in a document - move that if so. Then, move all remaining content to the
  done file as a header block, then delete the plan file. Skip `/plan-refine-next-step`.

- Otherwise: invoke `/plan-refine-next-step`.

## 3. Reflect

Invoke `/reflect`.
