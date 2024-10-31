[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory)]
    [ValidateSet("build", "test", "deploy", "prebuild")] [string] $action,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [object[]] $CommandParameters
)

$cbt = &$home\prat\lib\Get-CodebaseTable (Get-Location)
if ($null -eq $cbt) { 
    throw "Unknown codebase - can't $action"
}

# Note we depend on PATH to find Get-CodebaseScript. This allows for it to be overridden.
$script = Get-CodebaseScript $action $cbt.id

if ($null -eq $script) {
    Write-Verbose "$($action): NOP"
    return
}

if ($action -ne "prebuild") {
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

Write-Debug "calling $action script for $($cbt.id), with parameters: ($(ConvertTo-Expression $CommandParameters))"

Invoke-CommandWithCachedEnvDelta {&$script $cbt @CommandParameters} $envDelta -CommandParameters $CommandParameters
