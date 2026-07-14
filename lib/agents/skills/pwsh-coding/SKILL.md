---
name: pwsh-coding
description: Use when writing PowerShell code. Covers gotchas with arrays, argument passing, string
  handling, and common patterns in this codebase.
---

# Cryptographically secure random bytes

`Get-Random` is seeded from the clock — not cryptographically secure. For keys, tokens, or any
secret material, use `RandomNumberGenerator`:

```powershell
$bytes = [byte[]]::new(32)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$key = [System.Convert]::ToBase64String($bytes)
```

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

# Guarding a script's entrypoint so it can be dot-sourced

Any top-level script that calls its own logic unconditionally at the bottom — e.g. a `main` function,
following the "define `main` at the top, invoke it from the bottom" literate-structure convention —
can't be dot-sourced without triggering that call, whether to unit-test its helper functions or to
import them for reuse elsewhere. Guard the call:

```powershell
param(...)           # must stay at top — NOT inside the if block

function Helper { ... }

if ($MyInvocation.InvocationName -ne '.') {
    # main body — only runs when executed directly, not when dot-sourced
}
```

`$MyInvocation.InvocationName` is `.` when the script is dot-sourced, and the script's own name/path
otherwise — normal execution (`& script.ps1`, or running it directly) is unaffected.

Test files dot-source the script (`BeforeAll { . "$PSScriptRoot/myscript.ps1" }`) to load helpers
without triggering the body. Don't create separate files just to hold helpers for a single script.

# Accumulating into an array

Start with `$x = @()` and use `$x +=` to add elements. Do not use `[array]$source` when `$source`
might come from an `if`/`else` expression — PowerShell's pipeline can collapse an empty `@()` to
`$null`, so `[array]$null` gives `@($null)` (one null element) instead of an empty array.

# Consuming an array from a function call or property chain

A function returning a single-element array collapses to the bare element when the caller captures
it: `function Test-Ret { return @(@{a=1}) }; $r = Test-Ret` gives `$r` as a `Hashtable`, not an
array.

Chaining `@(FunctionCall).property` compounds this: it goes through array member-enumeration
(since `@(FunctionCall)` is an array), not ordinary property access, which collapses the
property's own value the same way — a single-element value collapses to a bare scalar, and an
*empty* value collapses to `$null` (then `@($null)` is a 1-element array containing `$null`, not
an empty array — see "Accumulating into an array" above).

Fix: assign to a variable first, then access properties normally — plain scalar property access,
immune to member-enumeration collapse:

```powershell
# Broken - collapses on both a single-element AND an empty .read
function getAgentRoPaths() {
    return @(Get-PratAgentGrantedPaths).read + @(Get-AgentRoPaths)
}

# Correct
function getAgentRoPaths() {
    $granted = Get-PratAgentGrantedPaths
    return @($granted.read) + @(Get-AgentRoPaths)
}
```

The empty case surfaces downstream as `Cannot bind argument to parameter 'Path' because it is an
empty string`, wherever the resulting array gets passed to something that binds each element as a
path.

A related but separate trap: `ConvertTo-Json $arr -AsArray` where `$arr` is passed positionally
(not piped). `-AsArray` wraps whatever's bound to `-InputObject` in an *additional* array layer —
correct for a scalar (the pipeline single-item-collapse case `-AsArray` is meant to fix), but wrong
once `$arr` is already a genuine array: `ConvertTo-Json @(1,2) -Depth 5 -AsArray` produces
`[[1,2]]`, not `[1,2]`. If `$arr` is already a real array (built via `@()`/`+=`, not piped in), omit
`-AsArray`.

# `ConvertTo-Json` on a `[hashtable]` emits keys in per-process-random order

When serializing to a generated file that's later compared as text (e.g. `Install-TextToFile`) or
committed, build the object with `[ordered]@{}`, not `@{}`. .NET randomizes `String.GetHashCode`
per-process, so a plain `[hashtable]`'s enumeration order — and thus `ConvertTo-Json`'s key order —
varies from run to run; identical data then serializes to different text, and a text-diff comparison
sees a spurious change every time (this made an installer stage report "updating" on every deploy).
`[ordered]` (OrderedDictionary) preserves insertion order, so the output is deterministic.

# Inspecting rich objects — select fields, don't serialize the whole thing

Objects built by tooling often carry live machinery that inspection renders badly: a member holding
a scriptblock makes `ConvertTo-Json` emit the scriptblock's entire AST (kilobytes of noise per
scriptblock — e.g. a `Get-PratProject` descriptor), and `Format-Table`/`Format-List` output needs a
console width, so it can come back blank in non-interactive sessions (pipe through
`Out-String -Width <N>`). To inspect, name the fields you want — `$p.id`, or
`$p | Select-Object id, root, parentId` — and reserve whole-object serialization for objects you
built yourself from plain data.

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

# Scriptblocks assigned as .NET delegates need a runspace — don't use for off-thread callbacks

A scriptblock assigned directly to a delegate-typed property (e.g. `HttpClientHandler`'s
`ServerCertificateCustomValidationCallback`, `SslStream`'s `RemoteCertificateValidationCallback`)
needs a PowerShell runspace to execute. If .NET invokes it on a thread that doesn't have one
available — the normal case for TLS handshake callbacks, which run on background/IO threads — it
either hangs indefinitely (if the calling thread is itself blocked synchronously via
`.GetAwaiter().GetResult()`, since that thread can't service the callback either) or throws
`PSInvalidOperationException: There is no Runspace available to run scripts in this thread`.
Confirmed by direct repro: a scriptblock that just returns `$true` never even logged that it ran.

Fix: compile the logic as C# via `Add-Type` and assign a method group (`$instance.MethodName`) to
the delegate property instead — compiled code has no runspace dependency:

```powershell
if (-not ('MyValidator' -as [type])) {
    Add-Type -TypeDefinition @'
public class MyValidator {
    public bool Validate(...) { ... }
}
'@
}
$validator = [MyValidator]::new(...)
$handler.ServerCertificateCustomValidationCallback = $validator.Validate
```

# `Add-Type` treats some obsolete .NET APIs as hard errors, not warnings

Compiling `new X509Certificate2(byte[])` (or the file-path / byte[]+password overloads) inside
`Add-Type -TypeDefinition` fails with `error SYSLIB0057: ... is obsolete` — a compile error, not a
warning, unlike calling the same obsolete constructor from plain PowerShell (silently allowed there).
Use `[X509CertificateLoader]::LoadCertificate(bytes)` / `LoadPkcs12FromFile(path, password)` instead
inside `Add-Type` blocks.

# Windows SChannel rejects PEM-loaded cert+key pairs as TLS server certs ("ephemeral keys")

`X509Certificate2.CreateFromPemFile(certPath, keyPath)` loads correctly (readable, `HasPrivateKey`
true), but its key is "ephemeral" — not backed by a persisted CAPI/CNG key container. Using that
cert as the server certificate in `SslStream.AuthenticateAsServer(...)` on Windows fails with
`AuthenticationException: Authentication failed because the platform does not support ephemeral
keys` (inner: `Win32Exception: No credentials are available in the security package`). Windows/
SChannel-specific — doesn't affect Linux/macOS, and doesn't affect real servers using their own TLS
stack (e.g. llama-server's OpenSSL). Re-exporting through a PFX
(`X509CertificateLoader.LoadPkcs12FromFile`, or `new X509Certificate2(cert.Export(Pfx))`) did not
reliably resolve it under a sandboxed/restricted account either (`Access denied` / "credentials ...
not recognized"). If a test needs a real TLS server and the project already has one with its own TLS
stack, drive that instead of standing up an `SslStream` server from a PEM cert.

# $PSScriptRoot-relative paths when moving a script

Before writing a moved script to its new location, audit every `$PSScriptRoot`-relative path —
they resolve relative to where the file lives, so a path correct in `pathbin/` is wrong in `lib/`.

Example: `pathbin/Foo.ps1` uses `"$PSScriptRoot/../lib/Bar.ps1"` → resolves to `lib/Bar.ps1`.
After moving to `lib/Foo.ps1`, the correct path is `"$PSScriptRoot/Bar.ps1"`.
