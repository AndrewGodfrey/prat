---
name: prat-run-unit-tests
description: Use when doing TDD, running tests after code changes, checking coverage, or debugging test failures in the prat codebase.
---

# Run Prat Unit Tests

Use `Test-Prat.sh` — it handles the prat root automatically, no `cd` required.
Grant permission as `Bash(Test-Prat.sh *)`.

## Common Invocations

```bash
Test-Prat.sh                                                              # full suite, with coverage
Test-Prat.sh -NoCoverage                                                  # full suite, skip coverage
Test-Prat.sh -Focus lib/Something                                         # focus on a directory
Test-Prat.sh -Focus lib/Foo.Tests.ps1                                     # focus on a test file
Test-Prat.sh -Verbosity Summary                                           # pass/fail + coverage % only
Test-Prat.sh -Focus lib/Foo.Tests.ps1 -NoCoverage -Verbosity Debugging    # debug a failing test
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Focus <path>` | Test scope: file or directory; coverage scope derived automatically |
| `-NoFocus` | Ignore saved focus state, run full suite |
| `-NoCoverage` | Skip coverage (faster for rapid iteration) |
| `-Verbosity <level>` | `Summary` / `Normal` (default) / `Debugging` |
| `-OutputDir <path>` | Where to write output files (default: `auto/`); files go under `testRuns/last/` |

## Verbosity

| Level | Use when |
|-------|----------|
| `Summary` | Quick pass/fail check — outputs one line from `auto/testRuns/last/test-run-summary.txt` |
| `Normal` | Default — file names, failure details, counts |
| `Debugging` | Diagnosing a failure — always pair with a tight `-Focus` |

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
<package name="C:/Users/andrew/prat/lib/Installers">   ← absolute path of directory
  <sourcefile name="instClaude.ps1">                   ← leaf filename only
    <line nr="5" mi="1" ci="0" .../>                   ← mi=missed, ci=covered instructions
```

XPath: `//package[@name='C:/Users/andrew/prat/lib/Installers']/sourcefile[@name='instClaude.ps1']/line[@mi!='0']`

Or in two steps: find the `<package>` whose `name` ends with your directory, then find the
`<sourcefile>` by leaf name within it. Don't search by leaf name alone — different directories
could share a filename.

## Per-Function Coverage

After a test run, use `Get-FileCoverage` to see which functions in a file need attention:

```powershell
Get-FileCoverage -FilePath "C:\path\to\File.ps1"               # uses auto/coverage.xml
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

**Avoid invoking `Invoke-Pester` or `pwsh -c` directly** — reasons:
- Pester 5 parameter sets are tricky
- `pwsh -c "..."` requires escaping every `$` which agents consistently get wrong.
- Using Test-Prat (when possible) is more user-friendly - the user can issue the same command easily.
