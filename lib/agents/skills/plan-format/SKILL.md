---
name: plan-format
description: Use when creating or restructuring a working-coordination plan file — an
  iterative-work plan shared by user + agent, with no audience beyond them.
---

For published plans (design docs, roadmaps, deliverable plans), don't apply this format; 
ask the user about structure instead.

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
current-unit:
  first: "Step 2: <brief label>"
  state: ready-to-implement
workflow: tick-tock              # the user's to declare; omitting it means this value
---
```

`current-unit` points at a contiguous run of one or more steps. A single-step unit writes down only
`first`; a batched multi-step unit adds `last` (see PlanState.ps1's header for the design
rationale). A `refined` list may also appear — steps beyond the pointer already
planned to implementable detail. Read these keys freely; never hand-edit `state`/`refined` —
write only via `. "$home/prat/lib/agents/PlanState.ps1"; Set-PlanState ...`. When you finish
refining a step, set `ready-for-refined-step-review`, in every mode. Whether you may then advance to
`ready-to-implement` yourself is what `workflow` decides: in `tick-tock` only the user may, through
`/wrap`, which records their approval of the refined step — so a new or reworked unit stays at
`ready-for-refined-step-review` however settled its design felt in conversation. `last` is set by
manual frontmatter edit when declaring a multi-step unit, and is written down only when it differs
from `first` — see PlanState.ps1's header. Once declared, re-point such a unit with `-First` and
`-Last` together; `-First` alone is refused there, and moves both ends of a single-step unit.

`workflow` is declared by hand beside `current-unit`; `Set-PlanState` carries it but never writes
it. It names which of three ways of working the plan runs in, and they differ only in who may
advance the state:

- `tick-tock` — the user reviews the refined step and the work. Absent or unrecognized values mean
  this one, since loosening what a session may do needs a value we recognize.
- `step-review` — the agent refines and implements; the user reviews the work.
- `branch-review` — the agent refines, implements and commits a run of steps; the user reviews the
  branch.

The value is a mode name, not a loadable skill — do not `load_skill` it; each mode's behavior
lives in the skills for the states it passes through.

The same split governs the closing checkpoint (`ready-for-user-review`, where `/wrap` moves the unit
to `_done.md` and advances the pointer): in `tick-tock` and `step-review` only the user invokes
`/wrap`, recording their review of the work; in `branch-review` the agent invokes it itself, at the
close of every step, since the user isn't there to. That closing `/wrap` still runs `/reflect` with no
code changes even in `branch-review`, where nobody has reviewed a diff yet — the review happens across
the whole branch afterward instead, so a fix landing here would still reach the user unreviewed.

There is no `## Next step:` heading in this format; the frontmatter pointer replaces it. 
(Older plans may still have the heading, or the older single-pointer `current-step` shape — treat
either as the pointer, migrate it into `current-unit` frontmatter via the script, and delete any
leftover heading.)

**Opening lines** — pointers to companion files (if they exist):
```
See `fooPlan_background.md` for settled design: <one-line summary>. Audience: planning sessions —
the refined steps are self-contained without it.
See `fooPlan_done.md` for completed steps and design rationale.
```

**Wrap list** — small checklist of things to verify before marking a step done (e.g. "check
changes don't reference private files"). Stays near the top so it's visible when finishing work.

**Steps** — the action items. A step is planned in one refine pass and implemented in one session
— if it doesn't fit that, split it. `/wrap` closes a **unit**: by default one step, or a
user-declared contiguous run of several when batching (see "Frontmatter" above). Headings must
start with `Step` (e.g. `### Step 2: <brief label>`); the state script locates steps by matching
`^##+ Step`. Label each sub-item `[AGENT]` or `[USER]`. Mark a completed item by prefixing it
`[ ✓ Done ]` rather than deleting it, until the step is fully done — a prefix, not strikethrough,
because `~~` doesn't span the line breaks a multi-line item has. Then move the whole
step (or, for a multi-step unit, all its steps) to `_done.md`. Renumbering steps silently re-points
`current-unit` and `refined` at different work — the state script keys a step on `Step N` and
ignores the title — so re-write both through `Set-PlanState -First` (plus `-Last` for a batched
unit) and `-Refined` after a renumber.

A run spent working the steps out — restructuring what's left, splitting one, changing direction —
has no `/wrap`: `/wrap` is approval to move on from a unit, and such a run may have refined nothing.
It writes the pointer and `refined` through `Set-PlanState` as it goes, and ends when the shape is
right.

## Companion files

**`_background.md`** — settled design. Once design discussion closes, move everything between the
opening pointers and the steps here. Audience is planning sessions; implementation sessions
shouldn't need it, because the refine pass makes a step self-contained — an implementation
session reaching for the background signals an under-specified step. (Older plans may have a
`_ref.md` companion instead — same role; leave the name as is.)

**`_done.md`** — completed steps, preserved for context and rationale. Move a step here once all its items
are struck through. This file lives in `plans/done/YYYY-Qn/` (year and quarter when the done file was
created) from the moment it's created — even while the plan is still active. It never sits alongside
the plan file.

Split content into a companion file when it would make agents re-read stable material every time
they update the plan. If content changes alongside the action steps, keep it in the main file.

If splitting an existing plan file to create a `_background.md`, load `working-with-git` first and
follow the rename pattern: `git mv` the original to the new name, commit as a pure rename, then
write new content in a second change.

## After creating the plan structure

Invoke `start-plan`.
