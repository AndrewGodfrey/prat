# .SYNOPSIS
# Deploys a codebase
#
# Recommended alias: d
#
# .NOTES
# What this does, depends on the codebase. It might do nothing, or deploy to the current machine, or even deploy to remote machines.
# The purpose of this is to provide a consistent dev inner loop. I alias 'd' to run this directly, or 'x' to run it as part of a larger loop.
#
# -Force: Ignores Prat's installation DB - i.e. acts as if that was empty. But this is not propagated to other package managers e.g. winget.
[CmdletBinding()]
param([switch] $Force)

&$PSScriptRoot\..\lib\Invoke-CodebaseCommand.ps1 "deploy" @("-Force", $Force)
