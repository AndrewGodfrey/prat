# Analyze-FileExtensions (alias: aext)
param ([switch] $Recurse=$False)
Get-ChildItem -File -Recurse:$Recurse | Group-Object Extension
