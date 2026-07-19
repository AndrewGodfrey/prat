# prat

## Running tests

Use the `prat-run-tests` agent (for delegation) or `t` directly. Key invocations:

```bash
t ~/prat -NoCoverage                          # full suite, skip coverage
t ~/prat/lib/Foo.Tests.ps1 -NoCoverage        # focused run (absolute path auto-derives repo)
t C:/abs/path/to/File.Tests.ps1 -NoCoverage   # absolute path: auto-derives RepoRoot
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
Deploy scripts guard their entrypoint so they can be dot-sourced for testing — see `pwsh-coding`
skill for the mechanism. Inline helper functions at the top of the script rather than creating a
separate file to hold them for a single script.

### Readability patterns (see `Get-PratProject.Tests.ps1` as a reference)
- Extract a `makeTestProfile` / `makeIndex` helper in `BeforeAll` to eliminate repeated profile-writing boilerplate.
- Group related tests into `Context` blocks (e.g. "root resolution", "shortcuts", "command properties").
- Use `$root/subpath` string interpolation rather than `(Get-Item "TestDrive:\subpath").FullName`.
- Blank line between the arrange/act setup and the assertion(s).
- Multi-property assertions: align the `|` pipes and property names for readability.


## repoProfile path resolution

In `Register-Node` (`pratRepos.ps1`), a relative command path (`test`/`build`/`deploy`/`prebuild`)
declared on a *subproject* resolves against the repoProfile **file's own directory**, not the
subproject's root. E.g. `subprojects = @{ sub = @{ path = 'lib/sub'; test = 'lib/sub/test_sub.ps1' } }`
in a profile at `$root/codebaseProfile_x.ps1` resolves `sub.test` to `$root/lib/sub/test_sub.ps1` —
joined against `$root` (the file's directory), not against `sub`'s own root (`$root/lib/sub`).

## Prat module pattern

When adding an exported function to a prat module (Installers, PratBase, TextFileEditor):
1. Create/edit the `.ps1` file
2. Dot-source it in the `.psm1`
3. Add the function name to `FunctionsToExport` in the `.psd1` ← easy to forget
