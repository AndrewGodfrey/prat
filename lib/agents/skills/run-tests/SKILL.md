---
name: run-tests
description: Use in non-pratified codebases, when doing TDD, running tests after code changes, checking coverage, or debugging test failures. For pratified codebases, use `pratified-dev-loop` instead.
---

# Running tests

Prefer the project's documented invocation over calling the test framework
directly — it handles environment setup and avoids parameter-set pitfalls.

## Fixing failures

- Read failure output carefully before acting
- Identify root cause — multiple failures from one cause get one fix
- Don't refactor beyond what's needed
- If a fix attempt fails three times, stop and report to the user

For testing conventions, see the `testing` skill.
