---
name: land-step
description: Part of the pr-workflow skill. Moves a landed "In review" step to the done file.
  User-invocable only — do not trigger autonomously.
---

Part of the `pr-workflow` skill — only meaningful when that skill is active.

The "active plan" is the plan file most relevant to this session — infer from context, or ask if
unclear. The user may specify which step to land; if not, and there's only one step in "In review",
use that one. If ambiguous, ask.

## 1. Verify the step is landed

- Read the "## In review" section of the active plan.
- Confirm all checklist items for the target step are checked. If any are unchecked, ask the user
  whether to proceed anyway or address them first.

## 2. Move to done file

- Cut the step entry (heading + checklist) from "In review" in the active plan.
- Append it to the corresponding `*_done.md` file. Change the status to reflect completion
  (e.g. "**Status:** Complete — merged.").
- Add a one-line entry under "## Completed" in the active plan pointing to `_done.md`.
- If "In review" is now empty, remove the section header.
