BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1" -Force
    . Set-LocationUsingShortcut.ps1
}

Describe "Set-LocationUsingShortcut" {
    BeforeEach {
        pushd
        Set-Location "\"
        $startingPath = $pwd.Path

        Mock Find-ProjectShortcut {
            if ($Shortcut -eq "hosts") {
                return "C:\WINDOWS\system32\drivers\etc"
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


Describe "ReverseSearchForShortcut" {
    It "Does not match a sibling path that shares a name prefix" {
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        $testProfilePath = "$dir/repoProfile_test.ps1"
        "@{ '.' = @{ repos = @{ myrepo = @{ root = '$dir/myrepo' } } } }" | Out-File $testProfilePath
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }

        $result = ReverseSearchForShortcut "$dir/myrepo-other"

        $result | Should -BeNull
    }

    It "Matches when exactly at the shortcut target" {
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        $testProfilePath = "$dir/repoProfile_test.ps1"
        "@{ '.' = @{ repos = @{ myrepo = @{ root = '$dir/myrepo' } } } }" | Out-File $testProfilePath
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }

        $result = ReverseSearchForShortcut "$dir/myrepo"

        $result | Should -Be "myrepo"
    }
}

