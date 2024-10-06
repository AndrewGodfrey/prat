# Build a codebase
#
# Recommended alias: b
# 
# What this does, depends on the codebase. It might do nothing.
# The purpose of this is to provide a consistent dev inner loop. I alias 'b' to run this directly, or 'x' to run it as part of a larger loop.
[CmdletBinding()]
param(
    [ValidateSet(
        "build", 
        "clean",
        "shell"  # Launches the appropriate build shell. For development of new automation, or for quick hacks.
    )] [string] $command="build"
)

$cbt = &$home\prat\lib\Get-CodebaseTable (Get-Location)
if ($null -eq $cbt) { 
    throw "Unknown codebase - can't build"
}

# Note we depend on PATH to find Get-CodebaseScript. This allows for it to be overridden.
$script = Get-CodebaseScript "build" $cbt.id

if ($null -eq $script) {
    Write-Verbose "build: NOP"
    return
}

Write-Debug "calling $script for ${$cbt.id}"
Invoke-CommandWithCachedEnvDelta {. $script $cbt $command} $cbt.cachedEnvDelta
