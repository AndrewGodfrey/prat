# Test a codebase
# (i.e. Run unit tests)
#
# Recommended alias: t
#
# What this does, depends on the codebase. It might do nothing.
# The purpose of this is to provide a consistent dev inner loop. I alias 't' to run this directly, or 'x' to run it as part of a larger loop.

[CmdletBinding()]
param()

$cbt = &$home\prat\lib\Get-CodebaseTable (Get-Location)
if ($null -eq $cbt) { 
    throw "Unknown codebase - can't run tests"
}

if ($null -ne $cbt.howToTest) {
    &$cbt.howToTest
} else {
    # Note we depend on PATH to find Get-CodebaseScript. This allows for it to be overridden.
    $script = Get-CodebaseScript "test" $cbt.id

    if ($null -eq $script) {
        Write-Verbose "test: NOP"
    } else {
        Write-Debug "calling $script for ${$cbt.id}"
        . $script $cbt
    }
}

