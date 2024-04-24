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
if ($cbt -eq $null) { 
    throw "Unknown codebase - can't build"
}
if ($cbt.howToBuild -ne $null) {
    &$cbt.howToBuild
} else {
    # Note we depend on PATH to find Get-CodebaseScript. This allows for it to be overridden.
    $script = Get-CodebaseScript "build" $cbt.id

    if ($script -eq $null) {
        Write-Verbose "build: NOP"
    } else {
        Write-Debug "calling $script for ${$cbt.id}"
        . $script $cbt $command
    }
}
