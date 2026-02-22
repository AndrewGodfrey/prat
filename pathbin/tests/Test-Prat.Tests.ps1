Describe "Test-Prat" {
    BeforeAll {
        $expectedCoverageType = "None"
        function Invoke-PesterWithCodeCoverage($CoverageType, $PathToTest) {}
        Mock Invoke-PesterWithCodeCoverage { $CoverageType | Should -Be $expectedCoverageType }

        $simualtedTestFocus = $null
        function Get-TestFocus { return $simualtedTestFocus }
    }
    It "Chooses no coverage by default" {
        Test-Prat
    }
    It "Can be overridden using the first parameter" {
        foreach ($type in @("None", "Standard", "Subset")) {
            $expectedCoverageType = $type

            Test-Prat $type
        }
    }
    It "Gives preference to the -CodeCoverage switch" {
        foreach ($type in @("None", "Standard", "Subset")) {
            $expectedCoverageType = "Standard"

            Test-Prat $type -CodeCoverage
        }
    }
    It "Supports test focus" {
        $simualtedTestFocus = "somePath"

        Test-Prat
    }
    It "Changes the -CodeCoverage switch behavior when test focus is set" {
        $expectedCoverageType = "Subset"
        $simualtedTestFocus = "somePath"

        Test-Prat -CodeCoverage
    }
    It "Uses explicit -TestFocus as path" {
        $simualtedTestFocus = $null

        Test-Prat -TestFocus "explicitFocus"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "explicitFocus" }
    }
    It "Explicit -TestFocus overrides Get-TestFocus state" {
        $simualtedTestFocus = "focusFromState"

        Test-Prat -TestFocus "explicitFocus"

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "explicitFocus" }
    }
    It "Explicit -TestFocus with -CodeCoverage uses Subset" {
        $expectedCoverageType = "Subset"
        $simualtedTestFocus = $null

        Test-Prat -TestFocus "explicitFocus" -CodeCoverage
    }
    It "-NoFocus ignores Get-TestFocus state" {
        $simualtedTestFocus = "focusFromState"

        Test-Prat -NoFocus

        Should -Invoke Invoke-PesterWithCodeCoverage -ParameterFilter { $PathToTest -eq "." }
    }
}
