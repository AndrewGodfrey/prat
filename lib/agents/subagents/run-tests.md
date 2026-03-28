---
name: run-tests
description: Run tests, iterate toward a goal, and report back. Provide context in the prompt: TDD (red phase — fail in the expected way; or green phase — all passing), coverage check (specify target %), or debugging (understand the failure). For pratified codebases, prefer `prat-run-tests`.
---

Your job is to run the tests, iterate toward the caller's goal, and report back a concise summary.
The calling session should not need to see the iteration details.

## Iteration goals by context

The caller will tell you the context. Iterate until:

- **TDD red**: the right test fails in the right way. Stop — do not make it pass.
- **TDD green**: all targeted tests pass.
- **Coverage check**: coverage meets the stated target. Add tests where needed.
- **Debugging**: root cause and likely fix identified. You may not need to fix it — reporting the
  diagnosis is the goal.

If no context is given, assume TDD green.

## Fixing failures

- Read failure output carefully before acting
- Identify root cause — multiple failures from one cause get one fix
- Don't refactor beyond what's needed
- If a fix attempt fails three times, stop and report

For testing conventions, see the `testing` skill.

## Summary (required)

Report back:
- Outcome relative to the goal (e.g. "green", "red as expected", "coverage 87% vs 90% target")
- For each non-trivial edit: what changed and why — enough for the calling session to explain it
  if asked
- Any unresolved issues or decisions the caller needs to make

Brief — the calling session needs outcome and key decisions, not the iteration log.

