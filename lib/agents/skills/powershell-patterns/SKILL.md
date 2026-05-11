---
name: powershell-patterns
description: Use when writing PowerShell code. Covers gotchas with arrays, argument passing, string
  handling, and common patterns in this codebase.
---

# Calling a script for its return value

Use `& $file` not `. $file`. Dot-source runs the script in the current scope and imports its
definitions — only use it when you need that (e.g. loading helper functions). For a script that
returns data, `& $file` is correct.

# Accumulating into an array

Start with `$x = @()` and use `$x +=` to add elements. Do not use `[array]$source` when `$source`
might come from an `if`/`else` expression — PowerShell's pipeline can collapse an empty `@()` to
`$null`, so `[array]$null` gives `@($null)` (one null element) instead of an empty array.

# Parameter forwarding in wrapper functions

When writing a thin wrapper function that forwards all arguments to a script or another function,
use `param()` + `@PSBoundParameters` — **not** bare `@args`:

```powershell
# Correct
function Invoke-Something {
    param([switch]$NoCoverage, $PathToTest, $RepoRoot, [switch]$PassThru)
    & "$PSScriptRoot/Invoke-Something.ps1" @PSBoundParameters
}

# Broken — @args splits -Switch:$false into a flag and a positional 'False'
function Invoke-Something { & "$PSScriptRoot/Invoke-Something.ps1" @args }
```

**Why `@args` breaks:** callers often use `:$value` syntax for switches (e.g.
`-NoCoverage:$CommandParameters['NoCoverage']`). PowerShell splits `-NoCoverage:$false` into the
flag `-NoCoverage:` and a separate positional argument `False`. The called script then errors:
"A positional parameter cannot be found that accepts argument 'False'."

`@PSBoundParameters` forwards named parameters correctly, including switches with explicit values.

# Checking whether a path is absolute

Call `Expand-TildePath $path` before `[System.IO.Path]::IsPathRooted` — .NET doesn't understand
PowerShell's `~`, so `IsPathRooted("~/prat")` returns `$false`. `Expand-TildePath` (in PratBase)
uses `GetUnresolvedProviderPathFromPSPath` and works on paths that don't exist yet.

```powershell
if ($Path) { $Path = Expand-TildePath $Path }
if ([System.IO.Path]::IsPathRooted($Path)) { ... }
```

# $PSScriptRoot-relative paths when moving a script

Before writing a moved script to its new location, audit every `$PSScriptRoot`-relative path —
they resolve relative to where the file lives, so a path correct in `pathbin/` is wrong in `lib/`.

Example: `pathbin/Foo.ps1` uses `"$PSScriptRoot/../lib/Bar.ps1"` → resolves to `lib/Bar.ps1`.
After moving to `lib/Foo.ps1`, the correct path is `"$PSScriptRoot/Bar.ps1"`.
