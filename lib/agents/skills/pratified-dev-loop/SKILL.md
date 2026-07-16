---
name: pratified-dev-loop
description: Use in any pratified project for build/test/deploy/prebuild work — b, d, pb, t with
  absolute-path support and coverage tools.
---

How to pratify a project? See the `pratify-a-project` skill.

# Dev loop tools

`b`, `d`, `pb`, and `t` all accept an absolute path as the first positional arg and auto-derive
the project — no `cd` required.

```bash
b ~/prat                        # build from any CWD
b ~/prat/lib/Foo.ps1            # partial build scoped to a subdir
d ~/prat                        # deploy from any CWD
pb ~/prat                       # prebuild from any CWD
t ~/prat/lib/Foo.Tests.ps1      # test from any CWD
```

`b` accepts a subdir for partial builds. `d` and `pb` require the exact project root — they throw
if given a subdirectory. To use a non-default build command: `b -CommandName clean`.

# Running tests

Use the `t` bash script with an absolute path — no `cd` required.
Permission is granted as `Bash(t *)`.

`t` works for any pratified codebase. It dispatches to the appropriate runner
(Pester for `.Tests.ps1`, `dotnet test` for `.csproj`) based on the target.

```bash
t ~/prat                                            # full Pester suite, with coverage
t ~/prat/lib/Something -NoCoverage                  # focus on a directory
t ~/prat/lib/Foo.Tests.ps1 -NoCoverage              # focus on a test file
t ~/prat -Integration -NoCoverage                   # run only integration-tagged tests
t foo/myproject                                     # .NET (csproj directory)
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

## Integration-tagged tests are excluded by default

Without `-Integration`/`-IncludeIntegrationTests`, tests tagged `Integration` are filtered out
and counted as **NotRun** — visible in `test-run.txt` but not in the console one-liner, whose
"Passed" count therefore understates the discovered total. Before treating a passed-count drop
across runs as a regression, check `test-run.txt` for the NotRun count.

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

- "CoverageGutters format" means one that the vscode coverage-gutters extension can read. It can
  read JaCoCo or Cobertura, but with particular requirements.

Previous runs are rotated to `auto/testRuns/<timestamp>/`.

When there are test failures, the summary output includes a hint with the path to `test-run.txt`.

## Coverage

Runs by default. Scope is inferred: a directory covers itself; a `.Tests.ps1` file covers its
corresponding production file. Use `-NoCoverage` during rapid iteration.

Use `Get-FileCoverage -FilePath "C:\path\to\File.ps1"` for a per-function summary.
Use `Get-FileCoverage -Detail -FilePath "C:\path\to\File.ps1"` for a line-range summary.

Both `Get-FileCoverage` and `gcr` infer the coverage file from the target's git repo root and prat
project — `<repoRoot>/auto/testRuns/[<subprojectId>/]last/coverage.xml` — including the subproject
segment when the target is inside a registered subproject. To point at a different run, pass the
file explicitly: `Get-FileCoverage ... -CoverageFile <path>` / `gcr -coverageFile <path>`.

`Get-CoverageDetails` and `gcr` support JaCoCo/CoverageGutters and Cobertura XML formats.

## Fixing Failures

- Read failure output carefully before acting
- Identify root cause — multiple failures from one cause get one fix
- Don't refactor beyond what's needed
- If a fix attempt fails three times, stop and report to the user

For testing conventions, see the `testing` skill.
