BeforeAll {
    Import-Module "$PSScriptRoot\PratBase.psd1" -Force
}

Describe "Get-PratRepoIndex" {
    InModuleScope PratBase {
        BeforeEach {
            $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        }

        It "Returns null when given an empty list" {
            Get-PratRepoIndex @() | Should -BeNull
        }

        It "Returns null when given null" {
            Get-PratRepoIndex $null | Should -BeNull
        }

        It "Sets repo id from its key name" {
            "@{ '.' = @{ repos = @{ myrepo = @{} } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["myrepo"].id | Should -Be "myrepo"
        }

        It "Repo root defaults to sectionRoot/id; '.' resolves to file directory" {
            "@{ '.' = @{ repos = @{ myrepo = @{} } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["myrepo"].root | Should -Be "$dir/myrepo"
        }

        It "Repo root defaults to sectionRoot/id when section key is an absolute path" {
            "@{ 'C:/base' = @{ repos = @{ myrepo = @{} } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["myrepo"].root | Should -Be "C:/base/myrepo"
        }

        It "Relative section key is resolved against the file's directory" {
            New-Item -ItemType Directory "TestDrive:\subdir" | Out-Null
            "@{ 'subdir' = @{ repos = @{ r = @{} } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["r"].root | Should -Be "$dir/subdir/r"
        }

        It "Uses explicit absolute per-repo root when specified" {
            "@{ '.' = @{ repos = @{ r = @{ root = 'C:/explicit' } } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["r"].root | Should -Be "C:/explicit"
        }

        It "Resolves explicit relative per-repo root against section root" {
            "@{ 'C:/base' = @{ repos = @{ r = @{ root = 'nested/sub' } } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["r"].root | Should -Be "C:/base/nested/sub"
        }

        It "Resolves explicit relative per-repo root against '.' section root" {
            "@{ '.' = @{ repos = @{ r = @{ root = 'nested/sub' } } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["r"].root | Should -Be "$dir/nested/sub"
        }

        It "Strips trailing path separator from root" {
            "@{ '.' = @{ repos = @{ r = @{ root = 'C:/myroot/' } } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["r"].root | Should -Be "C:/myroot"
        }

        It "Relative shortcut paths are resolved against the '.' section root (file dir)" {
            "@{ '.' = @{ repos = @{ r = @{} }; shortcuts = @{ sub = 'subdir' } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).shortcuts["sub"] | Should -Be "$dir/subdir"
        }

        It "Relative shortcut paths are resolved against an explicit section root" {
            "@{ 'C:/git' = @{ repos = @{ r = @{} }; shortcuts = @{ sub = 'subdir' } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).shortcuts["sub"] | Should -Be "C:/git/subdir"
        }

        It "Leaves already-absolute shortcut paths unchanged" {
            "@{ '.' = @{ repos = @{ r = @{} }; shortcuts = @{ s = 'C:/abs' } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).shortcuts["s"] | Should -Be "C:/abs"
        }

        It "Adds implicit shortcut id->root for each repo" {
            "@{ '.' = @{ repos = @{ myrepo = @{} } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).shortcuts["myrepo"] | Should -Be "$dir/myrepo"
        }

        It "Explicit shortcut overrides implicit id->root shortcut" {
            "@{ '.' = @{ repos = @{ r = @{} }; shortcuts = @{ r = 'override' } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).shortcuts["r"] | Should -Be "$dir/override"
        }

        It "Repo-level shortcuts are resolved relative to the repo root" {
            "@{ '.' = @{ repos = @{ r = @{ root = 'C:/myrepo'; shortcuts = @{ sub = 'lib' } } } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).shortcuts["sub"] | Should -Be "C:/myrepo/lib"
        }

        It "Merges repos and shortcuts from multiple files, first-file-wins for shortcuts" {
            "@{ '.' = @{ repos = @{ repoA = @{} }; shortcuts = @{ shared = '/from-file1' } } }" | Out-File "TestDrive:\repoProfile_a.ps1"
            "@{ '.' = @{ repos = @{ repoB = @{} }; shortcuts = @{ shared = '/from-file2' } } }" | Out-File "TestDrive:\repoProfile_b.ps1"
            $index = Get-PratRepoIndex @("$dir/repoProfile_a.ps1", "$dir/repoProfile_b.ps1")
            $index.repos.Keys | Should -Contain "repoA"
            $index.repos.Keys | Should -Contain "repoB"
            $index.shortcuts["shared"] | Should -Be "/from-file1"
        }

        It "Resolves a relative string command property to absolute path (relative to repoProfile dir)" {
            "@{ '.' = @{ repos = @{ r = @{ test = 'commands/test.ps1' } } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["r"].test | Should -Be "$dir/commands/test.ps1"
        }

        It "Leaves an already-absolute string command property unchanged" {
            "@{ '.' = @{ repos = @{ r = @{ test = 'C:/absolute/test.ps1' } } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["r"].test | Should -Be "C:/absolute/test.ps1"
        }

        It "Leaves a scriptblock command property as a scriptblock" {
            "@{ '.' = @{ repos = @{ r = @{ test = { 'hello' } } } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
            (Get-PratRepoIndex @("$dir/repoProfile_test.ps1")).repos["r"].test | Should -BeOfType [scriptblock]
        }
    }
}
