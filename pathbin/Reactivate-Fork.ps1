[string] $tokenFile = & (Resolve-PratLibFile "lib/inst/Get-PratTokens.ps1") "forkActivation"
if (($tokenFile -eq "") -or (!(Test-Path $tokenFile))) { throw "Not found: $tokenFile" }

$destDir = $env:localappdata + "\Fork"
[hashtable] $tokens = . $tokenFile
&$destDir\Fork.exe activate $tokens.email $tokens.key
