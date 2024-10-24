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

&$PSScriptRoot\..\lib\Invoke-CodebaseCommand.ps1 "prebuild" @("-Force", $Force)
