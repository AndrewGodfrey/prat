# .SYNOPSIS
#
# Groups files by file extension
#
# Alias: aext
param ([switch] $Recurse=$False)
Get-ChildItem -File -Recurse:$Recurse | Group-Object Extension
