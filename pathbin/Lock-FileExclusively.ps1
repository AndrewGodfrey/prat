# .SYNOPSIS
# (Test tool) Grabs an exclusive lock on a file
#
# .NOTES
# Source: https://superuser.com/questions/857725/how-to-lock-a-file-in-windows-without-changing-it-or-using-third-party-tools/857735#857735

param($FileName)
$ErrorActionPreference = "stop"

$FileName = Resolve-Path $FileName

#Open the file in read only mode, without sharing (I.e., locked as requested)
$file = [System.io.File]::Open($FileName, 'Open', 'Read', 'None')

try {
    #Wait in the above (file locked) state until the user presses a key
    Write-Host "Press any key to continue ..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} finally {
    #Close the file (This releases the current handle and unlocks the file)
    $file.Close()
}
