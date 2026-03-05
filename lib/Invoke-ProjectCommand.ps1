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
$project = Get-PratProject $location
if ($null -eq $project) {
    throw "Unknown project - can't $CommandName"
}

$command = $project[$CommandName]
if ($null -eq $command) {
    Write-Verbose "$($CommandName): NOP"
    return
}

if ($CommandName -ne "prebuild") {
    $envDelta = $project.cachedEnvDelta
    if (($null -ne $envDelta) -and (-not (Split-Path $envDelta -IsAbsolute))) {
        $envDelta = Join-Path $project.root $envDelta
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

Write-Debug "calling $CommandName script for $($project.id), with switches: ($(ConvertTo-Expression $CommandParameters))"

$wrapperScriptBlock = {
    param([hashtable]$CommandParameters = @{})
    & $command $project -CommandParameters:$CommandParameters
}
Invoke-CommandWithCachedEnvDelta $wrapperScriptBlock $envDelta -CommandParameters $CommandParameters
