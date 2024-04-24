Function Get-OptimalSize()
###############################################################################
# Description:  Convert Bytes into the appropriate unit of measure
# Author:       Unknown
# Last Update:  5/08/2010 2:03:57 PM
# Arguments:    [int64] The byte value to be converted
# Returns:      [string] Display friendly value
###############################################################################
{
    Param($sizeInBytes)
    if ($sizeInBytes -eq $null) {
        return $null
    }
    $sizeInBytes = [int64] $sizeInBytes

    switch ($sizeInBytes)
    {
        # Hmm. Disk size standards have changed. Nowadays, 1024 bytes is "one kibibyte, abbreviated KiB", and that unit is rarely used.
        # And KB means 1000 bytes. So, instead of using Powershell's definitions for 1TB, 1GB, 1MB or 1KB, I'll ignore those.
        {$sizeInBytes -ge 1000000000000000} {"{0:n1}" -f ($sizeInBytes/1000000000000) + "PB" ; break}
        {$sizeInBytes -ge 1000000000000} {"{0:n1}" -f ($sizeInBytes/1000000000) + "TB" ; break}
        {$sizeInBytes -ge 1000000000} {"{0:n1}" -f ($sizeInBytes/1000000000) + "GB" ; break}
        {$sizeInBytes -ge 1000000} {"{0:n1}" -f ($sizeInBytes/1000000) + "MB" ; break}
        {$sizeInBytes -ge 1000} {"{0:n1}" -f ($sizeInBytes/1000) + "K" ; break}
        Default { $sizeInBytes }
    } # EndSwitch
} # End Function Get-OptimalSize

