using module ../../lib/PratBase/PratBase.psd1

BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Test-Codebase" {
    It "passes -CodeCoverage to the test script" {
        $prev = pushTestEnvironment
        try {
            $result = Test-Codebase -Coverage
            $result | Should -Be "testCb: test: bar cc"
        } finally {
            popTestEnvironment $prev
        }
    }

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