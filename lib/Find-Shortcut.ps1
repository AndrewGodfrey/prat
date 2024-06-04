# Finds a shortcut definition from a list of global shortcuts
param($Shortcut, [switch] $ListAll)

$shortcuts = [ordered] @{
    "appdata" = $env:appdata
    "desktop" = "$home/desktop"
    "startup" = "$env:appdata/Microsoft/Windows/Start Menu/Programs/Startup"
    "hosts"   = "$env:windir\system32\drivers\etc"
}

if ($ListAll) { return $shortcuts }
if ($null -ne $shortcuts[$Shortcut]) { return $shortcuts[$Shortcut] }

