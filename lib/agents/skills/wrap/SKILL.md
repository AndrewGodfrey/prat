---
name: wrap
description: Finalize the completed plan step. User-invocable only — do not trigger autonomously.
---

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear.

## 0. Is the step complete?

If the user signals the session is ending but the step is still in progress, skip sections 1 and 2.
Instead, update the step in the plan to document what's done and what remains, then go to section 3.

## 1. Finalize current step

- **Check the wrap list.** Look for a "## Wrap list" section near the top of the active plan
  (typically just after the "## Next step" line). If present, work through each item in it.

- **Public repo check.** If any changes in this step touch a public repo (prefs, prat),
  invoke `/check-prat-layers`.

## 2. Update plan

- **Move the completed step.** Cut the completed step description from the active plan and append
  it to the end of the corresponding `*_done.md` file. Do not leave a copy in both files.

- **If the plan is now complete:**. 
  - Consider the remaining content in the plan file (title, background, design section, etc.)
    It might have permanent design info that belongs in a document - move that if so. 
  - Then, move all remaining content to the  done file as a header block, then delete the plan file.
  - Update `~/prat/auto/context/db.json`: If it still has an entry with a matching `planFile`, delete that entry.

## 3. Reflect

Invoke `/reflect`.
