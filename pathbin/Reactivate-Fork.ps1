[string] $tokenFile = & (Resolve-PratLibFile "lib/inst/Get-PratTokens.ps1") "forkActivation"
if (($tokenFile -eq "") -or (!(Test-Path $tokenFile))) { throw "Not found: $tokenFile" }

$destDir = $env:localappdata + "\Fork"
[hashtable] $tokens = . $tokenFile
&$destDir\current\Fork.exe activate $tokens.email $tokens.key

# OmitFromCoverageReport: a unit test would just restate it