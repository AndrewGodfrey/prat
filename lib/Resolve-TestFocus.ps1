# .SYNOPSIS
# Resolves a -Focus parameter to a test path.
# - No focus: returns "."
# - Absolute path: returns as-is
# - Relative path: joins with RepoRoot
param([string] $Focus, $RepoRoot)

if (!$Focus) {
    return "."
} elseif ([System.IO.Path]::IsPathRooted($Focus)) {
    return $Focus
} else {
    return Join-Path $RepoRoot $Focus
}
