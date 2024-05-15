# Basic functions that Prat needs everywhere, and that we'll always load in script and user profile.


# Tests whether the current user has elevated to administrator.
#
# Note: NOT to be confused with "are they a member of the Administrators group?".
function Get-CurrentUserIsElevated {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator"
    )
}


function Get-RelativePath($expectedRoot, $path) {
    if (-not (Split-Path $path -IsAbsolute)) { throw "Expected absolute path. Actual: $path" }
    if (-not (Test-Path -LiteralPath $path)) { throw "Expected literal path to existing item. Actual: $path" }

    $canonicalRoot = (Resolve-Path $expectedRoot).Path
    $canonicalPath = (Resolve-Path $path).Path
    if (-not ($canonicalPath.StartsWith($canonicalRoot))) { throw "Expected subpath. '$root' does not seem to be a root of '$path'" }
    if ($canonicalPath -eq $canonicalRoot) { return "" }

    # "+1" to strip off leading path separator.
    return $canonicalPath.SubString($canonicalRoot.Length + 1)
}

# This is analogous to Import-Alias -Force, just with a different file format (and fewer properties supported).
function Import-PratAliases($file) {
    . $file
    foreach ($name in $installedAliases.Keys) {
        $value = $installedAliases[$name]
        New-Alias -Force -Name $name -Value $value -Scope Global
    }
}


###############################################################################
# Description:  Convert Bytes into the appropriate unit of measure
# Author:       Unknown. But seems derived from Ed Wilson's blog: https://devblogs.microsoft.com/scripting/hey-scripting-guy-can-you-give-all-the-steps-for-creating-installing-and-using-windows-powershell-modules/
# Last Update:  5/08/2010 2:03:57 PM
# Arguments:    [int64] The byte value to be converted
# Returns:      [string] Display friendly value
###############################################################################
function Get-OptimalSize($sizeInBytes) {
    if ($sizeInBytes -eq $null) { return $null }
    $sizeInBytes = [int64] $sizeInBytes

    switch ($sizeInBytes) {
        # Hmm. Disk size standards have changed. Nowadays, 1024 bytes is "one kibibyte, abbreviated KiB", and that unit is rarely used.
        # And KB means 1000 bytes. So, instead of using Powershell's definitions for 1TB, 1GB, 1MB or 1KB:
        {$sizeInBytes -ge 1000000000000000} {"{0:n1}" -f ($sizeInBytes/1000000000000) + "PB" ; break}
        {$sizeInBytes -ge 1000000000000} {"{0:n1}" -f ($sizeInBytes/1000000000) + "TB" ; break}
        {$sizeInBytes -ge 1000000000} {"{0:n1}" -f ($sizeInBytes/1000000000) + "GB" ; break}
        {$sizeInBytes -ge 1000000} {"{0:n1}" -f ($sizeInBytes/1000000) + "MB" ; break}
        {$sizeInBytes -ge 1000} {"{0:n1}" -f ($sizeInBytes/1000) + "K" ; break}
        default { $sizeInBytes }
    }
}

. $PSScriptRoot\ConvertTo-Expression.ps1


