# .SYNOPSIS
# Opens a workspace with the configured temporary environment for a codebase.
#
# With no params, opens the default workspace for the codebase / sub-codebase.
# Given a file, launches that. e.g.
#    Open-CodebaseWorkspace MyProject.sln
# 
#    Open-CodebaseWorkspace MyProject.code-workspace
# 
# Given a script, runs that. e.g. 
#    Open-CodebaseWorkspace {cmd /k}
[CmdletBinding()]
param($fileOrScript = $null, $cbt = $null)

if ($null -eq $cbt) {
    $cbt = &$PSScriptRoot\..\lib\Get-CodebaseSubTable $pwd -Verbose:$VerbosePreference
}
Write-DebugValue $cbt

if (($null -eq $cbt) -and ($null -eq $fileOrScript)) { 
    Write-Error "Codebase not recognized"
    return
}

if ($null -eq $fileOrScript) {
    $workspace = $cbt.workspace
    if ($null -eq $workspace) {
        throw "Don't know how to open workspace for '$($cbt.id)'"
    }
    $workspace = $workspace -replace "dev:", "$($cbt.root)/"
    if ($workspace.Contains("test:")) { throw "NYI" }
} else {
    $workspace = $fileOrScript
}

if ($workspace -is [ScriptBlock]) {
    Invoke-CommandWithCachedEnvDelta $workspace $cbt.cachedEnvDelta
} else {
    if (!(Test-Path $workspace)) { throw "Not found: $workspace" }
    Write-Verbose "Opening workspace: $workspace"
    Invoke-CommandWithCachedEnvDelta {&$workspace} $cbt.cachedEnvDelta
}

