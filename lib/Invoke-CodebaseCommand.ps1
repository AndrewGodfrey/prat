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

Write-Debug "calling $action script for $($cbt.id), with parameters: ($(ConvertTo-Expression $CommandParameters))"

Invoke-CommandWithCachedEnvDelta {&$script $cbt @CommandParameters} $cbt.cachedEnvDelta -CommandParameters $CommandParameters
