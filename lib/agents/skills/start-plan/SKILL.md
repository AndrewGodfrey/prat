---
name: start-plan
description: Set up the first step of a new plan. Invoked after plan-format creates the plan structure.
---

The "active plan" is the plan file most recently created or restructured — infer from context.

## 1. Handle companion file creation

If the plan was created by splitting an existing file (e.g. extracting a `_ref.md` from an existing
plan file), load `working-with-git` and follow the rename pattern before writing any content:
`git mv` the original to the new name, commit as a pure rename, then write new content in a
second change.

## 2. Set up the first step

Invoke `/plan-refine-next-step`.
