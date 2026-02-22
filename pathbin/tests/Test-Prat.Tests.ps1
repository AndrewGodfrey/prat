Describe "Test-Prat" {
    BeforeAll {
        $expectedCoverageSetting = $null
        function Invoke-PesterWithCodeCoverage($Coverage, $PathToTest) {}
        Mock Invoke-PesterWithCodeCoverage { $Coverage | Should -Be $expectedCoverageSetting }

        $simulatedTestFocus = $null
        function Get-TestFocus { return $simulatedTestFocus }
    }
    BeforeEach {
        $expectedCoverageSetting = $false
    }
    It "Chooses no coverage by default" {
        $expectedCoverageSetting = $false

        Test-Prat
    }
    It "supports -Coverage" {
        foreach ($setting in @($false, $true)) {
            $expectedCoverageSetting = $setting

            Test-Prat -Coverage:$setting
        }
    }
    It "Supports test focus" {
        $expectedCoverageSetting = $false
        $simulatedTestFocus = "somePath"

        Test-Prat
        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "somePath" }
    }
    It "Uses explicit -TestFocus as path" {
        $simulatedTestFocus = $null

        Test-Prat -TestFocus "explicitFocus"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "explicitFocus" }
    }
    It "Explicit -TestFocus overrides Get-TestFocus state" {
        $simulatedTestFocus = "focusFromState"

        Test-Prat -TestFocus "explicitFocus"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "explicitFocus" }
    }
    It "Explicit -TestFocus with -Coverage uses Subset" {
        $expectedCoverageSetting = $true
        $simulatedTestFocus = $null

        Test-Prat -TestFocus "explicitFocus" -Coverage
    }
    It "-NoFocus ignores Get-TestFocus state" {
        $simulatedTestFocus = "focusFromState"

        Test-Prat -NoFocus

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "." }
    }
}
