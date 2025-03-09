# .SYNOPSIS
# Sets the current working location (like Set-Location), but using a shortcut.
# Command-completion is available for the shortcut parameter.
#
# Alias: c
# The shortcut "?" lists all shortcuts.
#
# .NOTES
# Shortcuts are interpreted using: 
#  1. Find-Shortcut_<devenv>  
#     i.e. each dev environment can supply one. e.g. see: Find-Shortcut_prat.ps1
#  2. Find-CodebaseShortcut 
#     - its behavior can be extended/overridden by overriding Get-GlobalCodebases (which by default also includes $pwd)
#
# .EXAMPLE
# c appdata
#
# .EXAMPLE
# c ?
# hosts                          C:\WINDOWS\system32\drivers\etc
#    [and so on...]
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

$result = FindShortcut $Shortcut
if ($null -eq $result) { 
    throw "Unrecognized: $Shortcut" 
}

$target = $result.target
$cbt = $result.cbt
$target = $target -replace '\\', '/'

if ($Test) {
    $testTarget = Push-UnitTestDirectory $target -JustReturnIt
    if ($null -ne $testTarget) {
        $target = $testTarget
    } else {
        Write-Warning "No test dir found, leaving you in dev"
    }
}

Set-Location $target
