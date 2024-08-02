# Converts a file encoding from "utf8" to "utf8 + BOM"
param ($file)

# Convert to absolute, because ReadAllBytes (used below) doesn't respect our $pwd.
$file = (Resolve-Path $file).Path

$fmt = &$PSScriptRoot/Get-TextFileEncoding -FromScript $file

if ($fmt -eq "utf8 + BOM") { 
    # NOP
    return
}

if ($fmt -ne "utf8") {
    Write-Warning "Unexpected format: $fmt. Skipping file: $file"
    return
}

[byte[]] $bytes = [System.IO.File]::ReadAllBytes($file)
[byte []] $bom = @(0xef, 0xbb, 0xbf)
[System.IO.File]::WriteAllBytes($file, $bom + $bytes)

$fmt = &$PSScriptRoot/Get-TextFileEncoding -FromScript $file
if ($fmt -ne "utf8 + BOM") {
    throw "Internal error: fmt is now: $fmt"
}

