# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in the 'prat' repository.

## Running tests

Use the `prat-run-tests` agent (for delegation) or `t` directly. Key invocations:

```bash
t -RepoRoot ~/prat -NoCoverage          # full suite, skip coverage
t -RepoRoot ~/prat -Focus lib/Foo.ps1   # focused run
```

After adding or modifying test files, scan for anti-patterns:

```bash
Find-TestAntiPatterns.ps1 -Path ~/prat
```

This catches unguarded env var mutations and writes to `$home`. Run it before wrapping up.

## Unit test conventions

### File organization
- One test file per function, named `<FunctionName>.Tests.ps1`, co-located with the source file.
- Internal (non-exported) functions go in `lib/PratBase/` and need `InModuleScope PratBase { ... }`.
- Tests for exported functions (e.g. `Get-PratRepo`, `Get-PratProject`) go in `lib/PratBase/` too (since that
  is where the source lives), but don't need `InModuleScope`.

### Testing helper functions in deploy scripts
Deploy scripts (`param` at top, side effects) can't be dot-sourced without triggering execution. To make
helper functions testable, inline them at the top of the script and guard the execution body:

```powershell
param(...)           # must stay at top — NOT inside the if block

function Helper { ... }

if ($MyInvocation.InvocationName -ne ".") {
    # main body — only runs when executed directly, not when dot-sourced
}
```

Test files dot-source the script (`BeforeAll { . "$PSScriptRoot/myscript.ps1" }`) to load the helpers
without triggering the body. Don't create separate files just to hold helpers for a single script.

### Readability patterns (see `Get-PratProject.Tests.ps1` as a reference)
- Extract a `makeTestProfile` / `makeIndex` helper in `BeforeAll` to eliminate repeated profile-writing boilerplate.
- Group related tests into `Context` blocks (e.g. "root resolution", "shortcuts", "command properties").
- Use `$root/subpath` string interpolation rather than `(Get-Item "TestDrive:\subpath").FullName`.
- Blank line between the arrange/act setup and the assertion(s).
- Multi-property assertions: align the `|` pipes and property names for readability.


## Prat module pattern

When adding an exported function to a prat module (Installers, PratBase, TextFileEditor):
1. Create/edit the `.ps1` file
2. Dot-source it in the `.psm1`
3. Add the function name to `FunctionsToExport` in the `.psd1` ← easy to forget

