BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    function makeProfile($repoDef) {
        "@{ '.' = @{ repos = $repoDef } }" | Out-File $testProfilePath
    }
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
        makeProfile "@{ r = @{ root = '$root/sub' } }"

        Get-PratRepo -Location $root | Should -BeNull
    }

    It "Returns the matching repo for the given location" {
        makeProfile "@{ myrepo = @{ root = '$root' } }"

        (Get-PratRepo -Location $root).id | Should -Be 'myrepo'
    }

    It "Sets subdir as path relative to repo root" {
        New-Item -ItemType Directory "TestDrive:\sub" -Force | Out-Null
        makeProfile "@{ r = @{ root = '$root' } }"

        (Get-PratRepo -Location "$root/sub").subdir | Should -Be "sub"
    }

    It "Throws when multiple repos match the location at the same depth" {
        makeProfile "@{ a = @{ root = '$root' }; b = @{ root = '$root' } }"

        { Get-PratRepo -Location $root } | Should -Throw "Found too many matches"
    }

    It "Returns the most-specific (deepest) repo when nested repos both match" {
        New-Item -ItemType Directory "TestDrive:\sub" -Force | Out-Null
        makeProfile "@{ parent = @{ root = '$root' }; child = @{ root = '$root/sub' } }"

        (Get-PratRepo -Location "$root/sub").id | Should -Be 'child'
    }
}
