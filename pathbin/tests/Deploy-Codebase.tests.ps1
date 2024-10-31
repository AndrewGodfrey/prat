BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Deploy-Codebase" {
    It "runs the 'deploy' script for the 'testCb' codebase" {
        $prev = pushTestEnvironment
        try {
            $env:testenvvar = 'foo'
            
            # Act
            $result = Deploy-Codebase

            # Assert
            $result | Should -Be "testCb: deploy: bar"
        } finally {
            popTestEnvironment $prev
        }
    }
}