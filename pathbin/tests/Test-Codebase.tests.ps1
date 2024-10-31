BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Test-Codebase" {
    It "runs the 'test' script for the 'testCb' codebase" {
        $prev = pushTestEnvironment
        try {
            $env:testenvvar = 'foo'
            
            # Act
            $result = Test-Codebase

            # Assert
            $result | Should -Be "testCb: test: bar"
        } finally {
            popTestEnvironment $prev
        }
    }
}