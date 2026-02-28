---
name: finishing-a-development-branch-supplement
description: Supplements superpowers:finishing-a-development-branch. Use to decide how to integrate the work
---

# Figure out what the user expects

This user uses a git client, 'fork.dev', to monitor changes in the repo. This not only visualizes agent changes well,
but also catches e.g. tests that created files in the wrong place. So:


## If we're not in a development branch

i.e. we're currently on 'main' or 'master': by default, the user expects you to use git only for reading.

You make the code changes; the user will review. They may then revert, hand-edit, commit, or stage some or all of the 
changes. On their next prompt they expect you to detect the modified state. (Speak up if we should develop a tool to
reliably & concisely pick that up).

'use git only for reading' includes git status, git branch, git show, git log.
'git add' for new files would be safe but this user doesn't need it (fork.dev handles it).
Don't commit, rebase, checkout, merge, or push without explicit instruction.
Also leave the staging area alone - the user often accumulates accepted changes there instead of committing at
every step.
  

## If we ARE in a development branch
Same default. But if the user asked you to do a series of changes / commits, then by all means commit after each step.
You can assume that if you find yourself in a development branch for the step we're working on, then committing changes
is safe. Still: don't rebase, checkout, merge, or push without explicit instruction.


## When you 'git commit'

Prefer single-line commit messages. Depart only when it's important. The first/only should follow the pattern of
"verb + what you changed", with an optional prefix where it's helpful context for 'where' the change was made.

Some examples (these are idealized edits of past commits):

```
extract script `GetCoverageScope`
simplify `t.sh`
remove `Test-Prat.sh`
tweak `instClaude.ps1`
`prat-run-unit-tests` skill: update to use `t.sh`
`t`/`b` etc: let `-RepoRoot` override the `Get-Location`
`t`: don't require `-Focus` if you use `-RepoRoot`
`t`: add the parameters that `Test-Prat` has
update docs and comments to reflect recent changes in test params
`gll`, `glp`: use `@args`
`Test-Prat`: make it reusable from another repo
`instPackages`: sort `$pratPackages`
`claude-user-md`: note how to find prat and de
`md` files: break lines before 120 chars
`Install-SoftLinkToFile`: fix some missing `using:` in a sudo scriptblock
bootstrap: add a 3rd phase, so we can avoid Windows PowerShell earlier
```
