$stateFile = "$home\prat\auto\profile\Get-CurrentTestFocus.ps1"
$currentState = $null
if (!(Test-Path $stateFile)) {
    return $null
}
$currentState = &$stateFile
return $currentState.DirectoryOrFile
