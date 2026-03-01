BeforeAll {
    $scriptToTest = "$PSScriptRoot/../Get-CodebaseScript.ps1"
    function Invoke-PesterWithCodeCoverage($NoCoverage, $PathToTest, $RepoRoot, $Debugging, $OutputDir, $IncludeIntegrationTests) {}
}

Describe "Get-CodebaseScript - prat test scriptblock" {
    BeforeAll {
        Mock Invoke-PesterWithCodeCoverage {}
        $script = &$scriptToTest "test" "prat"
    }

    It "runs coverage by default" {
        & $script -CommandParameters @{}

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { !$NoCoverage }
    }

    It "supports -NoCoverage" {
        & $script -CommandParameters @{NoCoverage = $true}

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $NoCoverage -eq $true }
    }

    It "forwards -IncludeIntegrationTests to Invoke-PesterWithCodeCoverage" {
        & $script -CommandParameters @{IncludeIntegrationTests = $true}

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $IncludeIntegrationTests }
    }

    It "forwards an explicit -RepoRoot to Invoke-PesterWithCodeCoverage" {
        & $script -CommandParameters @{RepoRoot = "customRoot"}

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $RepoRoot -eq "customRoot" }
    }
}
