# Looks for a codebase-specific action script
#
# Scripts that use this search $env:path, so that it can be overridden by putting another
# implementation earlier in $env:path.
param(
    [ValidateSet("build", "test", "deploy")] [string] $action,
    [string] $codebase
)

$script = "$PSScriptRoot\..\lib\codebases\$action${codebase}.ps1"
if (Test-Path $script) { return $script }
return $null

