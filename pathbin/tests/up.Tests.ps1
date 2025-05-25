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
}
