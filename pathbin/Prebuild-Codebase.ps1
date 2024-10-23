# Prebuild a codebase
#
# Recommended alias: pb
# 
# The idea of "prebuild" is to install expensive things that are needed (if any) for the "build" step to work.
# Some other common names for this step are "depends", "bootstrap", "prepare".
#
# This is an installation step similar to "deploy", but build depends on this step (whereas "deploy" depends on "build").
#
# -Force: Ignores Prat's installation DB - i.e. acts as if that was empty. But this is not propagated to other package managers e.g. winget.
#         I can only imagine the installation DB being a good idea for some kinds of prebuild action - haven't used it myself yet.
[CmdletBinding()]
param([switch] $Force)

$cbt = &$home\prat\lib\Get-CodebaseTable (Get-Location)
if ($null -eq $cbt) { 
    throw "Unknown codebase - can't prebuild"
}

# Note we depend on PATH to find Get-CodebaseScript. This allows for it to be overridden.
$script = Get-CodebaseScript "prebuild" $cbt.id

if ($null -eq $script) {
    Write-Verbose "prebuild: NOP"
    return
}

Write-Verbose "calling prebuild script for $($cbt.id); force: $Force"
&$script $cbt -Force:$Force
