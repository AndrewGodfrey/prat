BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Test-Codebase" {
    It "runs the 'test' script for the relevant codebase" {
        $prev = pushTestEnvironment
        try {
            $env:testenvvar = 'foo'
            
            # Act
            $result = Test-Codebase

            # Assert
            $result | Should -Be "testCb: test: foo"
        } finally {
            popTestEnvironment $prev
        }
    }
}