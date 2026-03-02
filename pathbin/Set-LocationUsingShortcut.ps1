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
#     - returns a flat name->path dict from all codebases in Get-GlobalCodebases
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

    $cbShortcuts = &$PSScriptRoot/../lib/Find-CodebaseShortcut -ListAll
    foreach ($key in ($cbShortcuts.Keys | Sort-Object)) {
        TryAdd $result $key $cbShortcuts[$key]
    }

    return $result
}

function FindShortcut($Shortcut) {
    foreach ($globalShortcutFile in (Resolve-PratLibFile "lib/Find-Shortcut.ps1" -ListAll)) {
        $result = &$globalShortcutFile $Shortcut
        if ($null -ne $result) { return $result }
    }
    return &$PSScriptRoot/../lib/Find-CodebaseShortcut $Shortcut
}

function ReverseSearchForShortcut($path) {
    $allShortcuts = GetAllShortcuts
    $path = $path -replace '\\', '/'
    foreach ($key in $allShortcuts.Keys) {
        $target = $allShortcuts[$key] -replace '\\', '/'
        if ($target.endswith('/')) {
            $target = $target.Substring(0, $target.Length - 1)
        }
        if ($path -like "$target*") {
            return $key
        }
    }
    return $null
}

if ($MyInvocation.InvocationName -ne ".") {
    if ($ListAll) {
        return GetAllShortcuts
    }

    if ($Shortcut -eq "?") {
        return (GetAllShortcuts | Format-Table -HideTableHeaders)
    }

    if ($Shortcut -eq ".") {
        $rev = ReverseSearchForShortcut $pwd.Path
        if ($null -ne $rev) {
            Write-Output $rev
        } else {
            Write-Warning "No shortcut found for $pwd"
        }
        return
    }

    $target = FindShortcut $Shortcut
    if ($null -eq $target) {
        throw "Unrecognized: $Shortcut"
    }

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
}
