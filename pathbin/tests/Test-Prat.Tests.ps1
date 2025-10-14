Describe "Test-Prat" {
    BeforeAll {
        $expectedCoverageType = "None"
        function Invoke-PesterWithCodeCoverage($CoverageType) {}
        Mock Invoke-PesterWithCodeCoverage { $CoverageType | Should -Be $expectedCoverageType }
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
}
