---
name: verification-supplement
description: Supplements superpowers:verification-before-completion. Use when modifying existing code that already has test coverage.
---

# Verification Supplement

Supplements **superpowers:verification-before-completion**: that skill triggers
before commits and PRs. This covers the gap *mid-task*.

## Run Tests Before presenting a code edit to the user

Any message describing a change you just made is a verification moment — not just
the final one. Run tests *before* narrating, not after.

Depending on the change, it might be easy to know that only one or a few test files were affected, so you could run just those. But if in doubt, run the full suite.

**Trigger:** "I've changed X" / "I've extracted Y" / "I've added Z" → run tests before returning to the user.

If the user has to ask "did you run the tests?" — you didn't run them at the right time. (And consider whether you can suggest an update to this skill).
