---
name: testing
description: Load before making any change to project code (excluding plan documents).
---

This skill covers the "Testing" section of agent-user.md in more detail.

## What to validate

Validate all major expectations, not just surface ones. Example: a test for a feature that deletes the
oldest item should verify *which* item was deleted, not just that *an* item was deleted.

## Mocks vs real dependencies

Good unit tests are **reliable and fast**. Whether to mock or use the real thing follows from that —
not from rules about categories of I/O.

Use the real thing when it's controllable, fast, and reliable: file I/O in an isolated temp dir, a
loopback service, an in-memory database. These test real behavior without coupling to implementation
details. A test using a heavyweight real dependency (e.g. a full in-memory SQL engine) might
reasonably be called an integration test even if it runs in the unit test framework — the label
reflects speed and scope, not the tooling.

Mock when the real thing would make tests slow, flaky, or uncontrollable: live network endpoints,
fixed system paths, uncontrollable external state.

Specific cases:
- **Configurable values** (lib file, env var): mock even if the current value happens to match — a
  user changing config for legitimate reasons should not break the test.
- **Fixed output locations** (e.g. a hardcoded log path): mock to control the location, often by
  extracting a small function. Also watch for directories created outside the test filesystem —
  harder to spot than files.
- **Flaky real dependencies**: don't mock to paper over flakiness — fix the root cause (better
  tie-breaker, better test data, better isolation) instead.

Anti-patterns:
- **Mocking without understanding**: before replacing something with a mock, understand what side
  effects the real thing has. Mocking without that understanding produces tests that pass while the
  real behavior is broken.
- **Mock calls as a proxy**: don't assert on mock calls as a proxy for behavior you could assert more
  directly. If the function's job is to produce an output, assert on the output — not on how the
  internals got there. (When the call itself *is* the observable outcome, asserting on it is fine.)

## Coverage blind spots

100%-instruction-covered code can still miss basic requirements. Common gaps:

- Switch/boolean param tested only with one value
- Parameter threaded to a downstream call but never verified at the destination
- Container param tested only when empty
- Collection-processing code tested only with one item (zero and two-plus unchecked)
- Relative path with implicit current-directory dependency
- Numeric edge cases (zero, overflow)

The goal is not to test every parameter, but to test every distinct mechanism or assumption. When
several inputs are structurally identical, one representative test is enough — but watch for inputs
that *appear* identical while hiding a different code path, implicit dependency, or silent failure mode.

## Test isolation

Use an auto-managed temp directory rather than hardcoded paths. Test frameworks typically provide one
(e.g. Pester's `TestDrive:`, pytest's `tmp_path`). These are real filesystem directories with
automatic cleanup and a unique path per run — not a special isolated environment. The benefit is
cleanup and uniqueness, not deep isolation.

Note: Pester's `TestDrive:` is a PS provider path. Anything that doesn't accept PS provider notation
needs a resolved real path: `(Get-Item "TestDrive:\subpath").FullName` or `Resolve-Path`.

### Pester 5 gotchas

**`TestDrive:` is shared within a `Context` block** — it is NOT reset between `It` blocks. Use distinct
subdirectory paths per test (e.g. `"TestDrive:\db-test1"`, `"TestDrive:\db-test2"`) to avoid
cross-test contamination when multiple tests in the same `Context` write to the filesystem.

**`InModuleScope` + `-Focus`**: `InModuleScope` is evaluated at discovery time, but `BeforeAll` runs
at execution time. When the focused file is the first to be discovered, the module isn't loaded yet
and discovery fails. Fix: add a `BeforeDiscovery` block (in addition to `BeforeAll`) to load the
module at discovery time:

```powershell
BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}
BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}
```

## Writing tests

If a test is hard to write, that's feedback: the design may be too complex. Consider simplifying the
production code before forcing the test to fit.

Red flag: a test passes when you expected it to fail — either the test is wrong, or the behavior was
already present somewhere unexpected. Investigate before proceeding.

## Mid-task verification

Any message describing a change you just made is a verification moment — not just the final one. Run
tests *before* narrating, not after.

If the change is clearly scoped, run just the relevant test file. If in doubt, run the full suite.

If the user has to ask "did you run the tests?" — you didn't run them at the right time.

Tests passing isn't sufficient if there are new warnings or errors in the output.

## Commit messages
Extending the "area: verb details" format: It's often useful to commit "Red: area: verb details"
followed by simply "green", meaning "area: verb details" is now implemented.
OTOH sometimes things don't go as planned, so put more details in the "green" message to signal that.

