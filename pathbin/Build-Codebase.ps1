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
        "clean", # TODO: Replace 'clean' with a $Force parameter that can be passed from Start-CodebaseDevLoop.
        "shell"  # Launches the appropriate build shell. For development of new automation, or for quick hacks.
    )] [string] $command="build",
    [switch] $Force,
    [switch] $Quiet
)
if (!$Quiet) { Write-Host -ForegroundColor Green "command: $command" }

&$PSScriptRoot\..\lib\Invoke-CodebaseCommand.ps1 "build" @($command, "-Force", $Force)
