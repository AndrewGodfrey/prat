Describe "Test-Prat" {
    BeforeAll {
        $expectedNoCoverage = $null
        function Invoke-PesterWithCodeCoverage($NoCoverage, $PathToTest, $RepoRoot, $Debugging, $OutputDir, $IncludeIntegrationTests) {}
        Mock Invoke-PesterWithCodeCoverage { $NoCoverage | Should -Be $expectedNoCoverage }
    }
    BeforeEach {
        $expectedNoCoverage = $false
    }
    It "runs coverage by default" {
        $expectedNoCoverage = $false

        Test-Prat
    }
    It "supports -NoCoverage" {
        foreach ($setting in @($false, $true)) {
            $expectedNoCoverage = $setting

            Test-Prat -NoCoverage:$setting
        }
    }
    It "Supports -Focus" {
        $expectedNoCoverage = $false

        Test-Prat -Focus "somePath"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "somePath" }
    }
    It "Supports -Focus with -NoCoverage" {
        $expectedNoCoverage = $true

        Test-Prat -Focus "somePath" -NoCoverage
    }
    It "forwards an explicit -RepoRoot to Invoke-PesterWithCodeCoverage" {
        Test-Prat -RepoRoot "customRoot"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $RepoRoot -eq "customRoot" }
    }
    It "does not pass -Debugging by default" {
        Test-Prat

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { !$Debugging }
    }

    It "forwards -Debugging to Invoke-PesterWithCodeCoverage" {
        Test-Prat -Debugging

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $Debugging }
    }

    It "forwards -Output to Invoke-PesterWithCodeCoverage" {
        Test-Prat -OutputDir "customOutputDir"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $OutputDir -eq "customOutputDir" }
    }

    It "forwards -IncludeIntegrationTests to Invoke-PesterWithCodeCoverage" {
        Test-Prat -IncludeIntegrationTests

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $IncludeIntegrationTests }
    }
}
