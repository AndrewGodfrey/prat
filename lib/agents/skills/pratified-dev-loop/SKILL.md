---
name: pratified-dev-loop
description: Use in any pratified project for build/test/deploy/prebuild work — b, d, pb, t.
  Includes coverage tools (Get-FileCoverage, Get-CoverageReport/gcr).
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

Run `t` with an absolute path — no `cd` required — through whatever execution tool the harness
provides; `Bash`/`PowerShell` are denied in the agent harness configs, so `t` is not invoked as a
shell command.

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
- Using `t` is more user-friendly — the user can issue the same command easily
- `pwsh -c "..."` requires escaping every `$` which agents consistently get wrong
- Pester 5 parameter sets are tricky

## Running every layer's tests at once (`ta`)

`Test-AllLayers` (alias `ta`) runs every installed layer (de/prefs/prat, whichever are present) concurrently —
one job per layer — and prints a merged summary once every layer has finished. Reach for it for a
whole-stack check; reach for plain `t` for the inner loop on one repo.

Exit code: `0` = every layer completed with zero failures; `1` = a layer reported test failures and no
layer was fatal; `2` = a layer was fatal (its job failed, timed out, or completed with no result) — `2`
wins when both occur. A `2` means the harness itself broke (read the per-layer detail `ta` prints, not
just the summary line); a `1` means read the failing layer's own `test-run.txt`, same as a `t` failure.

## If `t` itself errors

An error from `t` itself (e.g. "Unknown project") is friction in tooling — a defect to address, not
a cost to route around: debug and fix the root cause. Do not fall back to running the underlying
test command (pytest, `dotnet test`, Pester) directly as a substitute; that silently drops `t`'s
guarantees (coverage collection, working directory, output location) and is never an acceptable
resolution on its own.

## Integration-tagged tests are excluded by default

Without `-Integration`/`-IncludeIntegrationTests`, tests tagged `Integration` are filtered out
and counted as **NotRun** — visible in `test-run.txt` but not in the console one-liner, whose
"Passed" count therefore understates the discovered total. Before treating a passed-count drop
across runs as a regression, check `test-run.txt` for the NotRun count.

## Reading the summary line

The colour of the one-line summary, in precedence order — first match wins:

| Colour | Meaning |
|---|---|
| **red** | 5 or more tests failed. **Or** a fatal problem: nothing was discovered under the focus, a test file failed to run, or one leg of a multi-framework run produced no result at all. |
| **yellow** | 1–4 tests failed. **Or** the runner's output couldn't be parsed for counts. **Or** tests were discovered and none of them ran (`0 of N tests ran`). |
| **green** | At least one test ran, and none failed. |

Two consequences worth holding onto:

- **`Passed: 0, Failed: 0` is never green.** Zero tests executed is either red (nothing discovered)
  or yellow (`0 of N tests ran` — all filtered out or `-Skip`ped, e.g. `t <path> -Integration` where
  nothing carries the tag). Legitimate, but not a pass.
- **A fatal problem is red even when the counts look fine**, so read the counts and the reason
  together: `Passed: 12, Failed: 0. 1 test file failed to run.` means 12 tests passed *and* a whole
  file never ran.

The 5-failure threshold decides red vs. yellow, and also caps how many failure blocks print live —
hence the `N failures suppressed` hint. Any run with failures names the `test-run.txt` holding them;
a fatal one also echoes that log's last 20 lines.

Separately, an all-passing run whose coverage is below target prints the coverage part yellow inside
an otherwise-green line — that yellow is about coverage, not about the tests.

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

`Get-FileCoverage` and `gcr` support JaCoCo/CoverageGutters and Cobertura XML formats — both read
through the shared `lib/Get-CoverageDetails.ps1` parser, which is an internal script, not a command
on PATH.

## Fixing Failures

- Read failure output carefully before acting
- Identify root cause — multiple failures from one cause get one fix
- Don't refactor beyond what's needed
- If a fix attempt fails three times, stop and report to the user

For testing conventions, see the `testing` skill.
