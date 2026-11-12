---
name: pr-workflow
description: Use before creating a working plan or closing completed work to combine repository
  and user per-repository publication policies. Defaults to pull requests, with explicit
  direct-commit exceptions. Modifies wrap and plan-format behavior for work requiring PRs.
---

## Resolve effective publication policy

Determine policy for the current contributor in each source repository being changed, independently
of the agent role or the directory holding the plan/session. Combine the repository's publication
policy (`AGENTS.md` / `CLAUDE.md`) with the user's per-repository policy from personal or explicit
instructions to resolve the effective publication policy for these changes. A contributor-specific exception
applies only to that contributor's changes; it does not change the workflow for external contributions.
If requirements conflict without an applicable explicit exception, ask the user to resolve the conflict.
When neither policy specifies a workflow, default to pull requests.

An explicit direct-commit policy (including a wiki-like documentation workflow) uses the base
`wrap` and `plan-format` behavior; the PR modifications below do not apply to the covered changes.
Do not infer a direct-commit exception merely because a repository contains documentation.
For multi-repository work, track PRs only for changes whose effective policy requires them.

If a unit mixes work requiring PRs with work covered by a direct-commit policy, keep one entry in "In review"
until all required PRs merge. Record the direct-commit changes in that entry too; do not copy
the unit into both "In review" and `_done.md`.

Publication policy does not authorize staging, committing, pushing, or creating a PR. Follow
the user's authorization for those operations separately.

For work requiring PRs, this skill adds a PR tracking layer on top of the base `wrap` and
`plan-format` behavior.

## Modification to `wrap`

Instead of moving the completed step directly to `_done.md`, move it to an **"## In review"**
section in the active plan:

- Cut the completed step from its current location in the plan.
- Add it under `## In review` (create the section if it doesn't exist, between "Wrap list" and
  "Completed"). Drop the leading `Step N: ` from the heading — the state script counts any
  `^##+ Step` heading as remaining work, and in-review entries aren't. Include a post-coding
  checklist:
  ```
  ### <brief label> | branch <branchname>
  - [ ] PR published
  - [ ] PR completed
  ```
- Delete inapplicable items. Check off any already done (e.g. if the PR was published during
  the coding step).

The step stays in "In review" until the PR merges. Once it lands, tell the agent to run `/land-step`.

## Modification to `plan-format`

Plans containing work requiring PRs have an additional section:

**In review** — steps where coding is done but the PR is still in flight. Each entry has a
checklist tracking post-coding work. `/wrap` moves steps here; `/land-step` moves them to
`_done.md`. Example:
```
## In review

### <brief label> | branch u/user/branchname
- [x] PR published
- [ ] PR completed
```
Delete inapplicable checklist items rather than leaving them unchecked.

Steps move: active plan → **In review** (via `/wrap`) → `_done.md` (via `/land-step`).
For work covered entirely by a direct-commit policy, they move: active plan → `_done.md` (via `/wrap`) directly.

## `/land-step` user command

The user may invoke /land-step once the PR has merged.
