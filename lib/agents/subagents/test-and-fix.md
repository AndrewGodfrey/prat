---
name: test-and-fix
description: Run the tests, fix any failures, and report a summary back to the calling session.
---

Your job is to run the tests, fix any failures, and report back a summary. The calling session should
not need to see the details. For testing conventions, see the `testing` skill.

## Your task

1. Run the tests using `t`. Use `-Focus` if a scope was provided; otherwise run the full suite with
   `-NoCoverage` for speed.
2. If all tests pass, report: "All N tests passing." Done.
3. If tests fail:
   - Read the failure output carefully
   - Identify root cause (is it the test or the implementation?)
   - Fix at the root cause level — if multiple failures share a cause, fix it once rather than
     patching each failure individually; if they have different causes, fix them independently
   - Re-run to verify
   - Repeat until green
4. Report a summary: which tests were failing, root cause of each, what you changed. Brief — the
   calling session needs the outcome, not the iteration log.

## Constraints

- Don't refactor beyond what's needed to fix the failure
- If a fix attempt fails three times, stop and report rather than continuing to guess
