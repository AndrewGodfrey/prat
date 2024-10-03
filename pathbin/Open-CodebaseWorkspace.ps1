# Opens the given workspace, or (if null) the workspace for the current codebase / sub-codebase
# A 'workspace' can be something like a Visual Studio .sln file, a Vscode .code-workspace, or any
# other workspace file that Shell can open.
[CmdletBinding()]
param($file = $null)

$cbt = &$PSScriptRoot\..\lib\Get-CodebaseSubTable $pwd -Verbose:$VerbosePreference
Write-DebugValue $cbt

if (($null -eq $cbt) -and ($null -eq $file)) { 
    Write-Error "Codebase not recognized"
    return
}

if ($null -eq $file) {
    $workspace = $cbt.workspace
    if ($null -eq $workspace) {
        throw "Don't know how to open workspace for '$($cbt.id)'"
    }
    $workspace = $workspace -replace "dev:", "$($cbt.root)/"
    if ($workspace.Contains("test:")) { throw "NYI" }
} else {
    $workspace = $file
}

if (!(Test-Path $workspace)) { throw "Not found: $workspace" }
Write-Verbose "Opening workspace: $workspace"
Invoke-CommandWithCachedEnvDelta {&$workspace} $cbt.cachedEnvDelta
