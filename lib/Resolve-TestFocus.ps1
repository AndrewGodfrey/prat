# .SYNOPSIS
# Resolves a -Focus parameter to a test path.
# - No focus: returns "."
# - Absolute path: returns as-is
# - Relative path: joins with RepoRoot
# If the resolved path doesn't exist but $path.Tests.ps1 does, returns that instead.
# Throws if neither path exists.
param([string] $Focus, $RepoRoot)

if (!$Focus) { return "." }

# Expand ~ to home directory before IsPathRooted (which doesn't understand ~)
if ($Focus    -like '~*') { $Focus    = $home + $Focus.Substring(1) }
if ($RepoRoot -like '~*') { $RepoRoot = $home + $RepoRoot.Substring(1) }

function findPath {
    $resolved = if ([System.IO.Path]::IsPathRooted($Focus)) { $Focus } else { Join-Path $RepoRoot $Focus }

    if (Test-Path $resolved) { return $resolved }

    $withSuffix = $resolved + ".Tests.ps1"
    if (Test-Path $withSuffix) { return $withSuffix }

    throw "Focus path not found: '$resolved'"
}

$resolved = Resolve-Path (findPath)
$resolved -replace '\\', '/'
