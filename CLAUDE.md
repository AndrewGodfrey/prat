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

## Prat module pattern

When adding an exported function to a prat module (Installers, PratBase, TextFileEditor):
1. Create/edit the `.ps1` file
2. Dot-source it in the `.psm1`
3. Add the function name to `FunctionsToExport` in the `.psd1` ← easy to forget

