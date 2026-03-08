# Prat: PRogrammers Automation Tools

Prat (PRogrammers Automation Tools) is a PowerShell-based toolkit for
managing a programmer's dev environment on Windows. Core philosophy:
"one environment for many projects" — instead of separate enlistment
windows, Prat captures and manages each project's environment for use
when needed.

Features:
- **One environment for many projects.** Instead of separate "enlistment windows", Prat captures each 
  project's environment for use when interacting with it.
- **Standardized dev loop** for any project, using build/unit-test/deploy (aliases `b`, `t`, `d`).
  See `Start-CodebaseDevLoop` (alias `x`).
- **Idempotent deployment** via the `Installers` module — deploy is very quick (and quiet) when most/all 
  steps have no work to do, using quick-checks and `OnChange` notifications.
- **Automated config file editing** via the `TextFileEditor` module.

See [INSTALLATION.md](INSTALLATION.md) for installation and customization instructions.

## Dev Loop Commands

```powershell
Test-Project          # alias: t — runs Pester tests; -NoCoverage to skip coverage; -IncludeIntegrationTests to include integration tests; -Integration to run only integration tests
Deploy-Codebase       # alias: d — installs profile, scheduled tasks, Pester
Start-CodebaseDevLoop # alias: x — runs prebuild → build → test → deploy
```

Coverage target is **70%** (defined in
`lib\Get-CoveragePercentTarget_prat.ps1`). Coverage report goes to `auto/testRuns/last/coverage.xml` in CoverageGutters format.
View with `Get-CoverageReport` (alias: `gcr`).

Run a focused subset of tests, add: `-Focus <focus>`, where focus can be a file or directory.

## Architecture

### Three Core Modules (`lib/`)

- **PratBase** — Foundation: environment delta management, git forkpoints, path utilities, disk monitoring, 
  process management. Always loaded.
- **TextFileEditor** — In-memory line-oriented text file editing:
  LineArray class, XML sections, PowerShell hashtable editing. Preserves line endings.
- **Installers** — Idempotent deployment framework:
  `InstallationTracker` class, installation database (`auto/instDb`), staged installs with change tracking.

### Key Patterns

**Repo Profile (`repoProfile.*.ps1`):** Each repo declares its metadata — root dir, build/test/deploy scripts,
navigation shortcuts, workspace definitions, cached env delta path.
`Invoke-ProjectCommand` dispatches actions (prebuild/build/test/deploy) defined in `$project[$CommandName]`
(scriptblock → executed; string → resolved to absolute path and called as script).

**Environment Delta (`lib/PratBase/envDelta.ps1`):** Captures env var changes from batch scripts, 
caches them, and replays them fast — avoiding slow enlistment-window startup. Key functions:
`Export-EnvDeltaFromInvokedBatchScript`, `Invoke-CommandWithCachedEnvDelta`, `Install-CachedEnvDelta`.

**Override Mechanism:** `Get-DevEnvironments` returns layered dev environment descriptors.
`Resolve-PratLibFile` finds overridden files (e.g., `interactiveProfile_<devenv>.ps1`). PATH-based override for
scripts in `pathbin/`.

**Installation Pattern:** All installers use `Start-Installation` / `StartStage` / `EndStage` / `StopInstallation`
with try/catch/finally and `ReportErrorContext`. Idempotent with quick-check support.

### Profile Startup Chain

`installedProfile.ps1` → `profilePicker.ps1` → `scriptProfile.ps1` (aliases, PATH, formatting) →
`interactiveProfile_prat.ps1` (prompt, slow-command tracking, location detection).

### Other Components

- **`pathbin/`** — ~46 utility scripts placed on PATH (navigation, git helpers, testing, dev env management).
- **`lib/autoHotKey/`** — AutoHotKey v2 scripts for Windows automation (editor integration, web search,
  text manipulation).
- **`lib/claude/`** — Fragments assembled into the user-level `~/.claude/CLAUDE.md` by `Install-ClaudeUserConfig`.
- **`lib/schtasks/`** — Scheduled tasks (daily cleanup, on-logon scripts).
- **`auto/`** — Generated artifacts (gitignored): instDb, logs, coverage, cached completions, profile state.

## Testing

Tests are Pester `.Tests.ps1` files colocated with the code they test (e.g., `pathbin/tests/`, within module dirs).
Coverage exclusion comment: `# OmitFromCoverageReport:`. 
`Invoke-PesterAsJob` runs tests in an isolated process.
