[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory)]
    [ValidateSet("build", "test", "deploy", "prebuild")] [string] $CommandName,
    [hashtable] $CommandParameters = @{}
)

$location = if ($CommandParameters['RepoRoot']) {
    $resolved = (Resolve-Path $CommandParameters['RepoRoot']).Path
    $CommandParameters['RepoRoot'] = $resolved
    $resolved
} else { Get-Location }
$cbt = &$home\prat\lib\Get-PratRepo $location
if ($null -eq $cbt) { 
    throw "Unknown codebase - can't $CommandName"
}

# Note we depend on PATH to find Get-CodebaseScript. This allows for it to be overridden.
$script = Get-CodebaseScript $CommandName $cbt.id

if ($null -eq $script) {
    Write-Verbose "$($CommandName): NOP"
    return
}

if ($CommandName -ne "prebuild") {
    $envDelta = $cbt.cachedEnvDelta
    if (($null -ne $envDelta) -and (-not (Split-Path $envDelta -IsAbsolute))) {
        $envDelta = Join-Path $cbt.root $envDelta
    }
} else {
    # In the case of prebuild, cachedEnvDelta is not needed.
    # But also: Prebuild often would malfunction if cachedEnvDelta is applied, since it
    # needs the unapplied state to accurately calculate/update cachedEnvDelta.
    #
    # TODO: Add detection for when prebuild is called with any envdelta applied.
    #       Maybe Invoke-CommandWithEnvDelta could reserve some env-var name, and use it to maintain a 'nesting' counter.
    $envDelta = $null
}

Write-Debug "calling $CommandName script for $($cbt.id), with switches: ($(ConvertTo-Expression $CommandParameters))"

$wrapperScriptBlock = {
    param([hashtable]$CommandParameters = @{})
    & $script $cbt -CommandParameters:$CommandParameters
}
Invoke-CommandWithCachedEnvDelta $wrapperScriptBlock $envDelta -CommandParameters $CommandParameters
