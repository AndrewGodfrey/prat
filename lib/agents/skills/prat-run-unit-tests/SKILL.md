---
name: prat-run-unit-tests
description: Use when doing TDD, running tests after code changes, checking coverage, or debugging test failures in the prat codebase.
---

# Run Prat Unit Tests

Use the `t` bash script with `-RepoRoot` — no `cd` required.
Permission is granted as `Bash(t *)`.

## Common Invocations

```bash
t -RepoRoot ~/prat                                                   # full suite, with coverage
t -RepoRoot ~/prat -NoCoverage                                       # full suite, skip coverage
t -RepoRoot ~/prat -Focus lib/Something                              # focus on a directory
t -RepoRoot ~/prat -Focus lib/Foo.Tests.ps1                          # focus on a test file
t -RepoRoot ~/prat -Focus lib/Foo.Tests.ps1 -NoCoverage -Debugging   # debug a failing test
t -RepoRoot ~/prat -Integration -NoCoverage                          # run only integration-tagged tests
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-RepoRoot <path>` | Codebase to test; also sets the default test scope when `-Focus` is omitted |
| `-Focus <path>` | Test scope: file or directory relative to repo root; coverage scope derived automatically |
| `-NoCoverage` | Skip coverage (faster for rapid iteration) |
| `-Integration` | Run only `[Integration]`-tagged tests (mutually exclusive with `-IncludeIntegrationTests`) |
| `-IncludeIntegrationTests` | Run all tests including integration tests (default excludes them) |
| `-Debugging` | Full Pester diagnostic output, no filtering — always pair with a tight `-Focus` |
| `-IncludeIntegrationTests` | Run unit tests AND integration tests |
| `-Integration` | Run only integration-tagged tests (skips unit tests) |
| `-OutputDir <path>` | Where to write output files (default: `auto/`); files go under `testRuns/last/` |

## Output modes

Default (no switches): smart filter — `[+]` file lines shown live; failure blocks and summary shown
after the run. Quick to scan; full details in `auto/testRuns/last/test-run.txt` if needed.

`-Debugging`: unfiltered Pester Diagnostic output. Use when diagnosing a tricky failure; always
pair with `-Focus` to avoid overwhelming output.

## Cached Summary vs. Fresh Run

Read `auto/testRuns/last/test-run-summary.txt` instead of re-running when:
- No code has changed since the last run
- You only need the pass/fail count or coverage %

Run fresh after any code change.

## Output Files

Every run writes to `auto/testRuns/last/`:

| File | Contents |
|------|----------|
| `test-run.txt` | A copy of the console output |
| `test-run-summary.txt` | One-line summary: coverage % and pass/fail counts |
| `coverage.xml` | Coverage data in CoverageGutters format (omitted when using -NoCoverage) |

Previous runs are rotated to `auto/testRuns/<timestamp>/` and pruned to 1 kept by default
(configurable via `lib/Get-TestRunRetention_prat.ps1`).

When there are test failures, the summary output includes a hint with the path to `test-run.txt`.
If failures exceed the display threshold (5), the suppressed count is shown alongside the hint.

## Coverage

- Runs by default; written to `auto/testRuns/last/coverage.xml` (CoverageGutters format)
- Coverage scope is inferred: a directory covers itself; a single `.Tests.ps1` file covers
  its corresponding production file
- Skip with `-NoCoverage` during rapid iteration; run a final full-coverage pass when done

### Querying coverage.xml

CoverageGutters format uses **absolute paths** for package names and **leaf-only** sourcefile names.
Coverage file is at `auto/testRuns/last/coverage.xml` by default.
To find uncovered lines for e.g. `lib/Installers/instClaude.ps1`:

```
<package name="C:/Users/you/prat/lib/Installers">   ← absolute path of directory
  <sourcefile name="instClaude.ps1">                 ← leaf filename only
    <line nr="5" mi="1" ci="0" .../>                 ← mi=missed, ci=covered instructions
```

XPath: `//package[@name='C:/Users/you/prat/lib/Installers']/sourcefile[@name='instClaude.ps1']/line[@mi!='0']`

Or in two steps: find the `<package>` whose `name` ends with your directory, then find the
`<sourcefile>` by leaf name within it. Don't search by leaf name alone — different directories
could share a filename.

## Per-Function Coverage

After a test run, use `Get-FileCoverage` to see which functions in a file need attention:

```powershell
Get-FileCoverage -FilePath "C:\path\to\File.ps1"               # uses auto/testRuns/last/coverage.xml
Get-FileCoverage -FilePath "C:\path\to\File.ps1" -CoverageFile "path/to/coverage.xml"
```

Output — one row per function:

```
Function       Line  Covered  Missed
<script>          1       10       0
Get-Something    20        2       8   ← needs attention
Set-Something    35        0       6   ← uncovered
```

For line-range coverage:

```powershell
Get-FileCoverage -FilePath "C:\path\to\File.ps1" -Detail
```

Output:
```
Function                 StartLine EndLine Status
--------                 --------- ------- ------
<script>                        26      27 missed
TryAdd                          35      36 missed
FindShortcut                    62      71 covered
ReverseSearchForShortcut        75      86 missed
ReverseSearchForShortcut        89      94 covered
ReverseSearchForShortcut        95      95 missed
ReverseSearchForShortcut        98      98 covered
```

**Do not append `2>&1`** to `t` invocations — the Bash tool already captures both stdout and stderr.

**Avoid invoking `Invoke-Pester` or `pwsh -c` directly** — reasons:
- Pester 5 parameter sets are tricky
- `pwsh -c "..."` requires escaping every `$` which agents consistently get wrong.
- Using the `t` bash script is more user-friendly — the user can issue the same command easily (e.g. using the equivalent `t` Pwsh alias).
