using module .\PratBase.psd1

Describe "Get-RelativePath" {
    It "returns a relative path" {
        $p = Get-RelativePath $PSScriptRoot "$PSScriptRoot\PratBase.psd1"
        $p | Should -Be "PratBase.psd1"
    }
    It "returns a relative path to a subdirectory" {
        $p = Get-RelativePath $PSScriptRoot "$PSScriptRoot\test\"
        $p | Should -Be "test\"
    }
    It "returns a relative path to file in a subdirectory" {
        $p = Get-RelativePath $PSScriptRoot "$PSScriptRoot\test\dummytestfile.txt"
        $p | Should -Be "test\dummytestfile.txt"
    }
    It "uses upper/lowercase from the filesystem, not the parameter" {
        $p = Get-RelativePath "$PSScriptRoot\TeSt" "$PSScriptRoot\test\dummyTestfile.txt"
        $p | Should -Be "dummytestfile.txt"
    }
    It "returns an empty string (not '.') if given the root" {
        $p = Get-RelativePath $PSScriptRoot $PSScriptRoot
        $p | Should -Be ""
    }
}
