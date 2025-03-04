# .SYNOPSIS
# Resolves a file path to a file in one of the registered dev environments (as in Get-DevEnvironments).
# e.g. given "lib\profile\interactiveProfile.ps1" it will match to "lib\profile\interactiveProfile_prat.ps1" unless
#      another dev environment overrides it. Note the "_prat" suffix. Appending the dev environment name serves 2 purposes:
#      1. The files are easier to distinguish in an IDE.
#      2. It makes clear which files are expected to be overridden.
param ($file)

$ext = Split-Path $file -Extension
$fileWithoutExt = $file.SubString(0, $file.Length - $ext.Length)

foreach ($de in (Get-DevEnvironments)) {
    $candidate = "$($de.Path)\$($fileWithoutExt)_$($de.Name)$ext"
    if (Test-Path $candidate) {
        return $candidate
    }
}
return $null
