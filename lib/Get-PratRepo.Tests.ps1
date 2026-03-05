BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
}

Describe "Get-PratRepo" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $testProfilePath = "$root\repoProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
    }

    It "Returns null when no repoProfile files are found" {
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @() }

        Get-PratRepo -Location $root | Should -BeNull
    }

    It "Returns null when location is not inside any repo root" {
        "@{ '.' = @{ repos = @{ r = @{ root = '$root/sub' } } } }" | Out-File $testProfilePath

        Get-PratRepo -Location $root | Should -BeNull
    }

    It "Returns the matching repo for the given location" {
        "@{ '.' = @{ repos = @{ myrepo = @{ root = '$root' } } } }" | Out-File $testProfilePath

        (Get-PratRepo -Location $root).id | Should -Be 'myrepo'
    }

    It "Sets subdir as path relative to repo root" {
        New-Item -ItemType Directory "TestDrive:\sub" -Force | Out-Null
        "@{ '.' = @{ repos = @{ r = @{ root = '$root' } } } }" | Out-File $testProfilePath

        (Get-PratRepo -Location (Get-Item "TestDrive:\sub").FullName).subdir | Should -Be "sub"
    }

    It "Throws when multiple repos match the location at the same depth" {
        "@{ '.' = @{ repos = @{ a = @{ root = '$root' }; b = @{ root = '$root' } } } }" | Out-File $testProfilePath

        { Get-PratRepo -Location $root } | Should -Throw "Found too many matches"
    }

    It "Returns the most-specific (deepest) repo when nested repos both match" {
        New-Item -ItemType Directory "TestDrive:\sub" -Force | Out-Null
        "@{ '.' = @{ repos = @{ parent = @{ root = '$root' }; child = @{ root = '$root/sub' } } } }" | Out-File $testProfilePath

        (Get-PratRepo -Location (Get-Item "TestDrive:\sub").FullName).id | Should -Be 'child'
    }
}
