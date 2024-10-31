BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Build-Codebase" {
    It "runs the 'build' script for the relevant codebase" {
        $prev = pushTestEnvironment
        try {
            $env:testenvvar = 'foo'
            
            # Act
            $result = Build-Codebase

            # Assert
            $result | Should -Be "testCb: build: foo"
        } finally {
            popTestEnvironment $prev
        }
    }
}