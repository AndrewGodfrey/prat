---
name: working-in-prat
description: Use when doing any work in the prat codebase or in repos layered on top of prat
  (e.g. `de`, `prefs`) — reading, modifying, debugging, understanding code, or analyzing deploy
  scripts that use prat's package or installer system.
---

## Installers framework conventions

When writing `install` scriptblocks in `$pratPackages`, add `$stage.SetSubstage("description")`
before each long-running operation (network downloads, elevated installs, etc.) to give the user
progress visibility.

Also, for architecture overview, dev loop commands, and codebase structure: read @`$HOME/prat/README.md`

## Deploy stages

### Forcing a deploy stage to re-run

Some deploy stages track state in instDb files. For those, to force a re-run:
`rppr <stepId> && d`. The step ID is the file path within the instDb directory (without the version suffix).
- For stages using `GetIsStepComplete` directly, the step ID is the string before the `:` — e.g. `rppr agentDeploy`.
- For `Install-PratPackage`, the step ID is `pkg/{packageId}` — e.g. `rppr "pkg/python"`.
  This differs from the stage name passed to `StartStage` (`Install-PratPackage(python)`).

### Removing a deploy stage

When removing code that previously deployed an artifact, add a migration step that cleans up
existing deployments on other machines. The local machine isn't the only consumer of `d`.

Migration step pattern: call `$stage.NoteMigrationStep((Get-Date "YYYY-MM-DD"))` (today's date),
then use idempotent checks (e.g. `if (Test-Path ...)`) before making changes. The framework warns
after 30 days — signal to remove the step.

## Repo registry merge semantics

`Get-PratRepoIndex` (`lib/PratBase/pratRepos.ps1`) merges same-id repo entries across
`codebaseProfile_*.ps1` files by whole-node replacement (last file processed wins), not per-field —
unlike shortcuts, which have explicit first-file-wins protection. A repo's own file is always
processed last for its own id, so a field a public repo (e.g. prat, prefs) declares on its own
entry can never be overridden by a downstream clone. Before adding a field to a repo's own entry,
check whether that repo is public/multi-clone — if so, have consumers hand-list it instead of
relying on the registry.

## Layered config: finding all contributors

Layer fragments are discovered by *filename* (`Resolve-PratLibFile 'lib/inst/Get-X.ps1' -ListAll`
returns every layer's `Get-X_<layer>.ps1`), and a fragment's content needn't mention its own name —
so content-grepping for the base name can miss contributors entirely. To enumerate them, glob for
the filename pattern across the layer repos, or read the generated artifact (e.g.
`~/.claude/settings.json`), which shows every fragment's contribution merged.
