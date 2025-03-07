# .SYNOPSIS
# Gets FileVersionInfo for a command
#
# Alias: filever
param ($Target = $(throw "Target parameter is required"))

(Get-Command $Target).FileVersionInfo | format-list
