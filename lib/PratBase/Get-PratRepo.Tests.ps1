BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
    function makeProfile($repoDef) {
        "@{ '.' = @{ repos = $repoDef } }" | Out-File $testProfilePath
    }
}

Describe "Get-PratRepo" {
    BeforeEach {
        $root = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
        $testProfilePath = "$root/codebaseProfile_test.ps1"
        git -C $root init -q 2>$null
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
    }

    It "Returns null when no codebaseProfile files are found" {
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

    It "Returns the matching repo when the registered root uses backslashes (e.g. from PSScriptRoot)" {
        $backslashRoot = $root -replace '/', '\'
        makeProfile "@{ myrepo = @{ root = '$backslashRoot' } }"

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

    It "Returns the git-root repo (parent), not the nested registration (child), when inside a nested root" {
        New-Item -ItemType Directory "TestDrive:\sub" -Force | Out-Null
        makeProfile "@{ parent = @{ root = '$root' }; child = @{ root = '$root/sub' } }"

        (Get-PratRepo -Location "$root/sub").id | Should -Be 'parent'
    }

    It "Does not match a sibling directory that shares a name prefix" {
        New-Item -ItemType Directory "TestDrive:\myrepo" -Force | Out-Null
        New-Item -ItemType Directory "TestDrive:\myrepo-other" -Force | Out-Null
        makeProfile "@{ myrepo = @{ root = '$root/myrepo' } }"

        Get-PratRepo -Location "$root/myrepo-other" | Should -BeNull
    }

    It "Returns the top-level repo, not the subproject, when location is inside a subproject" {
        New-Item -ItemType Directory "TestDrive:\r\lib\sub" -Force | Out-Null
        git -C "$root/r" init -q 2>$null
        makeProfile "@{ r = @{ root = '$root/r'; subprojects = @{ sub = @{ path = 'lib/sub' } } } }"

        $result = Get-PratRepo -Location "$root/r/lib/sub"

        $result.id   | Should -Be "r"
        $result.root | Should -Be "$root/r"
    }
}
