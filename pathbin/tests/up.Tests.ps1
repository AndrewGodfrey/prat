Describe "up" {
    It "traverses upwards to find a match" {
        pushd $PSScriptRoot\testCb

        up "up.ps1" | Should -Be (Get-Command up).Source
        popd
    }
    It "supports wildcards" {
        pushd $PSScriptRoot\testCb

        up "up.*.ps1" | Should -Be $PSCommandPath
        popd
    }
    It "returns null when no match" {
        pushd "TestDrive:"

        up "notexists.*.nosuchthing" | Should -Be $null
        popd
    }
    It "can return multiple results" {
        pushd $PSScriptRoot

        $result = up "*.Tests.ps1" 3>$warnings

        $result.Count -gt 1 | Should -BeTrue
        $result[0] | Should -BeOfType String
        Test-Path $result[1] | Should -BeTrue
        popd
    }
}
