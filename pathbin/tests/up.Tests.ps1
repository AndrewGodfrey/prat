BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1" -Force
}

Describe "up" {
    It "traverses upwards to find a match" {
        pushd $PSScriptRoot\testCb

        up "up.ps1" | Should -Be (Get-Command up).Source
        popd
    }
    It "supports wildcards" {
        pushd $PSScriptRoot\testCb

        up "up.*.ps1" | Should -Be (Resolve-JunctionInPath $PSCommandPath)
        popd
    }
    It "returns null when no match" {
        pushd "TestDrive:"

        up "notexists.*.nosuchthing" | Should -Be $null
        popd
    }
    It "resolves junctions in the starting directory" {
        $r = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        New-Item -ItemType Directory "$r\up-real\subdir" -Force | Out-Null
        New-Item -ItemType Junction  "$r\up-jlink" -Target "$r\up-real" | Out-Null
        "x" | Out-File "$r\up-real\sentinel.txt"

        pushd "$r\up-jlink\subdir"
        $result = up "sentinel.txt"
        popd

        $result | Should -Be "$r\up-real\sentinel.txt"
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
