# Get-FileVersionInfo (alias: filever)
param ($Target = $(throw "Target parameter is required"))

(Get-Command $Target).FileVersionInfo | format-list
