BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = "$PSScriptRoot/Invoke-DetectedProjectTest.ps1"
    function Invoke-PytestWithSummary(
        [string[]]$TestArgs, [string]$OutputDir, [string]$RepoRoot,
        [string]$WorkingDir, [switch]$NoCoverage, [switch]$PassThru) {}
    function Invoke-DotnetTestWithSummary(
        [string[]]$TestArgs, [string]$OutputDir, [string]$RepoRoot, [string]$WorkingDir,
        [switch]$NoCoverage, [switch]$NoBuild, [string]$WorkspaceFile, [switch]$UseAlternateCollector, [switch]$PassThru) {}
}

Describe "Invoke-DetectedProjectTest.ps1 (pytest)" {
    BeforeAll {
        Mock Invoke-PytestWithSummary {}
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        New-Item -ItemType Directory "$root/myrepo/lib/myproject" -Force | Out-Null
        New-Item "$root/myrepo/lib/myproject/pyproject.toml" -ItemType File | Out-Null
        $project = @{ root = "$root/myrepo/lib/myproject"; id = "myrepo/myproject"; repo = @{ root = "$root/myrepo" } }
    }

    It "uses the project root for RepoRoot and WorkingDir" {
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-PytestWithSummary -ParameterFilter {
            $RepoRoot -eq $project.root -and $WorkingDir -eq $project.root
        }
    }

    It "wires OutputDir through from Get-ProjectTestOutputDir" {
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-PytestWithSummary -ParameterFilter { $OutputDir -eq (Get-ProjectTestOutputDir $project) }
    }

    It "supports -NoCoverage" {
        & $scriptToTest $project -CommandParameters @{NoCoverage = $true}
        Should -Invoke Invoke-PytestWithSummary -ParameterFilter { $NoCoverage -eq $true }
    }

    It "forwards -PassThru and returns result" {
        Mock Invoke-PytestWithSummary { @{ Passed = 5; Failed = 0 } }
        $result = & $scriptToTest $project -CommandParameters @{PassThru = $true}
        Should -Invoke Invoke-PytestWithSummary -ParameterFilter { $PassThru -eq $true }
        $result.Passed | Should -Be 5
    }

    Context "Focus" {
        It "passes through a focus path under the project root" {
            & $scriptToTest $project -CommandParameters @{Focus = "$($project.root)/test_myproject.py"}
            Should -Invoke Invoke-PytestWithSummary -ParameterFilter { $TestArgs -contains "$($project.root)/test_myproject.py" }
        }

        It "drops a focus path outside the project root" {
            & $scriptToTest $project -CommandParameters @{Focus = "$root/myrepo/lib/othersub"}
            Should -Invoke Invoke-PytestWithSummary -ParameterFilter { $TestArgs.Count -eq 0 }
        }

        It "passes no TestArgs when there is no focus" {
            & $scriptToTest $project -CommandParameters @{}
            Should -Invoke Invoke-PytestWithSummary -ParameterFilter { $TestArgs.Count -eq 0 }
        }
    }
}

Describe "Invoke-DetectedProjectTest.ps1 (dotnet)" {
    BeforeAll {
        Mock Invoke-DotnetTestWithSummary {}
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')

        # Each test uses its own uniquely-named repo directory — TestDrive persists across It
        # blocks within a Describe, so a shared path would leak files (e.g. an extra csproj).
        function newProjectFixture($rootDir, $name) {
            New-Item -ItemType Directory "$rootDir/$name/lib/myproject/Foo.Tests" -Force | Out-Null
            New-Item "$rootDir/$name/lib/myproject/Foo.Tests/Foo.Tests.csproj" -ItemType File | Out-Null
            @{ root = "$rootDir/$name/lib/myproject"; id = "$name/myproject"; repo = @{ root = "$rootDir/$name" } }
        }
    }

    It "finds the *.Tests.csproj recursively and passes it as TestArgs" {
        $project = newProjectFixture $root "repoFindsCsproj"
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-DotnetTestWithSummary -ParameterFilter {
            $TestArgs.Count -eq 1 -and $TestArgs[0] -like "*Foo.Tests.csproj"
        }
    }

    It "uses the project root for RepoRoot and WorkingDir" {
        $project = newProjectFixture $root "repoRootAndWorkingDir"
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-DotnetTestWithSummary -ParameterFilter {
            $RepoRoot -eq $project.root -and $WorkingDir -eq $project.root
        }
    }

    It "wires OutputDir through from Get-ProjectTestOutputDir" {
        $project = newProjectFixture $root "repoOutputDir"
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-DotnetTestWithSummary -ParameterFilter { $OutputDir -eq (Get-ProjectTestOutputDir $project) }
    }

    It "supports -NoCoverage and -NoBuild" {
        $project = newProjectFixture $root "repoNoCoverageNoBuild"
        & $scriptToTest $project -CommandParameters @{NoCoverage = $true; NoBuild = $true}
        Should -Invoke Invoke-DotnetTestWithSummary -ParameterFilter { $NoCoverage -eq $true -and $NoBuild -eq $true }
    }

    It "forwards -PassThru and returns result" {
        $project = newProjectFixture $root "repoPassThru"
        Mock Invoke-DotnetTestWithSummary { @{ Passed = 3; Failed = 0 } }
        $result = & $scriptToTest $project -CommandParameters @{PassThru = $true}
        Should -Invoke Invoke-DotnetTestWithSummary -ParameterFilter { $PassThru -eq $true }
        $result.Passed | Should -Be 3
    }

    It "throws when multiple *.Tests.csproj are found (ambiguous)" {
        $project = newProjectFixture $root "repoAmbiguous"
        New-Item "$root/repoAmbiguous/lib/myproject/Foo.Tests/Bar.Tests.csproj" -ItemType File | Out-Null

        { & $scriptToTest $project -CommandParameters @{} } | Should -Throw "*Multiple*"
    }
}

Describe "Invoke-DetectedProjectTest.ps1 (both frameworks detected)" {
    BeforeAll {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        New-Item -ItemType Directory "$root/bothRepo/lib/myproject/Foo.Tests" -Force | Out-Null
        New-Item "$root/bothRepo/lib/myproject/pyproject.toml" -ItemType File | Out-Null
        New-Item "$root/bothRepo/lib/myproject/Foo.Tests/Foo.Tests.csproj" -ItemType File | Out-Null
        $project = @{ root = "$root/bothRepo/lib/myproject"; id = "bothRepo/myproject"; repo = @{ root = "$root/bothRepo" } }
    }

    It "runs both frameworks and sums Passed/Failed into a merged result" {
        Mock Invoke-PytestWithSummary { @{ Passed = 5; Failed = 1 } }
        Mock Invoke-DotnetTestWithSummary { @{ Passed = 3; Failed = 0 } }

        $result = & $scriptToTest $project -CommandParameters @{PassThru = $true}

        Should -Invoke Invoke-PytestWithSummary -ParameterFilter { $PassThru -eq $true }
        Should -Invoke Invoke-DotnetTestWithSummary -ParameterFilter { $PassThru -eq $true }
        $result.Passed | Should -Be 8
        $result.Failed | Should -Be 1
    }

    It "forces -PassThru on each framework even when the caller didn't ask for it" {
        Mock Invoke-PytestWithSummary { @{ Passed = 1; Failed = 0 } }
        Mock Invoke-DotnetTestWithSummary { @{ Passed = 1; Failed = 0 } }
        Mock Write-TestRunResult -ModuleName PratBase {}

        & $scriptToTest $project -CommandParameters @{}

        Should -Invoke Invoke-PytestWithSummary -ParameterFilter { $PassThru -eq $true }
        Should -Invoke Invoke-DotnetTestWithSummary -ParameterFilter { $PassThru -eq $true }
    }
}

Describe "Invoke-DetectedProjectTest.ps1 (no framework detected)" {
    It "throws — Resolve-ProjectTestScript should never point here unless a framework was detected" {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        New-Item -ItemType Directory "$root/emptyProj" -Force | Out-Null
        $project = @{ root = "$root/emptyProj"; id = "emptyProj" }

        { & $scriptToTest $project -CommandParameters @{} } | Should -Throw "*No pytest or dotnet test marker*"
    }
}
