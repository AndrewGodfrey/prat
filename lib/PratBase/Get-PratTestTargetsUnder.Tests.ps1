BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-PratTestTargetsUnder" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        $testProfilePath = "$root/codebaseProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
    }

    # Each test uses its own uniquely-named repo directory — TestDrive persists across It blocks
    # within a Describe, so a shared path would leak files (e.g. a marker) between tests.

    It "returns a subproject that declares its own test script" {
        New-Item -ItemType Directory "$root/repoDeclared/lib/sub" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repoDeclared = @{ root = '$root/repoDeclared'; subprojects = @{ sub = @{ path = 'lib/sub'; test = 'lib/sub/test_sub.ps1' } } } } } }" |
            Out-File $testProfilePath

        $result = @(Get-PratTestTargetsUnder "$root/repoDeclared")

        $result.Count | Should -Be 1
        $result[0].id | Should -Be "repoDeclared/sub"
        # Relative `test` paths resolve against the repoProfile *file's* directory ($root), not the
        # subproject's own root — see Get-PratRepoIndex.Tests.ps1's "command properties" context.
        $result[0].test | Should -Be "$root/lib/sub/test_sub.ps1"
    }

    It "auto-detects a subproject with no declared test but a pyproject.toml" {
        New-Item -ItemType Directory "$root/repoPyproject/lib/sub" -Force | Out-Null
        New-Item "$root/repoPyproject/lib/sub/pyproject.toml" -ItemType File | Out-Null
        "@{ '.' = @{ repos = @{ repoPyproject = @{ root = '$root/repoPyproject'; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" |
            Out-File $testProfilePath

        $result = @(Get-PratTestTargetsUnder "$root/repoPyproject")

        $result.Count | Should -Be 1
        $result[0].id | Should -Be "repoPyproject/sub"
        $result[0].test | Should -Match 'Invoke-DetectedProjectTest\.ps1$'
    }

    It "excludes a subproject with no declared test and no detectable marker" {
        New-Item -ItemType Directory "$root/repoNoMarker/lib/sub" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repoNoMarker = @{ root = '$root/repoNoMarker'; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" |
            Out-File $testProfilePath

        @(Get-PratTestTargetsUnder "$root/repoNoMarker").Count | Should -Be 0
    }

    It "excludes the root project itself, even though its own root is registered" {
        "@{ '.' = @{ repos = @{ repoSelf = @{ root = '$root/repoSelf'; test = 'test_repo.ps1' } } } }" |
            Out-File $testProfilePath

        @(Get-PratTestTargetsUnder "$root/repoSelf").Count | Should -Be 0
    }

    It "includes a sibling repo that is registered separately but physically nested under the root" {
        New-Item -ItemType Directory "$root/repoSibling/lib/sibling" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repoSibling = @{ root = '$root/repoSibling' }; sibling = @{ root = '$root/repoSibling/lib/sibling'; test = 'test_sibling.ps1' } } } }" |
            Out-File $testProfilePath

        $result = @(Get-PratTestTargetsUnder "$root/repoSibling")

        $result.Count | Should -Be 1
        $result[0].id | Should -Be "sibling"
    }

    It "excludes a sibling repo marked excludeFromAggregation, even with a declared test" {
        New-Item -ItemType Directory "$root/repoOptOut/lib/fixture" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repoOptOut = @{ root = '$root/repoOptOut' }; fixture = @{ root = '$root/repoOptOut/lib/fixture'; test = 'test_fixture.ps1'; excludeFromAggregation = `$true } } } }" |
            Out-File $testProfilePath

        @(Get-PratTestTargetsUnder "$root/repoOptOut").Count | Should -Be 0
    }

    It "excludes a project outside the root entirely" {
        New-Item -ItemType Directory "$root/repoOutside" -Force | Out-Null
        New-Item -ItemType Directory "$root/otherOutside" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repoOutside = @{ root = '$root/repoOutside' }; otherOutside = @{ root = '$root/otherOutside'; test = 'test_other.ps1' } } } }" |
            Out-File $testProfilePath

        @(Get-PratTestTargetsUnder "$root/repoOutside").Count | Should -Be 0
    }

    It "returns an empty list when no repoProfile files are registered" {
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @() }

        @(Get-PratTestTargetsUnder "$root/repoEmpty").Count | Should -Be 0
    }
}
