BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Prebuild-Codebase" {
    It "runs the 'prebuild' script for the 'testCb' codebase" {
        $prev = pushTestEnvironment
        try {
            $env:testenvvar = 'foo'
            
            # Act
            $result = Prebuild-Codebase

            # Assert
            $result | Should -Be "testCb: prebuild: foo"  # Note: We expect 'foo' not 'bar' - prebuild should not apply cachedEnvDelta.
        } finally {
            popTestEnvironment $prev
        }
    }
}