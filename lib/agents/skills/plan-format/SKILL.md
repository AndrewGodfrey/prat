---
name: plan-format
description: Use when creating a new plan file or restructuring an existing one.
---

A plan file should be action-focused — easy to update, easy to resume from.

## Structure

**Opening lines** — pointers to companion files (if they exist):
```
See `fooPlan_ref.md` for background: <one-line summary of what's there>.
See `fooPlan_done.md` for completed phases and design rationale.
```

**Next step** — prominent, at the top of the action content:
```
## Next step: Phase N: <brief label>
```

**Wrap list** — small checklist of things to verify before marking a step done (e.g. "check
changes don't reference private files"). Stays near the top so it's visible when finishing work.

**Phases** — action steps. Label each sub-step `[CLAUDE]` or `[USER]`. Strike through completed
items inline (`~~item~~ ✓ Done`) rather than deleting them, until the phase is fully done —
then move the whole phase to `_done.md`.

## Companion files

**`_ref.md`** — stable background that rarely changes: design rationale, naming conventions,
architecture diagrams, "what stays where" lists. Agents read this at task start, not when
updating the plan.

**`_done.md`** — completed phases, preserved for context and rationale. Move a phase here once
all its steps are struck through.

Split content into a companion file when it would make agents re-read stable material every time
they update the plan. If content changes alongside the action steps, keep it in the main file.
