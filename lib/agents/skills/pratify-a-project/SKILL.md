---
name: pratify-a-project
description: Load before working on the integration of a project into the prat dev environment.
---

This skill covers how to integrate an external repo/project so that it presents a uniform
inner-loop dev interface to the user: `pb` (prebuild), `b` (build), `t` (test), `d` (deploy).

## Question 1: Internal or external?

If this is the user's own project, they may prefer to put prat configuration inside the repo itself.
Ask for more guidance in this case — it's not fully fleshed out here. One example is prat itself:
see `prat/codebaseProfile_prat.ps1`.

Otherwise — for external projects, put prat configuration in another repo:
- `de/codebaseProfile_de.ps1` — environment-specific (for projects tied to one dev environment e.g. school / personal / work)
- `prefs/codebaseProfile_prefs.ps1` — user-global (for projects shared across all the user's environments)

For projects whose source lives *inside* `prefs` or `de` (e.g. `de/lib/projects/cssample`), register them
under a relative section key like `"lib/projects"` rather than `"C:/git"` or a hardcoded absolute
path. The section key is resolved relative to the codebaseProfile file's directory, so the project
root ends up as `<de-root>/lib/projects/<id>`.

## Configuration

A codebaseProfile file returns a hashtable. Each key is a **section** — a base directory under
which repos live. Each repo's root defaults to `<sectionRoot>/<id>`.

```powershell
@{
    "C:/git" = @{
        repos = @{
            llamacpp = @{
                buildKind      = "CMake"
                cachedEnvDelta = "build/de_bt_msvc_envvar_cache.ps1"  # relative to project root
            }
            nanogpt  = @{}
        }
    }
    "lib/projects" = @{
        repos = @{
            cssample = @{}   # root resolves to <de-root>/lib/projects/cssample
        }
    }
}
```

Custom properties (like `buildKind`, `cachedEnvDelta`) are passed through to the `$project` object
that all scripts receive.

### Auto-discovery of scripts

For a registered project with id `<id>`, prat auto-discovers scripts at:

```
<codebaseProfile-dir>/lib/projects/<id>/<cmd>_<id>.ps1
```

where `<cmd>` is one of `prebuild`, `build`, `test`, `deploy`. No explicit wiring needed if the
scripts follow this naming and live in the expected location. You can also override with an explicit
path or scriptblock in the codebaseProfile entry.

## `prebuild`: purpose and requirements

Prebuild installs everything needed to build and test. It runs via `pb` and must be idempotent —
fast when nothing needs to change.

### Requirements for dependencies

The goal is **development isolation**: multiple projects with different dependencies must coexist on
the same machine without interfering. This is not about security, it is about:
- development isolation (many projects on one machine, without crosstalk)
- reproducibility

**What's acceptable:**

- Writing to the registry, if the tool is designed to coexist with other versions
- Installing files to `Program Files`, if the tool supports side-by-side versions
- A **global muxer** on PATH (see below)

**What's not acceptable:**

- Permanently adding build-specific toolchain directories to PATH
- Modifying shell functions or prompt
- Assuming only one version of the tool will ever be present

**Two valid patterns:**

#### Pattern A: Env delta (e.g. MSVC / CMake)

Used when the toolchain is not on PATH at all. Prebuild captures the environment changes the
toolchain's setup script would make, and stores them in a `.ps1` cache file. `b` and `t` apply
this delta temporarily for the duration of the command, then revert.

Wire it up by setting `cachedEnvDelta` in the codebaseProfile to a path (relative to project root)
for the cache file. `Invoke-CodebaseCommand` handles apply/revert automatically.

```powershell
# prebuild: capture the env delta once (or when the forkpoint changes)
function deployCmakeEnvDelta($it, $cbtRoot, $mainBranch, $cachedEnvDeltaFn) {
    $stage = $it.StartStage('deployCmakeEnvDelta')
    $currentForkpoint = Get-CurrentGitForkpoint $cbtRoot $mainBranch
    if (!($stage.GetForkpointCacheIsValid("myproject\cachedEnvDelta", $currentForkpoint))) {
        $stage.OnChange()
        $environmentChange = Export-EnvDeltaFromInvokedBatchScript "path\to\setup.bat" `
            -OnOutput (Get-DefaultOnOutputBlock)
        Install-CachedEnvDelta $stage $cachedEnvDeltaFn $environmentChange
        $stage.SetForkpointCache("myproject\cachedEnvDelta", $currentForkpoint)
    }
    $it.EndStage($stage)
}
```

The **forkpoint cache** avoids re-running the expensive batch capture on every `pb` call —
it only re-runs when the project's git branch diverges from the last captured point.

`Export-EnvDeltaFromInvokedBatchScript` and `Install-CachedEnvDelta` are exported from `PratBase`.

#### Pattern B: Global muxer (e.g. .NET SDK)

Used when the tool installs a single dispatcher binary on PATH that reads a project-local config
file to select the right version at runtime. No env delta is needed — the muxer handles version
selection transparently.

Requirements for using this pattern:
- The dispatcher is designed for multi-version coexistence (not just "multiple major versions can
  be installed", but actual correct dispatch per-project)
- The project pins its required version in a checked-in config file (e.g. `global.json` for .NET)
- The config file pins major.minor at minimum; use `latestFeature` to float across feature bands
  within that minor version (e.g. `8.0.100` accepts `8.0.419`). `latestPatch` is narrower — it only
  rolls within the same feature band (hundreds digit), which is usually not what you want, but could help
  with a conflict.

```json
// global.json — checked in at the project root
{
  "sdk": {
    "version": "8.0.100",
    "rollForward": "latestFeature"
  }
}
```

Prebuild just ensures the required version is installed:

```powershell
function ensureDotnetSdk8($it) {
    $stage = $it.StartStage('ensureDotnetSdk8')
    $sdkDir = "$env:programfiles\dotnet\sdk"
    $hasSdk8 = (Test-Path $sdkDir) -and
               [bool](Get-ChildItem $sdkDir -Directory -ErrorAction SilentlyContinue |
                      Where-Object Name -like '8.0.*')
    if (-not $hasSdk8) {
        $stage.OnChange()
        winget install --silent --exact --id Microsoft.DotNet.SDK.8 `
            --accept-package-agreements --accept-source-agreements
        $code = $LastExitCode
        if ($code -ne 0 -and $code -ne -1978335189) { throw "install failed (winget exit: $code)" }
        # Installer updates machine PATH in registry but not the current process — refresh it
        $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        if ($machinePath -notin ($env:PATH -split ';')) { $env:PATH = "$machinePath;$env:PATH" }
    }
    $it.EndStage($stage)
}
```

#### Counterexample: conda (what not to do)

Conda by default wraps the shell prompt, wraps `TabExpansion`, defines aliases, and adds multiple
directories to PATH — none of which are reverted when you're done. This is what the env delta
pattern is designed to avoid.

### Prebuild script structure

```powershell
using module ..\..\..\..\prat\lib\PratBase\PratBase.psd1
using module ..\..\..\..\prat\lib\Installers\Installers.psd1

[CmdletBinding()]
param($project, [hashtable]$CommandParameters = @{})

$ErrorActionPreference = "stop"
$it = $null

try {
    $it = Start-Installation "prebuild<Id>" `
        -InstallationDatabaseLocation "$home\prat\auto\instDb" `
        -Force:$CommandParameters['Force']

    # ... stages here ...

    echo "OK"
} catch {
    if ($null -ne $it) { $it.ReportErrorContext($error[0]) }
    throw
} finally {
    if ($null -ne $it) { $it.StopInstallation() }
}
```

The `using module` paths assume the script lives at depth 4 below the home directory (e.g.
`de/lib/projects/<id>/`). Adjust `..` count if the depth differs.

The `-Force` flag (passed through from `pb -Force`) clears instDb state for this installation,
forcing all stages to re-run. Useful when you need to re-capture an env delta or re-install a
package.

## `build`: purpose and requirements

- **Incremental**: only build what changed since the last build. Let the build tool handle this —
  don't delete output before building unless the user explicitly requests a clean build.
- Receive `$project` and `$CommandParameters`. Support at minimum `Command = 'build'` and
  `Command = 'clean'` where the tool supports it.

## `test`: purpose and requirements

- Run the full test suite (or a relevant subset if the project has a concept of that)
- Exit non-zero on failure; prat will surface this to the user
- Receive `$project` and `$CommandParameters`

## `deploy`: purpose and requirements

- Project-specific: could mean copying output to a target machine, running a publish step, etc.
- For the `de` repo itself, deploy means running `deployEnv.ps1` which applies the dev environment
  configuration to the current machine
