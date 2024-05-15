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

. $PSScriptRoot\ConvertTo-Expression.ps1

