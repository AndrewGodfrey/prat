# .SYNOPSIS
# Resolves a -Focus parameter to a test path.
# - No focus + RepoRoot: returns RepoRoot
# - No focus, no RepoRoot: returns "."
# - Absolute path: returns as-is (after Resolve-Path)
# - Relative path: joins with RepoRoot
# If the resolved path doesn't exist but $path.Tests.ps1 does, returns that instead.
# Throws if neither path exists.
param([string] $Focus, $RepoRoot)

if (!$Focus) {
    if ($RepoRoot) {
        return (Expand-TildePath $RepoRoot) -replace '\\', '/'
    }
    return "."
}

$Focus    = Expand-TildePath $Focus
$RepoRoot = Expand-TildePath $RepoRoot

function findPath {
    $resolved = if ([System.IO.Path]::IsPathRooted($Focus)) { $Focus } else { Join-Path $RepoRoot $Focus }

    if (Test-Path $resolved) { return $resolved }

    $withSuffix = $resolved + ".Tests.ps1"
    if (Test-Path $withSuffix) { return $withSuffix }

    throw "Focus path not found: '$resolved'"
}

$resolved = Resolve-Path (findPath)
$resolved -replace '\\', '/'
