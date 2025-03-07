# .SYNOPSIS
# Tests a codebase
# (i.e. Runs unit tests)
#
# Recommended alias: t
#
# .NOTES
# What this does, depends on the codebase. It might do nothing.
# The purpose of this is to provide a consistent dev inner loop. I alias 't' to run this directly, or 'x' to run it as part of a larger loop.

[CmdletBinding()]
param()

&$PSScriptRoot\..\lib\Invoke-CodebaseCommand.ps1 "test"
