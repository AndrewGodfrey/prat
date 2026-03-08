---
name: working-with-git
description: Use before using git to make state changes, e.g. before using git to commit, checkout,
  rebase, merge, push, pull, stash.
---

# Figure out what the user expects

This user monitors changes via a git GUI client. This not only visualizes agent changes well, but also
catches e.g. tests that created files in the wrong place.

## If we're not in a development branch

i.e. we're currently on 'main' or 'master': by default, the user expects you to use git only for
reading.

You make the code changes; the user will review. They may then revert, hand-edit, commit, or stage
some or all of the changes. On their next prompt they expect you to detect the modified state.

'use git only for reading' includes git status, git branch, git show, git log.
Don't commit, rebase, checkout, merge, or push without explicit instruction.
Leave the staging area alone — the user often accumulates accepted changes there instead of committing
at every step.

## If we ARE in a development branch

Same default. But if the user asked you to do a series of changes / commits, then commit after each
step. You can assume that if you find yourself in a development branch for the step we're working on,
then committing changes is safe. Still: don't rebase, checkout, merge, or push without explicit
instruction.

When adding or modifying production code in a development branch, run the project's tests before each
commit.

## When you 'git commit'

Prefer single-line commit messages. Depart only when it's important. Follow the pattern
"verb + what you changed", with an optional prefix for context about where the change was made.

Examples:
```
extract script `GetCoverageScope`
simplify `t.sh`
remove `Test-Prat.sh`
tweak `instClaude.ps1`
`prat-run-unit-tests` skill: update to use `t.sh`
`t`/`b` etc: let `-RepoRoot` override the `Get-Location`
`t`: don't require `-Focus` if you use `-RepoRoot`
update docs and comments to reflect recent changes in test params
`instPackages`: sort `$pratPackages`
`md` files: break lines before 120 chars
bootstrap: add a 3rd phase, so we can avoid Windows PowerShell earlier
```

If it seems hard to fit the change into a single line, consider whether the change should be broken
into smaller, more focused commits. If retrospectively splitting already-written passing code, it's
okay to do that without running tests on each individual commit — provided tests pass after the final
split.

A commit in the same area as the previous one, should omit the prefix. Example sequence (from oldest to newest):
```
`instPackages`: Move `forkGitClient` to `$pratPackages` table
Update notes
`Get-CodebaseTable`: Update comments
```