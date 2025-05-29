BeforeAll {
    . Set-LocationUsingShortcut.ps1
}

Describe "Set-LocationUsingShortcut" {
    BeforeEach { 
        pushd
        Set-Location "\" 
        $startingPath = $pwd.Path

        Mock FindShortcut { 
            if ($Shortcut -eq "hosts") {
                return @{ target = "C:\WINDOWS\system32\drivers\etc" }
            } else {
                return $null
            }
        }

        $allShortcuts = @{
            "a" = "\foo\a"
            "b" = "\foo\b"
            "c" = "\foo\c"
        }
        Mock GetAllShortcuts {
            return $allShortcuts
        }
    }
    AfterEach { popd }
    It "SetsPwdToFoundShortcut" {
        Set-LocationUsingShortcut -Shortcut "hosts"

        $pwd.Path | Should -Be "C:\WINDOWS\system32\drivers\etc"
    }
    It "IntegratesWithPush-UnitTestDirectory" {
        function Push-UnitTestDirectory ($CodeDir, [switch] $JustReturnIt) {
            if (($CodeDir -eq "C:/WINDOWS/system32/drivers/etc") -and $JustReturnIt) {
                return "C:\Windows"
            }
            throw "Unexpected: $Target"
        }
        Set-LocationUsingShortcut -Shortcut "hosts" -Test

        $pwd.Path | Should -Be "C:\Windows"
    }
    It "ThrowsWhenShortcutUnrecognized" {
        {Set-LocationUsingShortcut -Shortcut "notExist"} | Should -Throw "Unrecognized: notExist"

        $pwd.Path | Should -Be $startingPath
    }
    It "WarnsWhenTestDirectoryNotFound" {
        function Push-UnitTestDirectory { return $null }

        $warnings = Set-LocationUsingShortcut -Shortcut "hosts" -Test 3>&1
        
        $warnings[0] | Should -Be "No test dir found, leaving you in dev"
        $pwd.Path | Should -Be "C:\WINDOWS\system32\drivers\etc"
    }
    It "CanListAllShortcuts" {
        $result = Set-LocationUsingShortcut -ListAll

        $result | Should -Be $allShortcuts
    }
}

<#
Describe "Find-Shortcut" {
    BeforeEach { 
        function Resolve-PratLibFile($file, [switch] $ListAll) {
            if ($file -ne "lib/Find-Shortcut.ps1") { throw }
            if ($ListAll) {
                throw
            }
            return "$PSScriptRoot\lib\Find-Shortcut.ps1"
        }

    }
    It "ReturnsTargetForKnownShortcut" {
        $result = Find-Shortcut "hosts"

        $result.target | Should -Be "C:\WINDOWS\system32\drivers\etc"
    }
    It "ReturnsNullForUnknownShortcut" {
        $result = Find-Shortcut "notExist"

        $result | Should -BeNull
    }
}#>