# .SYNOPSIS
# Sets the current working location (like Set-Location), but using a shortcut.
#
# Alias: c
#
# .NOTES
# Shortcuts are interpreted using: 
#  1. Find-Shortcut_<devenv>  
#     i.e. each dev environment can supply one. e.g. see: Find-Shortcut_prat.ps1
#  2. Find-CodebaseShortcut 
#     - its behavior can be extended/overridden by overriding Get-GlobalCodebases (which by default also includes $pwd)
param(
    [ArgumentCompleter(
        {
            param($cmd, $param, $wordToComplete)
            [array] $validValues = &$PSScriptRoot\..\lib\Get-CompletionList.ps1 "Set-LocationUsingShortcut-Shortcut"
            $validValues -like "$wordToComplete*"
        }
        )]   
    $Shortcut="", 
    [switch] $Test, 
    [switch] $ListAll)

function TryAdd($dict, $key, $value) {
    if (!$dict.Contains($key)) {
        $dict.Add($key, $value)
    }
}

function GetAllShortcuts() {
    $result = [System.Collections.Specialized.OrderedDictionary]::new()

    foreach ($globalShortcutFile in (Resolve-PratLibFile "lib/Find-Shortcut.ps1" -ListAll)) {
        $globalShortcuts = &$globalShortcutFile -ListAll
        foreach ($key in ($globalShortcuts.Keys | Sort-Object)) {
            TryAdd $result $key $globalShortcuts[$key]
        }
    }

    $cbts = &$PSScriptRoot/../lib/Find-CodebaseShortcut -ListAll
    foreach ($cbt in $cbts) {
        foreach ($key in ($cbt.shortcuts.Keys | Sort-Object)) {
            TryAdd $result $key ($cbt.root + "/" + $cbt.shortcuts[$key])
        }
    }

    return $result
}

function FindShortcut($Shortcut) {
    foreach ($globalShortcutFile in (Resolve-PratLibFile "lib/Find-Shortcut.ps1" -ListAll)) {
        $result = &$globalShortcutFile $Shortcut
        if ($null -ne $result) { return @{target = $result; cbt = $null} }
    }

    $cbt = &$PSScriptRoot/../lib/Find-CodebaseShortcut $Shortcut
    if ($null -ne $cbt) { 
        return @{target = $cbt.root + "/" + $cbt.shortcuts[$Shortcut]; cbt = $cbt}
    }
    return $null
}

if ($ListAll) {
    return GetAllShortcuts
}

if ($Shortcut -eq "?") {
    return (GetAllShortcuts | Format-Table -HideTableHeaders)
}

function findTestDir($tt) {
    $c = "$($tt)Test"; if (Test-Path $c) { return $c }
    $c = "$($tt)Tests"; if (Test-Path $c) { return $c }
    if (Test-Path $tt) { return $tt }
    while ($true) {
        $parent = Split-Path -Parent $tt
        if ($parent -eq $tt) { break }
        if (Test-Path $parent) { return $parent }
        $tt = $parent
    }
    return $null
}

$result = FindShortcut $Shortcut
if ($null -eq $result) { 
    throw "Unrecognized: $Shortcut" 
}

$target = $result.target
$cbt = $result.cbt
$target = $target -replace '\\', '/'

if ($Test) {    
    if ($null -ne $cbt.irregularTestShorcuts[$Shortcut]) {
        $target = $cbt.root + "/" + $cbt.irregularTestShorcuts[$Shortcut]
    } elseif ($null -ne $cbt.testDirFromDevDir) {
        $testTarget = &$cbt.testDirFromDevDir $target
        $alt = findTestDir $testTarget
        if ($null -ne $alt) { $target = $alt } else {
            Write-Warning "No test dir found, leaving you in dev"
        }
    }
}

cd $target
