Describe "Test-Prat" {
    BeforeAll {
        $expectedCoverageType = "None"
        function Invoke-PesterWithCodeCoverage($CoverageType) {}
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
}
