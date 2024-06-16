# Converts a file encoding from "utf8 + BOM" to "utf8"
param ($file)

# Convert to absolute, because ReadAllBytes (used below) doesn't respect our $pwd.
$file = (Resolve-Path $file).Path

$fmt = &$PSScriptRoot/Get-TextFileEncoding -FromScript $file

if ($fmt -eq "utf8") { 
    # NOP
    return
}

if ($fmt -ne "utf8 + BOM") {
    Write-Warning "Unexpected format: $fmt. Skipping file: $file"
    return
}

[byte[]] $bytes = [System.IO.File]::ReadAllBytes($file)
[System.IO.File]::WriteAllBytes($file, $bytes[3..($bytes.Length-1)])

$fmt = &$PSScriptRoot/Get-TextFileEncoding -FromScript $file
if ($fmt -ne "utf8") {
    throw "Internal error: fmt is now: $fmt"
}

