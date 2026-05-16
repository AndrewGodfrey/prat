---
name: prat-run-tests
description: Use in any pratified codebase, when doing TDD, running tests after code changes, checking coverage, or debugging test failures.
---

# Running tests

Use the `t` bash script with an absolute path — no `cd` required.
Permission is granted as `Bash(t *)`.

```bash
t ~/prat                                        # full suite, with coverage
t ~/prat/lib/Something -NoCoverage              # focus on a directory
t ~/prat/lib/Foo.Tests.ps1 -NoCoverage          # focus on a test file
t ~/prat -Integration -NoCoverage               # run only integration-tagged tests
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Focus <path>` | File or directory; if absolute, repo is auto-derived; if relative, uses CWD |
| `-NoCoverage` | Skip coverage (faster for rapid iteration) |
| `-NoBuild` | Skip build step |
| `-Integration` | Run only integration-tagged tests |
| `-IncludeIntegrationTests` | Run unit tests AND integration tests |
| `-UseAlternateCollector` | Use `dotnet-coverage` instead of `coverlet` (Pester: emits warning, continues) |
| `-OutputDir <path>` | Direct parent of `last/` run dir (default: `auto/testRuns/`) |

**Avoid invoking `Invoke-Pester` or `pwsh -c` directly** — reasons:
- Using the `t` bash script is more user-friendly — the user can issue the same command easily
- `pwsh -c "..."` requires escaping every `$` which agents consistently get wrong
- Pester 5 parameter sets are tricky

## Cached summary vs. fresh run

Read `auto/testRuns/last/summary.txt` instead of re-running when no code has changed and you only
need pass/fail count or coverage %. Run fresh after any code change.

## Output files

Every run writes to `auto/testRuns/last/`:

| File | Contents |
|------|----------|
| `test-run.txt` | A copy of the console output |
| `summary.txt` | One-line summary: coverage % and pass/fail counts |
| `coverage.xml` | Coverage data, in CoverageGutters format (omitted when using `-NoCoverage`) |

- "CoverageGutters format" means one that the vscode coverage-gutters extension can read. It can read JaCoCo or Cobertura,
  but with particular requirements.

Previous runs are rotated to `auto/testRuns/<timestamp>/`.

When there are test failures, the summary output includes a hint with the path to `test-run.txt`.

## Coverage

Runs by default. Scope is inferred: a directory covers itself; a `.Tests.ps1` file covers its
corresponding production file. Use `-NoCoverage` during rapid iteration.

Use `Get-FileCoverage -FilePath "C:\path\to\File.ps1"` for a per-function summary.
Use `Get-FileCoverage -Detail -FilePath "C:\path\to\File.ps1"` for a line-range summary.

Both `Get-FileCoverage` and `gcr` infer the coverage file from the git repo root: `<repoRoot>/auto/testRuns/last/coverage.xml`.
For projects with a separate coverage subdirectory (e.g. a subproject), use `-Project`:

```powershell
gcr -Project myproject
Get-FileCoverage -FilePath "C:\path\to\File.cs" -Project myproject
```

`-Project <id>` resolves to `<repoRoot>/auto/testRuns/<id>/last/coverage.xml`.

`Get-CoverageData` and `gcr` support JaCoCo/CoverageGutters and Cobertura XML formats.

## Fixing Failures

- Read failure output carefully before acting
- Identify root cause — multiple failures from one cause get one fix
- Don't refactor beyond what's needed
- If a fix attempt fails three times, stop and report to the user

For testing conventions, see the `testing` skill.
