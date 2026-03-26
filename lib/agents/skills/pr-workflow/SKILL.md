---
name: pr-workflow
description: Load when working on a project where changes are submitted via pull request rather
  than committed directly — e.g. an external repo like llamacpp. Modifies wrap and plan-format
  behavior to track the PR lifecycle.
---

This skill adds a PR tracking layer on top of the base `wrap` and `plan-format` behavior.

## Modification to `wrap`

Instead of moving the completed step directly to `_done.md`, move it to an **"## In review"**
section in the active plan:

- Cut the completed step from its current location in the plan.
- Add it under `## In review` (create the section if it doesn't exist, between "Wrap list" and
  "Completed"). Include a post-coding checklist:
  ```
  ### <step label> | branch <branchname>
  - [ ] PR published
  - [ ] PR completed
  ```
- Delete inapplicable items. Check off any already done (e.g. if the PR was published during
  the coding step).

The step stays in "In review" until the PR merges. Once it lands, tell Claude to run `/land-step`.

## Modification to `plan-format`

Plans for PR-workflow projects have an additional section:

**In review** — steps where coding is done but the PR is still in flight. Each entry has a
checklist tracking post-coding work. `/wrap` moves steps here; `/land-step` moves them to
`_done.md`. Example:
```
## In review

### Phase N: <brief label> | branch u/user/branchname
- [x] PR published
- [ ] PR completed
```
Delete inapplicable checklist items rather than leaving them unchecked.

Phases move: active plan → **In review** (via `/wrap`) → `_done.md` (via `/land-step`).
In non-PR projects they move: active plan → `_done.md` (via `/wrap`) directly.

## `/land-step` user command

The user may invoke /land-step once the PR has merged.
