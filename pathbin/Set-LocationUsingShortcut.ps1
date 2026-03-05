# .SYNOPSIS
# Sets the current working location (like Set-Location), but using a shortcut.
# Command-completion is available for the shortcut parameter.
#
# Alias: c
# The shortcut "?" lists all shortcuts.
#
# .NOTES
# Shortcuts are defined in repoProfile_<devenv>.ps1
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

function GetAllShortcuts() {
    return Find-ProjectShortcut -ListAll
}

function ReverseSearchForShortcut($path) {
    $allShortcuts = GetAllShortcuts
    $path = $path -replace '\\', '/'
    foreach ($key in $allShortcuts.Keys) {
        $target = $allShortcuts[$key] -replace '\\', '/'
        if ($target.endswith('/')) {
            $target = $target.Substring(0, $target.Length - 1)
        }
        if ($path -eq $target -or $path -like "$target/*") {
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

    $target = Find-ProjectShortcut $Shortcut
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
