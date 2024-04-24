# Deploy a codebase
#
# Recommended alias: d
#
# What this does, depends on the codebase. It might do nothing, or deploy to the current machine, or even deploy to remote machines.
# The purpose of this is to provide a consistent dev inner loop. I alias 'd' to run this directly, or 'x' to run it as part of a larger loop.
[CmdletBinding()]
param()

$cbt = &$home\prat\lib\Get-CodebaseTable (Get-Location)
if ($cbt -eq $null) { 
    throw "Unknown codebase - can't deploy"
}
if ($cbt.howToDeploy -ne $null) {
    &$cbt.howToDeploy
} else {
    # Note we depend on PATH to find Get-CodebaseScript. This allows for it to be overridden.
    $script = Get-CodebaseScript "deploy" $cbt.id

    if ($script -eq $null) {
        Write-Verbose "deploy: NOP"
    } else {
        Write-Debug "calling $script for ${$cbt.id}"
        . $script $cbt
    }
}
