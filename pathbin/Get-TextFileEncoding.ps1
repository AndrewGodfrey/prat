# Looks at the preamble of the given text file to distinguish utf8 with and without BOM, and utf16.
# That's all it supports. I need it for apps that like to add a BOM (especially utf8 + BOM) when that's really not wanted.
using module ../lib/PratBase/PratBase.psd1

param ($pathspec)

function ReadFirstBytes($file, $n) {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        Get-Content $file -Encoding byte -TotalCount $n
    } else {
        Get-Content $file -AsByteStream -TotalCount $n
    }
}

$paths = @() + (Resolve-Path $pathspec)
if (!$?) { return }
if (($paths.Length -eq 1) -and (Test-Path -PathType Container $paths[0])) {
    $pathspec = $paths[0].Path + "/*"
    $paths = @() + (Resolve-Path $pathspec)
}
$files = @() + ($paths | ? { Test-Path -PathType Leaf $_ })
foreach ($file in $files) {
    [byte[]] $b = ReadFirstBytes $file 3

    function startsWith($a, $prefix) {
        if ($a.Count -lt $prefix.Count) { return $false }
        $i = 0
        foreach ($b in $prefix) {
            if ($a[$i] -ne $b) { return $false }
            $i++
        }
        return $true
    }

    function isAscii($val) { return ($val -gt 0x0) -and ($val -lt 0x80) }

    $fmt = "<unknown>"
    if ($b.Count -eq 0) { $fmt = "empty file"} else {
        if (startsWith $b @(0xef, 0xbb, 0xbf)) { $fmt = "utf8 + BOM" }
        if (startsWith $b @(0xfe, 0xff)) { $fmt = "utf16 + BOM (BE)" }
        if (startsWith $b @(0xff, 0xfe)) { $fmt = "utf16 + BOM (LE)" }
        if ($b.Count -ge 2) {
            if ((isAscii $b[0]) -and (isAscii $b[1])) { $fmt = "utf8" }
            if ((isAscii $b[0]) -and ($b[1] -eq 0)) { $fmt = "utf16" }
        }
    }

    if (Test-PathIsUnder $file $pwd) {
        $message = "$(Get-RelativePath $pwd $file): $fmt"
    } else {
        $message = "$($file): $fmt"
    }
    if ($fmt -ne "utf8") {
        Write-Host -ForegroundColor Yellow $message
    } else {
        Write-Host $message
    }
}

