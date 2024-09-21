# Opens the workspace for the current codebase / sub-codebase
[CmdletBinding()]
param()

$cbt = &$PSScriptRoot\..\lib\Get-CodebaseSubTable $pwd

if ($null -eq $cbt) { 
    Write-Error "Codebase not recognized"
    return
}

$workspace = $cbt.workspace
if ($null -eq $workspace) {
    throw "Don't know how to open workspace for '$($cbt.id)'"
}
$workspace = $workspace -replace "dev:", "$($cbt.root)/"
if ($workspace.Contains("test:")) { throw "NYI" }
if (!(Test-Path $workspace)) { throw "Not found: $workspace" }

Write-Verbose "Opening: $workspace"
Invoke-CommandWithEnvDelta {&$workspace} (Get-CachedEnvDelta $cbt.cachedEnvDelta)

