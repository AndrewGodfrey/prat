# .SYNOPSIS
# Given a location/pwd, finds what codebase it's 'in'.
# This controls the behavior of various other tools.
#
# Relies on information kept in 'cbTable.*.ps1' files.
# These can either be included in a git repo (for projects you own), or
# in a parent folder.
# 
#
# Limitations: 
#   Currently, only the nearest parent directory containing a cbTable.ps1 file is used.
#   I could imagine one day needing to override a cbTable.*.ps1 that's checked in.
#
# Design: 
#   The contents of a cbTable.*.ps1 files need to be kept simple, because they are going to be executed by the prompt when the current directory
#   changes. I tried putting a scriptblock for 'howToTest' in there and had problems that were hard to debug. So, making it a string instead
#   and avoiding scriptblocks.
#
#
# Input properties from the cbTable: The cbTable is a table of hashtables, key being the codebase nickname.
# Each codebase table has these properties:
#   root:                      The root directory of the codebase - e.g. probably the location that .git and .gitignore are in.
#   howToBuild, 
#     howToTest, 
#     howToDeploy:             Optional - gives the command to run when the user invokes Build-Codebase (alias: b), Test-Codebase (alias: t) 
#                              or Deploy-Codebase (alias: d).
#   shortcuts, 
#     irregularTestShortcuts:  Optional table of shortcuts for use by Set-LocationUsingShortcut (alias: c).
#   workspaces: 
#   cachedEnvData:             An optional filename that stores a cached EnvDelta for the codebase. Must end in '.ps1'. 
#                              e.g. "$home\prat\auto\cachedEnvDelta\envForCmake.ps1"
#                              You'd populate it using Install-CachedEnvDelta from a deployment script.
#
# Other properties added to the $cbt object:
#   subdir:                    A path for the given $Location, relative to $root

using module PratBase\PratBase.psd1

#TODO: Resolve confusion between "cbtable" in filename, and this script which only returns one entry.
#      And reconcile with Get-CodebaseSubTable.

[CmdletBinding()]
param ([string] $Location = $pwd)

$cbTable = &$PSScriptRoot\Get-CodebaseTables $Location
if ($null -eq $cbTable) { return $null }

[System.IO.DirectoryInfo] $locationDI = $Location

$results = @()

foreach ($item in $cbTable.Values) {
    Write-Verbose "Get-CodebaseTable: Considering: $($item.id)"
    [System.IO.DirectoryInfo] $rootDI = $item.root
    Write-Verbose "Get-CodebaseTable: Compare: '$($rootDI.FullName)' vs '$($locationDI.FullName)'"
    if ($locationDI.FullName.StartsWith($rootDI.FullName, 'InvariantCultureIgnoreCase')) {
        Write-Verbose "Get-CodebaseTable: Found: $($item | Out-String)" # This doesn't show scriptblocks properly, but at least it doesn't hang like ConvertTo-Expression!
        $results += $item
    }
}
Write-Verbose "Get-CodebaseTable: Found $($results.Length) matches"

if ($results.Length -eq 0) { return $null }
if ($results.Length -gt 1) { throw "Found too many matches in $cbFile" }

$item = $results[0]
$item.subdir = Get-RelativePath $item.root $Location
return $item
