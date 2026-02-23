using module ../../lib/PratBase/PratBase.psd1

BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Test-Codebase" {
    It "includes coverage suffix by default" {
        $prev = pushTestEnvironment
        try {
            $result = Test-Codebase
            $result | Should -Be "testCb: test: bar cc"
        } finally {
            popTestEnvironment $prev
        }
    }

    It "skips coverage suffix with -NoCoverage" {
        $prev = pushTestEnvironment
        try {
            $result = Test-Codebase -NoCoverage
            $result | Should -Be "testCb: test: bar"
        } finally {
            popTestEnvironment $prev
        }
    }
}
