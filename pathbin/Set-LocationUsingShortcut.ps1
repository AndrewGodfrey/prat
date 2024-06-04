# Like Set-Location, but using a shortcut that's interpreted using Find-Shortcut and Find-CodebaseShortcut
param($Shortcut="")

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

$target = &$PSScriptRoot/../lib/Find-Shortcut $Shortcut
if ($null -eq $target) { 
    $cbt = &$PSScriptRoot/../lib/Find-CodebaseShortcut $Shortcut
    if ($null -eq $cbt) { 
        Write-Error "Unrecognized: $Shortcut" 
        return
    }
    $target = $cbt.root + "/" + $cbt.shortcuts[$Shortcut]
}

cd $target


