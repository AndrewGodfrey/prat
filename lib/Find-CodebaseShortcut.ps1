# Finds a shortcut definition from a list of shortcuts defined in various codebases
# Actually returns the codebase table the shortcut is in, rather than the shortcut target itself. (More useful).
#
# Test case: ~\prat\lib\Find-CodebaseShortcut.ps1 -ListAll | % { $root = $_.root; $_.shortcuts.Values | % {"$root/$_"} }
param($Shortcut, [switch] $ListAll)

# This is the set of codebase locations to search. Can include $pwd (Get-CodebaseTable will find the codebase $pwd is in).
# Can be overridden by putting a different Get-GlobalCodebases.ps1 earlier in $env:path.
#
# Unrecognized locations will be silently ignored.
$codebaseLocations = Get-GlobalCodebases

$results = @()

$rootsFound = @{}

foreach ($codebaseLocation in $codebaseLocations) {
    $cbt = &$PSScriptRoot/Get-CodebaseTable $codebaseLocation

    if ($null -ne $cbt) {
        if ($rootsFound[$cbt.root]) { continue }
        $rootsFound[$cbt.root] = $true
        if ($null -ne $cbt.shortcuts) {
            if ($ListAll) { 
                $results += $cbt 
            } else {
                if ($null -ne ($cbt.shortcuts[$Shortcut])) { return $cbt }
            }
        }
    }
}

if ($ListAll) { return $results }

return $null

