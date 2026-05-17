# .SYNOPSIS
# Prebuilds a codebase
#
# Recommended alias: pb
# 
# .NOTES
# The idea of "prebuild" is to install expensive things that are needed (if any) for the "build" step to work.
# Some other common names for this step are "depends", "bootstrap", "prepare".
#
# This is an installation step similar to "deploy", but build depends on this step (whereas "deploy" depends on "build").
#
# -Force: Ignores Prat's installation DB - i.e. acts as if that was empty. But this is not propagated to other package managers e.g. winget.
#         I can only imagine the installation DB being a good idea for some kinds of prebuild action - haven't used it myself yet.
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
&$PSScriptRoot\..\lib\Invoke-CodebaseCommand.ps1 "prebuild" -CommandParameters $params
