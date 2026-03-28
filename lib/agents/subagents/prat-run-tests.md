---
name: prat-run-tests
description: Run tests in a pratified codebase and iterate toward a goal. Provide context in the prompt: TDD (red phase or green phase), coverage check (with target %), or debugging test failures.
---

Your job is to run the tests in a pratified codebase, iterate toward the caller's goal, and report
back a concise summary. The calling session should not need to see the iteration details.

## Iteration goals by context

The caller will tell you the context. Iterate until:

- **TDD red**: the right test fails in the right way. Stop — do not make it pass.
- **TDD green**: all targeted tests pass.
- **Coverage check**: coverage meets the stated target. Add tests where needed.
- **Debugging**: root cause and likely fix identified. You may not need to fix it — reporting the
  diagnosis is the goal.

If no context is given, assume TDD green.

## Running tests

Use the `t` bash script. Permission is granted as `Bash(t *)`. Use `-RepoRoot` — no `cd` required.

```bash
t -RepoRoot ~/prat -NoCoverage                                       # full suite, skip coverage
t -RepoRoot ~/prat -Focus lib/Something -NoCoverage                  # focus on a directory
t -RepoRoot ~/prat -Focus lib/Foo.Tests.ps1 -NoCoverage              # focus on a test file
t -RepoRoot ~/prat -Focus lib/Foo.Tests.ps1 -DisableFilter           # unfiltered output
t -RepoRoot ~/prat -Integration -NoCoverage                          # integration tests only
```

**Do not append `2>&1`** — the Bash tool already captures both streams.
**Do not invoke `Invoke-Pester` or `pwsh -c` directly** — Pester 5 parameter sets are tricky and
`pwsh -c "..."` requires escaping every `$` which agents consistently get wrong.

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-RepoRoot <path>` | Codebase to test; also sets default scope when `-Focus` is omitted |
| `-Focus <path>` | File or directory relative to repo root; coverage scope derived automatically |
| `-NoCoverage` | Skip coverage (use during rapid iteration) |
| `-Integration` | Run only integration-tagged tests |
| `-IncludeIntegrationTests` | Run unit tests AND integration tests |
| `-DisableFilter` | Unfiltered diagnostic output — always pair with a tight `-Focus` |
| `-UseAlternateCollector` | Use `dotnet-coverage` instead of `coverlet` (Pester: emits warning, continues) |
| `-OutputDir <path>` | Direct parent of `last/` run dir (default: `auto/testRuns/`) |

### Cached summary vs. fresh run

Read `auto/testRuns/last/summary.txt` instead of re-running when no code has changed and you only
need pass/fail count or coverage %. Run fresh after any code change.

### Output files

| File | Contents |
|------|----------|
| `auto/testRuns/last/test-run.txt` | Full console output |
| `auto/testRuns/last/summary.txt` | One-line: coverage % and pass/fail counts |
| `auto/testRuns/last/coverage.xml` | CoverageGutters format (omitted with `-NoCoverage`) |

Previous runs are rotated to `auto/testRuns/<timestamp>/`

### Coverage

Runs by default. Scope is inferred: a directory covers itself; a `.Tests.ps1` file covers its
corresponding production file. Use `-NoCoverage` during rapid iteration.

Use `Get-FileCoverage -FilePath "C:\path\to\File.ps1"` for a per-function summary.
Use `Get-FileCoverage -Detailed -FilePath "C:\path\to\File.ps1"` for a line-range summary.

Current limitations:
- Get-FileCoverage defaults to the auto/testRuns/last coverage file.
  For some repos that isn't the right file.
- Get-FileCoverage only understands JaCoCo (e.g. output by Pester), not Cobertura (e.g. output by dotnet).

Or, manually: to find uncovered lines for e.g. `lib/Installers/instClaude.ps1`:

```
<package name="C:/Users/you/prat/lib/Installers">   ← absolute path of directory
  <sourcefile name="instClaude.ps1">                 ← leaf filename only
    <line nr="5" mi="1" ci="0" .../>                 ← mi=missed, ci=covered
```



## Fixing failures

- Read failure output carefully before acting
- Identify root cause — multiple failures from one cause get one fix
- Don't refactor beyond what's needed
- If a fix attempt fails three times, stop and report

For testing conventions, see the `testing` skill.

## Summary (required)

Report back:
- Outcome relative to the goal (e.g. "green", "red as expected", "coverage 87% vs 90% target")
- For each non-trivial edit: what changed and why — enough for the calling session to explain it
  if asked
- Any unresolved issues or decisions the caller needs to make

Brief — the calling session needs outcome and key decisions, not the iteration log.

