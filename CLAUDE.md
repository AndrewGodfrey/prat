# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in the 'prat' repository.

## Running tests

Use the `prat-run-unit-tests` skill. Key invocations:

```bash
t -RepoRoot ~/prat -NoCoverage          # full suite, skip coverage
t -RepoRoot ~/prat -Focus lib/Foo.ps1   # focused run
```

## Style

- Markdown files: wrap lines at 120 characters max. Break at natural phrase boundaries
  for readability (like this).

## Unit test conventions

### File organization
- One test file per function, named `<FunctionName>.Tests.ps1`, co-located with the source file.
- Internal (non-exported) functions go in `lib/PratBase/` and need `InModuleScope PratBase { ... }`.
- Tests for exported functions (e.g. `Get-PratRepo`, `Get-PratProject`) go in `lib/PratBase/` too (since that
  is where the source lives), but don't need `InModuleScope`.

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

