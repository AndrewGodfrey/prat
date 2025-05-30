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


Describe "FindShortcut" {
    BeforeEach { 
        function Resolve-PratLibFile($file, [switch] $ListAll) {
            if ($file -ne "lib/Find-Shortcut.ps1") { throw }
            if (!$ListAll) {
                throw
            }
            return @("$PSScriptRoot\mock_Find-Shortcut.ps1")
        }

    }
    It "ReturnsTargetForKnownShortcut" {
        $result = FindShortcut "b"

        $result.target | Should -Be "/a/b"
    }
    It "ReturnsNullForUnknownShortcut" {
        Mock Get-GlobalCodebases { return @() }
        $result = FindShortcut "notExist"

        $result | Should -BeNull
    }
    It "AlsoLooksAtCodebases" {
        function Get-GlobalCodebases {}
        Mock Get-GlobalCodebases { return @('foo') }

        function Get-CodebaseTable($codebase) {}
        Mock Get-CodebaseTable {
            if ($codebase -eq 'foo') {
                return @{ root = '/a'; shortcuts = @{ c = 'b/c' } }
            }
            throw "Unexpected codebase: $codebase"
        }
 
        $result = FindShortcut "c"

        $result.target | Should -Be "/a/b/c"
    }
}