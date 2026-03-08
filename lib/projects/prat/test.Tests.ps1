BeforeAll {
    $scriptToTest = "$PSScriptRoot/test.ps1"
    function Invoke-PesterWithCodeCoverage(
        $NoCoverage, $PathToTest, $RepoRoot, $Debugging, $OutputDir, $IncludeIntegrationTests, $Integration) {}
}

Describe "prat test.ps1" {
    BeforeAll {
        Mock Invoke-PesterWithCodeCoverage {}
        $project = @{ root = "$HOME/prat" }
    }

    It "runs coverage by default" {
        & $scriptToTest $project -CommandParameters @{}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { !$NoCoverage }
    }

    It "supports -NoCoverage" {
        & $scriptToTest $project -CommandParameters @{NoCoverage = $true}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $NoCoverage -eq $true }
    }

    It "forwards -IncludeIntegrationTests" {
        & $scriptToTest $project -CommandParameters @{IncludeIntegrationTests = $true}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $IncludeIntegrationTests }
    }

    It "forwards -Integration" {
        & $scriptToTest $project -CommandParameters @{Integration = $true}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $Integration }
    }

    It "forwards an explicit -RepoRoot" {
        & $scriptToTest $project -CommandParameters @{RepoRoot = "customRoot"}
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $RepoRoot -eq "customRoot" }
    }
}
