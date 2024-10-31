BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Prebuild-Codebase" {
    It "runs the 'prebuild' script for the relevant codebase" {
        $prev = pushTestEnvironment
        try {
            $env:testenvvar = 'foo'
            
            # Act
            $result = Prebuild-Codebase

            # Assert
            $result | Should -Be "testCb: prebuild: foo"
        } finally {
            popTestEnvironment $prev
        }
    }
}