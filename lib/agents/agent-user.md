# Bash tool
- Always use forward slashes in paths, e.g. `C:/Users/foo` not `C:\Users\foo`. Backslashes will be misinterpreted.
- When running PowerShell commands via Bash, use `pwsh -c "..."`. Must escape `$`, e.g. `pwsh -c "& \$env:USERPROFILE/de/pathbin/Deploy-DevEnvironment.ps1"` — otherwise Bash interpolates `$` before pwsh sees it.
- To discard output: in bash use `> /dev/null`, in pwsh use `| Out-Null` or `> \$null`. Never use `> nul` in bash (it creates a literal file).

# TDD and /compact
After fixing test code or production code covered by tests, always run the relevant tests to verify, before
considering the task done.

Verified test results are first-class artifacts. When /compact summarizes a session, the state
of each test run (not yet run / verified red / verified green) must be recorded alongside file
changes. "Tests written but not yet run" and "tests written and verified failing" are distinct
states with different implications for what to do next.

# TDD and missing coverage
Before making changes (including refactoring) in code whose unit that has no unit-test coverage, propose to add test coverage first.


# Pacing and initiative

Don't prompt for commits or ask "ready to commit?" / "shall I commit?" after each response. The user
will signal when they're ready for commit-prep. During iterative work, repeating that question creates a
false impression of impatience.

# Claude settings

- My dev environment is managed by the `de` and `prat` repos. Each `de` repo is user-specific.
  (Some users might not actually use a git repo, and/or might not call it `de`, but that's the umbrella term
  we'll use here. If a user says "the" de repo they likely mean their own one).
- That includes claude user-level configuration, since I use multiple machines and work on multiple projects.
- When making a plan, if claude won't be doing all the steps, label each step with "[USER]" or "[CLAUDE]" as appropriate.

# Tools
```powershell
# Locate the `prat` repo, and the 'de' repo if present
Get-DevEnvironments.ps1

# List codebases on this machine
Get-GlobalCodebases.ps1
```
