# .SYNOPSIS
# Builds a codebase
#
# Recommended alias: b
# 
# .NOTES
# What this does, depends on the codebase. It might do nothing.
# The purpose of this is to provide a consistent dev inner loop. I alias 'b' to run this directly, or 'x' to run it as part of a larger loop.
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string] $Path,
    [ValidateSet(
        "build",
        "clean", # TODO: Replace 'clean' with a $Force parameter that can be passed from Start-CodebaseDevLoop.
        "shell"  # Launches the appropriate build shell. For development of new automation, or for quick hacks.
    )] [string] $CommandName="build",
    [switch] $Force,
    [switch] $Quiet
)
if ($Path) { $Path = Expand-TildePath $Path }
if (!$Quiet) { Write-Host -ForegroundColor Green "command: $CommandName" }

$switches = @{Command = $CommandName}
if ($Force)  { $switches['Force']    = $true }
if ($Path)   { $switches['RepoRoot'] = $Path }
&$PSScriptRoot\..\lib\Invoke-CodebaseCommand.ps1 "build" -CommandParameters $switches
