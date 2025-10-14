# Set-TestFocus (alias: stf)
# Sets or clears the current test focus.
#
# If set to non-null, it is shown in the prompt, and Test-Prat focuses on the given code, or single test file.
param ($directoryOrFile = $null)
$stateFile = "$home\prat\auto\profile\Get-CurrentTestFocus.ps1"
$currentState = $null
if (Test-Path $stateFile) {
    $currentState = &$stateFile
}
if ($null -ne $directoryOrFile) {
    $newState = @{
        DirectoryOrFile = (Resolve-Path $directoryOrFile).Path
        Timestamp = (Get-Date).ToString("u")
    }
    if ($null -ne $currentState -and $currentState.DirectoryOrFile -eq $newState.DirectoryOrFile) {
        return
    }
    ConvertTo-Expression $newState | Out-File -FilePath $stateFile -Force
} else {
    if ($null -ne $currentState) {
        Remove-Item $stateFile | Out-Null
    }
}