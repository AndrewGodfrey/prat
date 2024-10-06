# Deploy a codebase
#
# Recommended alias: d
#
# What this does, depends on the codebase. It might do nothing, or deploy to the current machine, or even deploy to remote machines.
# The purpose of this is to provide a consistent dev inner loop. I alias 'd' to run this directly, or 'x' to run it as part of a larger loop.
#
# -Force: Ignores Prat's installation DB - i.e. acts as if that was empty. But this is not propagated to other package managers e.g. winget.
[CmdletBinding()]
param([switch] $Force)

$cbt = &$home\prat\lib\Get-CodebaseTable (Get-Location)
if ($cbt -eq $null) { 
    throw "Unknown codebase - can't deploy"
}

# Note we depend on PATH to find Get-CodebaseScript. This allows for it to be overridden.
$script = Get-CodebaseScript "deploy" $cbt.id

if ($script -eq $null) {
    if ($cbt.howToDeploy -ne $null) {
        &$cbt.howToDeploy -Force:$Force
    } else {
        Write-Verbose "deploy: NOP"
    }
} else {
    Write-Debug "calling $script for ${$cbt.id}"
    . $script $cbt -Force:$Force
}
