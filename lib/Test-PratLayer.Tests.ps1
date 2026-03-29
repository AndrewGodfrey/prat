BeforeAll {
    $scriptToTest = "$PSScriptRoot/Test-PratLayer.ps1"
    function Invoke-PesterWithCodeCoverage(
        $NoCoverage, $PathToTest, $RepoRoot, $OutputDir, $IncludeIntegrationTests, $Integration) {}
}

Describe "Test-PratLayer.ps1" {
    BeforeAll {
        Mock Invoke-PesterWithCodeCoverage {}
        $project = @{ root = "C:/test/repo" }
    }

    It "runs coverage by default" {
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { !$NoCoverage }
    }

    It "supports -NoCoverage" {
        & $scriptToTest $project -CommandParameters @{NoCoverage = $true}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $NoCoverage -eq $true }
    }

    It "uses project root when RepoRoot not specified" {
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $RepoRoot -eq "C:/test/repo" }
    }

    It "forwards an explicit -RepoRoot" {
        & $scriptToTest $project -CommandParameters @{RepoRoot = "customRoot"}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $RepoRoot -eq "customRoot" }
    }

    It "forwards -IncludeIntegrationTests" {
        & $scriptToTest $project -CommandParameters @{IncludeIntegrationTests = $true}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $IncludeIntegrationTests }
    }

    It "forwards -Integration" {
        & $scriptToTest $project -CommandParameters @{Integration = $true}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $Integration }
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
