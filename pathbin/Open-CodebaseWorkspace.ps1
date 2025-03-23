# .SYNOPSIS
# Opens a workspace with the configured temporary environment for the codebase we're in ($pwd).
#
# Alias: ow
#
# .NOTES
# With no params, opens the default workspace for the codebase / sub-codebase.
# Given a script, runs it. 
# Given a file, launches it.
# 
# .EXAMPLE
#    ow MyProject.sln
# .EXAMPLE
#    ow MyProject.code-workspace
# .EXAMPLE
#    ow {cmd /k}
# .EXAMPLE
#    ow {pwsh}
[CmdletBinding()]
param($fileOrScript = $null, $cbt = $null, [ScriptBlock] $DescriptionScript = $null)

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
    if ($workspace -is [string]) {
        $workspace = $workspace -replace "dev:", "$($cbt.root)/"
        if ($workspace.Contains("test:")) { throw "NYI" }
    }
} else {
    $workspace = $fileOrScript
}

# Adds the given context to $env:__prat_contextPath. This is shown on the prompt (see interactiveProfile_prat.ps1)
function appendContextPath($cachedEnvDelta, $id) {
    if ($null -ne $cachedEnvDelta) {
        if (($null -ne $env:__prat_contextPath) -and ($env:__prat_contextPath -ne "")) {
            # Rudimentary nesting support. "Full" support would check for clashes between the applied env-vars.
            # I'll probably only use this to detect I've nested when I didn't mean to.
            $env:__prat_contextPath += "/"
        }
        $env:__prat_contextPath += "%$id%"
    }
}

if ($null -eq $DescriptionScript) {
    $Description = "Opening workspace for: $($cbt.id)"
} else {
    $Description = (& $DescriptionScript $cbt.id)
}

if ($workspace -is [ScriptBlock]) {
    pushd $cbt.root
    $savedContextPath = $env:__prat_contextPath
    try {
        appendContextPath $cbt.cachedEnvDelta $cbt.id
        Write-Host -ForegroundColor Green $Description
        Invoke-CommandWithCachedEnvDelta $workspace $cbt.cachedEnvDelta
    } finally {
        $env:__prat_contextPath = $savedContextPath
        popd
    }
} else {
    # TODO: Refactor; we can do the same save/restore work (for $pwd and $env:__prat_contextPath) here.
    #       It would simplify the code. There might even be real use-cases where launching a file opens an inner 'pwsh' shell.
    #
    # TODO: Further refactor so that *every* use of Invoke-CommandWithCachedEnvDelta will update $env:__prat_contextPath
    if (!(Test-Path $workspace)) { throw "Not found: $workspace" }
    Write-Host -ForegroundColor Green $Description
    Invoke-CommandWithCachedEnvDelta {&$workspace} $cbt.cachedEnvDelta
}

