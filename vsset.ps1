param($cmd)
$settingsFile = "$($env:localappdata)\Microsoft\VisualStudio\17.0_078781cc\Settings\CurrentSettings.vssettings"

function getLatestCopyNum() { # 0 means none
    $copies = dir $PSScriptRoot/vssettings/vssettings.* 
    if ($null -eq $copies) { return 0 }

    [int] $max = 0
    foreach ($item in $copies) {
        if ($item -notmatch ".([0-9]+)$") { Write-Warning "Skipping: $item"; continue }
        [int] $num = $Matches[1]
        if ($num -gt $max) { $max = $num }
    }
    return $max
}

# Tidy the XML. Makes for better diffs
function prettify($xmlFile) {
  $xmlFile = Resolve-Path $xmlFile # If you give a relative path to [xml].Save(), it saves relative to ~.
  $x = [xml] (Get-Content $xmlFile)
  $x.Save("$($xmlFile).xml")
}

switch ($cmd) {

    "cp" {
        $latest = getLatestCopyNum
        if ($latest -gt 0) {
            fc.exe $settingsFile $PSScriptRoot/vssettings/vssettings.$latest > $null
            if ($?) { 
                Write-Warning "No changes - doing nothing"
                return
            }
        }
        $newnum = $latest + 1
        cp $settingsFile $PSScriptRoot/vssettings/vssettings.$newnum
        prettify $PSScriptRoot/vssettings/vssettings.$newnum
    }
}