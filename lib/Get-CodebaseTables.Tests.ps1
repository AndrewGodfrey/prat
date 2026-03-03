BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Get-CodebaseTables" {

    It "Returns null when directory has no repoProfile files" {
        New-Item -ItemType Directory "TestDrive:\empty" | Out-Null
        $result = &$scriptToTest (Get-Item "TestDrive:\empty").FullName
        $result | Should -BeNull
    }

    It "Returns null for a non-existent directory" {
        $result = &$scriptToTest "TestDrive:\doesNotExist"
        $result | Should -BeNull
    }

    It "Sets repo id from its key name" {
        "@{ repos = @{ myrepo = @{} } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.repos["myrepo"].id | Should -Be "myrepo"
    }

    It "Repo root defaults to fileRoot/id when no file-level root" {
        "@{ repos = @{ myrepo = @{} } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.repos["myrepo"].root | Should -Be "$dir/myrepo"
    }

    It "Repo root defaults to fileRoot/id when file-level root is set" {
        "@{ root = 'C:/base'; repos = @{ myrepo = @{} } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.repos["myrepo"].root | Should -Be "C:/base/myrepo"
    }

    It "Uses explicit per-repo root when specified" {
        "@{ repos = @{ r = @{ root = 'C:/explicit' } } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.repos["r"].root | Should -Be "C:/explicit"
    }

    It "Strips trailing path separator from root" {
        "@{ repos = @{ r = @{ root = 'C:/myroot/' } } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.repos["r"].root | Should -Be "C:/myroot"
    }

    It "Makes relative shortcut paths absolute relative to file root" {
        "@{ repos = @{ r = @{} }; shortcuts = @{ sub = 'subdir' } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.shortcuts["sub"] | Should -Be "$dir/subdir"
    }

    It "Leaves already-absolute shortcut paths unchanged" {
        "@{ repos = @{ r = @{} }; shortcuts = @{ s = 'C:/abs' } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.shortcuts["s"] | Should -Be "C:/abs"
    }

    It "Adds implicit shortcut id->root for each repo" {
        "@{ repos = @{ myrepo = @{} } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.shortcuts["myrepo"] | Should -Be "$dir/myrepo"
    }

    It "Explicit shortcut overrides implicit id->root shortcut" {
        "@{ repos = @{ r = @{} }; shortcuts = @{ r = 'override' } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.shortcuts["r"] | Should -Be "$dir/override"
    }

    It "Each repo root defaults to fileRoot/id when no file-level root and no per-repo root" {
        "@{ repos = @{ repoA = @{}; repoB = @{} } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.repos["repoA"].root | Should -Be "$dir/repoA"
        $result.repos["repoB"].root | Should -Be "$dir/repoB"
    }

    It "Repo-level shortcuts are resolved relative to the repo root" {
        "@{ repos = @{ r = @{ root = 'C:/myrepo'; shortcuts = @{ sub = 'lib' } } } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.shortcuts["sub"] | Should -Be "C:/myrepo/lib"
    }

    It "Repo-level absolute shortcut paths are kept as-is" {
        "@{ repos = @{ r = @{ root = 'C:/myrepo'; shortcuts = @{ abs = 'C:/other' } } } }" | Out-File "TestDrive:\repoProfile.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.shortcuts["abs"] | Should -Be "C:/other"
    }

    It "Loads multiple repoProfile files from the same directory" {
        "@{ repos = @{ repoA = @{} } }" | Out-File "TestDrive:\repoProfile.a.ps1"
        "@{ repos = @{ repoB = @{} } }" | Out-File "TestDrive:\repoProfile.b.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result.repos.Keys | Should -Contain "repoA"
        $result.repos.Keys | Should -Contain "repoB"
    }
}
