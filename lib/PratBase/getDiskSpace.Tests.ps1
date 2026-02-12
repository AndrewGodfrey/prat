BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}
Describe "getUsedPercentage" {
    It "returns a percentage" {
        getUsedPercentage 21 42 | Should -Be "50.0%"
    }
}

Describe "Get-DiskFreeSpace" {
    BeforeAll {
        Mock Get-CimInstance {
            if ($ClassName -ne 'win32_logicaldisk') { throw "Unexpected class name: $ClassName" }
            return @(
                [PSCustomObject]@{
                    'DeviceID'     = 'C:'
                    'FreeSpace'    = 312136237056
                    'ProviderName' = $Null
                    'Size'         = 497952157696
                    'VolumeName'   = 'OS'
                },
                [PSCustomObject]@{
                    'DeviceID'     = 'Y:'
                    'FreeSpace'    = 579564081152
                    'ProviderName' = '\\server\share1'
                    'Size'         = 1030776045568
                    'VolumeName'   = 'Share1'
                }
            )
        }
    }
    It "returns disk space information" {
        $text = Get-DiskFreeSpace | Out-String

        $text | Should -Match 'C:'
        $text | Should -Match 'Y:'
        $text | Should -Match 'OS'
        $text | Should -Match 'Share1'
        $text | Should -Match '\\\\server\\share1'
        $text | Should -Match '37\.3%'   # used percentage for C:
    }
}
