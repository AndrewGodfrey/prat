# Searches all repos known to Get-GlobalCodebases, for navigation shortcuts.
#
# With -ListAll:  Returns an ordered dictionary of all shortcuts.
# Otherwise:      Returns the absolute path for the given shortcut name, or $null if not found.
[CmdletBinding()]
param($Shortcut, [switch] $ListAll)

function Get-CodebaseTables { &$PSScriptRoot/Get-CodebaseTables @args }

$codebaseLocations = Get-GlobalCodebases
$allShortcuts      = [ordered]@{}
$seenRoots         = @{}

foreach ($loc in $codebaseLocations) {
    Write-Verbose "Find-CodebaseShortcut: $loc"
    $tables = Get-CodebaseTables $loc
    if ($null -eq $tables) { continue }

    # Track repo roots so duplicate repoProfile coverage from multiple locations doesn't double shortcuts
    $anyNewRoot = $false
    foreach ($repo in $tables.repos.Values) {
        if (-not $seenRoots[$repo.root]) {
            $seenRoots[$repo.root] = $true
            $anyNewRoot = $true
        }
    }
    if (-not $anyNewRoot -and $tables.repos.Count -gt 0) { continue }

    foreach ($name in $tables.shortcuts.Keys) {
        if (-not $allShortcuts.Contains($name)) {
            $allShortcuts[$name] = $tables.shortcuts[$name]
        }
    }
}

if ($ListAll) { return $allShortcuts }
if ($allShortcuts.Contains($Shortcut)) { return $allShortcuts[$Shortcut] }
return $null
