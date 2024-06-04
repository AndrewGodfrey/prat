# .SYNOPSIS
# Look for the given dir/file, beginning in the starting dir, following parent dirs.
# Like the way ".git" or ".hg" directories work.
[CmdletBinding()]
param($itemToFind, $startingDir, [switch] $Multiple)

$searchDir = Resolve-Path $startingDir
$candidate = $null
do {
    $candidate = Join-Path $searchDir $itemToFind
    Write-Verbose "Test: $candidate"
    if (Test-Path $candidate) { break }
    
    $parentDir = (Split-Path -Parent $searchDir)
    if ($parentDir.Length -eq 0) {
        return $null
    }
    $searchDir = $parentDir
    Write-Verbose "Next searchDir: $searchDir"
} while ($true);

# When "$itemToFind" has wildcards, then we expect to see exactly one match.

$results = @()
$results += Get-ChildItem $candidate
if ($Multiple) { return $results }
if ($results.Length -gt 1) {
    Write-Warning "Multiple matches found - ignoring them all"
    return $null
}
return $results[0]

