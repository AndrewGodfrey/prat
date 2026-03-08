using module ../../lib/PratBase/PratBase.psd1

BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1
}

Describe "Test-Project" {
    It "includes coverage suffix by default" {
        $prev = pushTestEnvironment
        try {
            $result = Test-Project
            $result | Should -Be "testCb: test: bar"
        } finally {
            popTestEnvironment $prev
        }
    }

    It "skips coverage suffix with -NoCoverage" {
        $prev = pushTestEnvironment
        try {
            $result = Test-Project -NoCoverage
            $result | Should -Be "testCb: test: bar: NoCoverage=True"
        } finally {
            popTestEnvironment $prev
        }
    }

    It "passes -Focus to the codebase script" {
        $prev = pushTestEnvironment
        try {
            $result = Test-Project -Focus "lib/foo"
            $result | Should -Be "testCb: test: bar: Focus=lib/foo"
        } finally {
            popTestEnvironment $prev
        }
    }

    It "defaults -Focus to -RepoRoot when -Focus is not specified" {
        $prev = pushTestEnvironment
        try {
            $testCbPath = (Get-Location).Path
            $result = Test-Project -RepoRoot $testCbPath
            $result | Should -Be "testCb: test: bar: Focus=$testCbPath RepoRoot=$testCbPath"
        } finally {
            popTestEnvironment $prev
        }
    }
}
