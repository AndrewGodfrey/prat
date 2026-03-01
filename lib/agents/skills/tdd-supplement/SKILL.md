---
name: tdd-supplement
description: Supplements superpowers:test-driven-development. Load this after loading the superpowers 'test-driven-development' skill - which is triggered "Use when implementing any feature or bugfix, before writing implementation code"
---

# TDD Supplement

Supplements **superpowers:test-driven-development** with patterns that skill doesn't cover.

## When writing tests: What to validate

Try to validate all 'major' expectations.

e.g. in a test for a feature that deletes old items - verifying that *an* item was deleted is not
as good as verifying that *the oldest* test item was deleted.


## When writing tests: When mocks are unavoidable

The instruction "Tests use real code (mocks only if unavoidable)" needs some context.

Good unit tests are reliable, fast, and avoid inappropriate coupling.

Examples:
- (inappropriate coupling - dependence on configurable values): e.g. if code reads from a configurable source (lib file, env var), mock it — even if the current value happens to match what the test expects. A user changing the config for legitimate reasons should not break the test.

- (inapprpriate coupling - lack of test isolation):
  - e.g. a script writes to a log file in a fixed location. Mock to control the file location. Which might be best accomplished by extracting a small function and then mocking that.

  - e.g. after fixing the above, there was still a directory being created outside the test filesystem. Created
    directories are a bit harder to notice e.g. git focuses on files. But this is still inappropriate.

Counter-example:

- (unreliability): e.g. in a test which sorted directories by CreationTime, two directories created in rapid succession
  could receive identical timestamps (~15ms NTFS resolution). Could maybe have been fixed by some sort of complicated mocking. Was instead fixed by adding Name as a tie-breaker (Name being more under the test's control).


# When writing tests: Consider the blind spot in measured test coverage

Even 100%-instruction-covered code can still be missing validation of basic requirements.
Some common examples:
- Switch/boolean param tested only with one value (false/absent)
- Parameter threaded to a downstream call, never verified at the destination
- Container param tested only when empty
- Collection-processing code tested only with one item (zero and two-plus unchecked)
- Relative path with implicit $pwd dependency
- Numeric edge cases (division by zero, overflow)

The goal is not to test every parameter, but to test every distinct mechanism or assumption. Code review can confirm
that several inputs are handled identically, making one representative test sufficient. The risk is when something
appears structurally identical but has a subtle difference — a different code path, an implicit dependency, a silent
failure mode — that isn't obvious from reading. Those are the cases worth a targeted test.
