# .SYNOPSIS
# Given a location, finds which codebase it's in.
# Searches repos registered in repoProfile.*.ps1 files at locations returned by Get-GlobalCodebases.
#
# Other properties added to the returned object:
#   subdir: path of $Location relative to the repo root
using module PratBase\PratBase.psd1

[CmdletBinding()]
param ([string] $Location = $pwd)

$Location = Resolve-Path $Location

function Get-CodebaseTables { &$PSScriptRoot/Get-CodebaseTables @args }

$codebaseLocations = Get-GlobalCodebases

[System.IO.DirectoryInfo] $locationDI = $Location
$seenRepos = @{}
$results   = @()

foreach ($dir in $codebaseLocations) {
    $tables = Get-CodebaseTables $dir
    if ($null -eq $tables) { continue }
    foreach ($repo in $tables.repos.Values) {
        $repoKey = "$($repo.id)::$($repo.root)"
        if ($seenRepos[$repoKey]) { continue }
        $seenRepos[$repoKey] = $true
        [System.IO.DirectoryInfo] $rootDI = $repo.root
        Write-Verbose "Get-PratRepo: Considering: $($repo.root)"
        if ($locationDI.FullName.StartsWith($rootDI.FullName, 'InvariantCultureIgnoreCase')) {
            Write-Verbose "Get-PratRepo: Match: $($repo.id)"
            $results += $repo
        }
    }
}

Write-Verbose "Get-PratRepo: Found $($results.Length) matches"
if ($results.Length -eq 0) { return $null }

# If multiple repos match (e.g. a nested repo inside another), pick the most-specific one (longest root).
# Throw only if two repos are tied at the same root length — that's genuine ambiguity.
if ($results.Length -gt 1) {
    $results  = @($results | Sort-Object { $_.root.Length } -Descending)
    $topLen   = $results[0].root.Length
    $results  = @($results | Where-Object { $_.root.Length -eq $topLen })
    if ($results.Length -gt 1) { throw "Found too many matches" }
}

$item = $results[0]
$item.subdir = Get-RelativePath $item.root $Location
return $item
