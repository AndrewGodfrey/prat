BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Deploy-Codebase" {
    It "runs the 'deploy' script for the relevant codebase" {
        $prev = pushTestEnvironment
        try {
            $env:testenvvar = 'foo'
            
            # Act
            $result = Deploy-Codebase

            # Assert
            $result | Should -Be "testCb: deploy: foo"
        } finally {
            popTestEnvironment $prev
        }
    }
}