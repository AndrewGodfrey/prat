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
param(
    [Parameter(Position=0)]
    [string] $Path,
    [switch] $Force
)

$repoRoot = $null
if ($Path) {
    $Path = Expand-TildePath $Path
    if (-not [System.IO.Path]::IsPathRooted($Path)) { throw "Path must be absolute." }
    $project      = Get-PratProject -Location $Path
    if (-not $project) { throw "Not a registered project root: $Path" }
    $resolvedPath = (Resolve-Path $Path).Path -replace '\\', '/'
    if ($resolvedPath -ne ($project.root -replace '\\', '/')) {
        throw "Path must be the project root, not a subdirectory: $Path"
    }
    $repoRoot = $project.root
}

$params = @{Force = [bool]$Force}
if ($repoRoot) { $params['RepoRoot'] = $repoRoot }
&$PSScriptRoot\..\lib\Invoke-CodebaseCommand.ps1 "deploy" -CommandParameters $params
