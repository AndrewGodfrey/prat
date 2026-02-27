Describe "Test-Prat" {
    BeforeAll {
        $expectedNoCoverage = $null
        function Invoke-PesterWithCodeCoverage($NoCoverage, $PathToTest, $RepoRoot, $Debugging, $OutputDir, $IncludeIntegrationTests) {}
        Mock Invoke-PesterWithCodeCoverage { $NoCoverage | Should -Be $expectedNoCoverage }

        $simulatedTestFocus = $null
        function Get-TestFocus { return $simulatedTestFocus }
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
    It "Supports test focus" {
        $expectedNoCoverage = $false
        $simulatedTestFocus = "somePath"

        Test-Prat
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "somePath" }
    }
    It "Uses explicit -Focus as path" {
        $simulatedTestFocus = $null

        Test-Prat -Focus "explicitFocus"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "explicitFocus" }
    }
    It "Explicit -Focus overrides Get-TestFocus state" {
        $simulatedTestFocus = "focusFromState"

        Test-Prat -Focus "explicitFocus"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "explicitFocus" }
    }
    It "skips coverage with -NoCoverage even when using -Focus" {
        $expectedNoCoverage = $true
        $simulatedTestFocus = $null

        Test-Prat -Focus "explicitFocus" -NoCoverage
    }
    It "-Focus and -NoFocus cannot be used together" {
        { Test-Prat -Focus "somePath" -NoFocus } | Should -Throw
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

    It "-NoFocus ignores Get-TestFocus state" {
        $simulatedTestFocus = "focusFromState"

        Test-Prat -NoFocus

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "." }
    }
}
