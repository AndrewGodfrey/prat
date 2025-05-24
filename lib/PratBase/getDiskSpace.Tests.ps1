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
        Mock -ModuleName PratBase Get-CimInstance { 
            if ($ClassName -ne 'win32_logicaldisk') { throw "Unexpected class name: $ClassName" }  
            return 
            @(
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
        $result = Get-DiskFreeSpace
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 7
        ($result | ForEach-Object { $_.GetType().Name }) -join ", " | Should -Be "FormatStartData, GroupStartData, FormatEntryData, FormatEntryData, FormatEntryData, GroupEndData, FormatEndData"
        
        # I'm not sure how to test Format-Table output. It bypasses stdout, and FormatEntryData doesn't like to be questioned.
    }
}
