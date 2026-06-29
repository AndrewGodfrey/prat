---
name: powershell-patterns
description: Use when writing PowerShell code. Covers gotchas with arrays, argument passing, string
  handling, and common patterns in this codebase.
---

# `[Parameter()]` activates advanced mode — `$ARGS` goes empty

Adding any `[Parameter()]` attribute to a `param()` block activates advanced function mode, even
without `[CmdletBinding()]`. In advanced mode `$ARGS` is always empty — extra positional arguments
are rejected with "A positional parameter cannot be found that accepts argument '...'".

For scripts that use `$ARGS` to forward pass-through args, use plain typed params with no
`[Parameter()]` decoration:

```powershell
# Correct — $ARGS captures remaining args
param([string] $Harness, [scriptblock] $LaunchHook)

# Broken — advanced mode, $ARGS always empty
param([Parameter(Mandatory)] [string] $Harness, [Parameter(Mandatory)] [scriptblock] $LaunchHook)
```

If mandatory enforcement is needed in advanced mode, capture remaining args explicitly:
`[Parameter(ValueFromRemainingArguments)] $PassThrough`.

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

# Scriptblocks passed as hooks — variable capture and shadowing

A plain `{ }` scriptblock captures a live reference to its defining scope's SessionStateInternal.
Variables from the defining scope are accessible when the hook runs. The risk is **shadowing**: a
variable anywhere in the call chain between invoker and hook that shares a name takes precedence.

**`.GetNewClosure()`** — snapshots variable values at definition time, making them immune to
shadowing. Safe when the scriptblock stays in-process and is never serialized:

```powershell
$claudeExe = "$home\.local\bin\claude.exe"
$hook = { & $claudeExe @allArgs }.GetNewClosure()   # $claudeExe value embedded, not looked up
```

**`[scriptblock]::Create()`** — bakes values into source text via string interpolation. Required
when the scriptblock goes through `Strip-Scriptblocks` / `Import-Scriptblock` (which reconstruct
from source text, discarding any `.GetNewClosure()` captures):

```powershell
$claudeExe = "$home\.local\bin\claude.exe"
$hook = [scriptblock]::Create("& '$claudeExe' @allArgs")   # value is in the source text
```

Switch params (`[switch] $NoSandbox`) are captured correctly by `.GetNewClosure()` as bool values.

**Functions are not captured** — only variables are. A function defined in the outer scope and
called by name inside the hook will fail after `.GetNewClosure()`. Workaround: store the function
as a variable using `${function:name}` syntax before closing over it:

```powershell
function getToken { ... }
$getToken = ${function:getToken}   # captured as a variable by GetNewClosure()

$hook = {
    $tok = & $getToken             # call via variable, not by name
}.GetNewClosure()
```

# Keep scriptblocks thin — extract implementation into functions

Closures capture the entire outer scope, so any variable name collision between the outer scope
and the scriptblock body is a latent bug. Keep the scriptblock as a thin wiring layer and put the
implementation in a named function, making dependencies explicit via parameters:

```powershell
function Invoke-MyHook($param1, $capturedVal, $resumeSid, $allArgs) {
    # all logic here — dependencies are explicit parameters
}

$capturedVal  = "..."
$invokeMyHook = ${function:Invoke-MyHook}
$hook = {
    param($resumeSid, $allArgs)
    & $invokeMyHook $param1 $capturedVal $resumeSid $allArgs
}.GetNewClosure()
```

The scriptblock becomes a legible declaration of what flows in. The function is independently
testable without any closure setup.

# Error-handling traps in pipeline redirection

`throw` is a terminating error — it bypasses `2>&1 | ForEach-Object` pipeline redirection entirely.
Wrap the pipeline in `try/catch` to handle both terminating and non-terminating errors:

```powershell
try {
    & $inner 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) { "[err] $($_.Exception.Message)" }
        else { $_ }
    }
} catch {
    "[err] $_"
    exit 1
}
```

# `exit N` inside a scriptblock exits the process

`exit N` inside `& { ... }` exits the **containing process**, not just the scriptblock.
To propagate an exit code without exiting, check `$LASTEXITCODE` after the block, or use a child
process (`pwsh -c ...`).

# $PSScriptRoot-relative paths when moving a script

Before writing a moved script to its new location, audit every `$PSScriptRoot`-relative path —
they resolve relative to where the file lives, so a path correct in `pathbin/` is wrong in `lib/`.

Example: `pathbin/Foo.ps1` uses `"$PSScriptRoot/../lib/Bar.ps1"` → resolves to `lib/Bar.ps1`.
After moving to `lib/Foo.ps1`, the correct path is `"$PSScriptRoot/Bar.ps1"`.
