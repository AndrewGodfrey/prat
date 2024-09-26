# Like Set-Location, but using a shortcut that's interpreted using Find-Shortcut and Find-CodebaseShortcut
param($Shortcut="", [switch] $Test)

function emit($key, $target) {
    $target = $target -replace "\\", "/"
    $p = 20-$key.Length
    if ($p -lt 1) { $p = 1 }
    $padding = ' ' * $p
    echo "$key$padding$target"
}

if ($Shortcut -eq "?") {
    $globalShortcuts = &$PSScriptRoot/../lib/Find-Shortcut -ListAll

    foreach ($key in ($globalShortcuts.Keys | Sort-Object)) {
        emit $key $globalShortcuts[$key]
    }

    $cbts = &$PSScriptRoot/../lib/Find-CodebaseShortcut -ListAll
    foreach ($cbt in $cbts) {
        # echo "$($cbt.id):"
        foreach ($key in ($cbt.shortcuts.Keys | Sort-Object)) {
            $target = $cbt.root + "/" + $cbt.shortcuts[$key]
            emit $key $target
        }
    }
    return
}

function findTestDir($tt) {
    $c = "$($tt)Test"; if (Test-Path $c) { return $c }
    $c = "$($tt)Tests"; if (Test-Path $c) { return $c }
    if (Test-Path $tt) { return $tt }
    while ($true) {
        $parent = Split-Path -Parent $tt
        if ($parent -eq $tt) { break }
        if (Test-Path $parent) { return $parent }
        $tt = $parent
    }
    return $null
}

$target = &$PSScriptRoot/../lib/Find-Shortcut $Shortcut
if ($null -eq $target) { 
    $cbt = &$PSScriptRoot/../lib/Find-CodebaseShortcut $Shortcut
    if ($null -eq $cbt) { 
        throw "Unrecognized: $Shortcut" 
    }
    $target = $cbt.root + "/" + $cbt.shortcuts[$Shortcut]
    $target = $target -replace '\\', '/'

    if ($Test) {
        if ($null -ne $cbt.irregularTestShorcuts[$Shortcut]) {
            $target = $cbt.root + "/" + $cbt.irregularTestShorcuts[$Shortcut]
        } elseif ($null -ne $cbt.testDirFromDevDir) {
            $testTarget = &$cbt.testDirFromDevDir $target
            $alt = findTestDir $testTarget
            if ($null -ne $alt) { $target = $alt } else {
                Write-Warning "No test dir found, leaving you in dev"
            }
        }
    }
}

cd $target
