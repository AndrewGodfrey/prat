---
name: plan-format
description: Use when creating or restructuring a working-coordination plan file — an
  iterative-work plan shared by user + agent, with no audience beyond them. For published plans
  (design docs, roadmaps, deliverable plans), don't apply this format; ask the user about
  structure instead.
---

A working-coordination plan file should be action-focused — easy to update, easy to resume from.
The format here is for plans the user and agent iterate on together and discard after the work
is done; it's not appropriate for plans intended for a wider audience.

## Before creating: search for overlapping plans

Search the plans directory the new file is going into — all subdirectories except `done/` — for the
new plan's key terms. Note real overlaps in the new plan as a short "Related plans" list. If the new
plan supersedes an existing one, fold its still-live content in and retire it now, rather than
leaving two plans covering one topic.

Also grep `done/` for the same terms — a prior decision recorded there can constrain or contradict
the new plan's design. Cite such records in "Related plans"; never fold or retire them.

## Structure

**Frontmatter** — the plan's lifecycle state, owned by the state script:

```
---
current-step:
  name: "Step 2: <brief label>"
  state: ready-to-implement
---
```

A `refined` list may also appear — steps beyond the pointer already planned to implementable
detail. Read these keys freely; never hand-edit them — write only via
`. "$home/prat/lib/agents/PlanState.ps1"; Set-PlanState ...`. There is no `## Next step:`
heading in this format; the frontmatter pointer replaces it. (Older plans may still have the
heading — treat it as the pointer, migrate it into frontmatter via the script, and delete it.)

**Opening lines** — pointers to companion files (if they exist):
```
See `fooPlan_background.md` for settled design: <one-line summary>. Audience: planning sessions —
step specs are self-contained without it.
See `fooPlan_done.md` for completed steps and design rationale.
```

**Wrap list** — small checklist of things to verify before marking a step done (e.g. "check
changes don't reference private files"). Stays near the top so it's visible when finishing work.

**Steps** — the action units. A step is the unit one `/wrap` closes: planned in one refine pass,
implemented in one session, reviewed in one pass — if it doesn't fit that, split it. Headings
must start with `Step` (e.g. `### Step 2: <brief label>`); the state script locates steps by
matching `^##+ Step`. Label each sub-item `[AGENT]` or `[USER]`. Strike through completed items
inline (`~~item~~ ✓ Done`) rather than deleting them, until the step is fully done — then move
the whole step to `_done.md`.

## Companion files

**`_background.md`** — settled design. Once design discussion closes, move everything between the
opening pointers and the steps here. Audience is planning sessions; implementation sessions
shouldn't need it, because the refine pass makes step specs self-contained — an implementation
session reaching for the background signals an under-specified step. (Older plans may have a
`_ref.md` companion instead — same role; leave the name as is.)

**`_done.md`** — completed steps, preserved for context and rationale. Move a step here once all its items
are struck through. Note: This file lives in `plans/done/YYYY-Qn/`, where YYYY and n give the year and quarter when
the done file was created.

Split content into a companion file when it would make agents re-read stable material every time
they update the plan. If content changes alongside the action steps, keep it in the main file.

If splitting an existing plan file to create a `_background.md`, load `working-with-git` first and
follow the rename pattern: `git mv` the original to the new name, commit as a pure rename, then
write new content in a second change.

## After creating the plan structure

Invoke `start-plan`.
