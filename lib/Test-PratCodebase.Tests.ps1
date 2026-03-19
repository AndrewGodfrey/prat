BeforeAll {
    $scriptToTest = "$PSScriptRoot/Test-PratCodebase.ps1"
    function Invoke-PesterWithCodeCoverage(
        $NoCoverage, $PathToTest, $RepoRoot, $Debugging, $OutputDir, $IncludeIntegrationTests, $Integration) {}
}

Describe "Test-PratCodebase.ps1" {
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
