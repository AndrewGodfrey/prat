# .SYNOPSIS
# Resolves a -Focus parameter to a test path, for Pester projects only (wired into
# Test-PratLayer.ps1, the `test` dispatcher for Pester-based projects). Despite the generic name,
# there's no equivalent for pytest/dotnet projects: Invoke-DetectedProjectTest.ps1's pytest path
# forwards Focus to pytest as-is with no source-to-test-file resolution, and its dotnet path
# ignores Focus entirely (always runs the project's single *.Tests.csproj). A -Focus pointing at a
# pytest source file (rather than its test_*.py/*_test.py) won't find its tests via this function.
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
    $withSuffix = if ($resolved -match '\.ps1$') { $resolved -replace '\.ps1$', '.Tests.ps1' } else { $resolved + '.Tests.ps1' }
    $testFileName = Split-Path $withSuffix -Leaf
    $dirFwd = (Split-Path $resolved -Parent) -replace '\\', '/'
    $inTestsSubdir = "$dirFwd/tests/$testFileName"

    # A resolved path that's a plain (non-.Tests.ps1) file may be the source file for a co-located
    # test - prefer that test file, since handing the source file itself to Pester as a literal
    # path bypasses its *.Tests.ps1 discovery filter and executes the source file directly. Tests
    # live either alongside the source (module-dir convention) or in a tests/ subdirectory
    # (pathbin convention) - see prat/README.md's Testing section.
    $isSourceFile = ($resolved -notmatch '\.Tests\.ps1$') -and (Test-Path $resolved -PathType Leaf)
    if ($isSourceFile) {
        if (Test-Path $withSuffix) { return $withSuffix }
        if (Test-Path $inTestsSubdir) { return $inTestsSubdir }
    }

    if (Test-Path $resolved) { return $resolved }
    if (Test-Path $withSuffix) { return $withSuffix }
    if (Test-Path $inTestsSubdir) { return $inTestsSubdir }

    throw "Focus path not found: '$resolved'"
}

$resolved = Resolve-Path (findPath)
$resolved -replace '\\', '/'
