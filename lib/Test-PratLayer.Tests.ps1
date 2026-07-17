BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = "$PSScriptRoot/Test-PratLayer.ps1"
    function Invoke-PesterWithSummary(
        $NoCoverage, $PathToTest, $RepoRoot, $OutputDir, $IncludeIntegrationTests, $Integration,
        [switch] $PassThru) {}
    # No sub-targets by default — most tests here aren't exercising aggregation. Shadows the real,
    # module-exported Get-PratTestTargetsUnder (the same way Invoke-PesterWithSummary shadows its
    # own script's real implementation — see the "shadowing module functions for standalone
    # scripts" testing note; Mock -ModuleName doesn't reliably intercept a call made by a script
    # outside the module).
    function Get-PratTestTargetsUnder { @() }
}

Describe "Test-PratLayer.ps1" {
    BeforeAll {
        Mock Invoke-PesterWithSummary {}
        $project = @{ root = "C:/test/repo"; id = "repo"; repo = @{ root = "C:/test/repo" } }
    }

    It "runs coverage by default" {
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-PesterWithSummary -ParameterFilter { !$NoCoverage }
    }

    It "supports -NoCoverage" {
        & $scriptToTest $project -CommandParameters @{NoCoverage = $true}
        Should -Invoke Invoke-PesterWithSummary -ParameterFilter { $NoCoverage -eq $true }
    }

    It "uses project root when RepoRoot not specified" {
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-PesterWithSummary -ParameterFilter { $RepoRoot -eq "C:/test/repo" }
    }

    It "forwards an explicit -RepoRoot" {
        & $scriptToTest $project -CommandParameters @{RepoRoot = "customRoot"}
        Should -Invoke Invoke-PesterWithSummary -ParameterFilter { $RepoRoot -eq "customRoot" }
    }

    It "computes OutputDir via Get-ProjectTestOutputDir when not specified" {
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-PesterWithSummary -ParameterFilter { $OutputDir -eq (Get-ProjectTestOutputDir $project) }
    }

    It "forwards an explicit -OutputDir instead of computing one" {
        & $scriptToTest $project -CommandParameters @{OutputDir = "custom/output/dir"}
        Should -Invoke Invoke-PesterWithSummary -ParameterFilter { $OutputDir -eq "custom/output/dir" }
    }

    It "forwards -IncludeIntegrationTests" {
        & $scriptToTest $project -CommandParameters @{IncludeIntegrationTests = $true}
        Should -Invoke Invoke-PesterWithSummary -ParameterFilter { $IncludeIntegrationTests }
    }

    It "forwards -Integration" {
        & $scriptToTest $project -CommandParameters @{Integration = $true}
        Should -Invoke Invoke-PesterWithSummary -ParameterFilter { $Integration }
    }

    It "forwards -PassThru and returns result" {
        Mock Invoke-PesterWithSummary { @{ Passed = 5; Failed = 0 } }
        $result = & $scriptToTest $project -CommandParameters @{PassThru = $true}
        Should -Invoke Invoke-PesterWithSummary -ParameterFilter { $PassThru -eq $true }
        $result.Passed | Should -Be 5
    }
}

Describe "Test-PratLayer.ps1 sub-target aggregation" {
    BeforeAll {
        # Resolve-TestFocus requires a -Focus path to actually exist on disk, so this needs real
        # TestDrive directories (unlike Get-TestDispatch's own tests, which never touch the
        # filesystem). Merge-TestSummary also needs a real, writable RunDir for its output files.
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        New-Item -ItemType Directory "$root/repo/lib/sub" -Force | Out-Null
        New-Item -ItemType Directory "$root/repo/lib/unrelated" -Force | Out-Null
        $runDir = "$root/runDir"
        New-Item -ItemType Directory $runDir -Force | Out-Null
        $project = @{ root = "$root/repo"; id = "repo"; repo = @{ root = "$root/repo" } }

        # A fake sub-target: `.test` can be a scriptblock (same as a script path, from `&`'s POV).
        function subTargets() {
            @(@{ id = 'sub'; root = "$root/repo/lib/sub"; test = { param($project, [hashtable]$CommandParameters = @{}) @{ Passed = 3; Failed = 0; RunDir = $runDir } } })
        }
    }

    It "also runs an overlapping sub-target and merges its result with Pester's" {
        function Get-PratTestTargetsUnder { subTargets }
        Mock Invoke-PesterWithSummary { @{ Passed = 2; Failed = 0; RunDir = $runDir } }

        $result = & $scriptToTest $project -CommandParameters @{PassThru = $true}

        $result.Passed | Should -Be 5
    }

    It "skips Pester when the focus is confined inside a sub-target" {
        function Get-PratTestTargetsUnder { subTargets }
        Mock Invoke-PesterWithSummary { throw "should not be called — focus is inside the sub-target" }

        $result = & $scriptToTest $project -CommandParameters @{Focus = "$root/repo/lib/sub"; PassThru = $true}

        $result.Passed | Should -Be 3
    }

    It "still runs Pester over an unrelated focus, without invoking the sub-target" {
        function Get-PratTestTargetsUnder { subTargets }
        Mock Invoke-PesterWithSummary { @{ Passed = 2; Failed = 0; RunDir = $runDir } }

        $result = & $scriptToTest $project -CommandParameters @{Focus = "$root/repo/lib/unrelated"; PassThru = $true}

        $result.Passed | Should -Be 2
    }
}

Describe "t -Focus (integration)" -Tag Integration {
    BeforeDiscovery {
        $focusTestCases = Get-ChildItem (Resolve-Path "$PSScriptRoot/..").Path -Recurse -Filter "*.Tests.ps1" |
            ForEach-Object { @{ testFile = ($_.FullName -replace '\\', '/'); label = $_.Name } }
    }

    It "focused run passes: <label>" -ForEach $focusTestCases {
        $env:PESTER_FOCUS_PATH = $testFile
        $out = pwsh -NoProfile -c '
            Import-Module Pester
            $config = [PesterConfiguration]::Default
            $config.Run.Path          = $env:PESTER_FOCUS_PATH
            $config.Filter.ExcludeTag = @("Integration")
            $config.Run.PassThru      = [bool]$true
            $config.Output.Verbosity  = "Minimal"
            $r = Invoke-Pester -Configuration $config
            exit $(if ($r) { $r.FailedCount } else { 1 })
        ' 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }
}
