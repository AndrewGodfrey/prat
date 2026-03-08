# instructions from 'prat' repo

## Bash tool

- Always use forward slashes in paths, e.g. `C:/Users/foo` not `C:\Users\foo`. Backslashes will be
  misinterpreted.
- When running PowerShell commands via Bash, use `pwsh -c "..."`. Must escape `$`, e.g.
  `pwsh -c "& \$env:USERPROFILE/de/pathbin/Deploy-DevEnvironment.ps1"` — otherwise Bash interpolates
  `$` before pwsh sees it.

## Testing

Write the test first, watch it fail (and how it fails), then implement.

Run tests after any fix, even when confident. Reasons: catches unknown unknowns, and gives the user
evidence rather than just your assurance.

Before changing code with inadequate unit-test coverage, propose adding coverage first.

See the `testing` skill for more detail. Use the `test-and-fix` agent to delegate test-fixing to a
subagent.

When /compact summarizes a session, record the state of each test run (not yet run / verified red /
verified green) alongside file changes. These are distinct states with different implications.

## Debugging

Find root cause before fixing. If three fixes have failed, stop and question the approach rather
than attempting a fourth.

## Code review

No performative agreement ("Great point!", "You're absolutely right!"). Just fix it — actions speak.

For external reviewer suggestions: verify against the codebase before implementing. Push back with
technical reasoning if wrong; the user wants correctness, not compliance.

## Pacing and initiative

Don't prompt for commits or ask "ready to commit?" after each response. The user signals when they're
ready for commit-prep. Repeating the question during iterative work creates a false impression of
impatience.

## Self-improvement

When the user corrects a behavioral mistake, update the relevant file so it doesn't recur:
- Repo-specific facts → that repo's `CLAUDE.md`
- Cross-repo behavioral rules → `prat/lib/agents/agent-user.md`
- User-specific preferences → `de/lib/agents/agent-user.md`
- Triggerable procedures → modify/create a command or agent (or skill, but skill triggering seems unreliable)

Distinguish behavioral corrections ("you didn't X", "why didn't you Y") from one-time task direction
("please also include X in this document"). Test: would a fresh Claude have made the same mistake
without this direction? If yes, capture it. If no, it was context-specific — skip.

Edge case: "please ask me before doing X" sounds one-time but is usually a standing preference — flag
for confirmation before capturing.

## Dev environment

- Managed by the `de` and `prat` repos. Each `de` repo is user-specific. If a user says "the" de repo
  they mean their own one.
- When making a plan, label each step with "[USER]" or "[CLAUDE]" as appropriate.
