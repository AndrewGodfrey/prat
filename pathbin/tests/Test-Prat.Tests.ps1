Describe "Test-Prat" {
    BeforeAll {
        $expectedCoverageSetting = $null
        function Invoke-PesterWithCodeCoverage($Coverage, $PathToTest, $RepoRoot) {}
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
    It "Explicit -Focus with -Coverage enables coverage" {
        $expectedCoverageSetting = $true
        $simulatedTestFocus = $null

        Test-Prat -Focus "explicitFocus" -Coverage
    }
    It "-Focus and -NoFocus cannot be used together" {
        { Test-Prat -Focus "somePath" -NoFocus } | Should -Throw
    }
    It "forwards an explicit -RepoRoot to Invoke-PesterWithCodeCoverage" {
        Test-Prat -RepoRoot "customRoot"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $RepoRoot -eq "customRoot" }
    }
    It "-NoFocus ignores Get-TestFocus state" {
        $simulatedTestFocus = "focusFromState"

        Test-Prat -NoFocus

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "." }
    }
}
