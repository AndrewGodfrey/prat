# .SYNOPSIS
# Get-DiskFreeSpace ('df') - shows free space and capacity for all logical disks.
# Compare with: Get-Volume, Get-PhysicalDisk.

function getUsedPercentage([int64] $free, [int64] $size) {
    [int64] $used = $size - $free
    return "{0:F1}%" -f (100.0*$used / $size)
}

function Get-DiskFreeSpace([switch] $HideTableHeaders) {
    Get-CimInstance win32_logicaldisk  | format-table -HideTableHeaders:$HideTableHeaders -Property DeviceID, 
        @{Name="FreeSpace";Expression={Get-OptimalSize $_.FreeSpace}},
        @{Name="Size";Expression={Get-OptimalSize $_.Size}},
        @{Name="Used";Expression={getUsedPercentage $_.FreeSpace $_.Size}},
        VolumeName, ProviderName
}

