# Finds a shortcut definition from a list of global shortcuts
param($Shortcut, [switch] $ListAll)

$shortcuts = [ordered] @{
    "appdata"   = $env:appdata
    "desktop"   = "$home/desktop"
    "downloads" = "$home/Downloads"
    "startup"   = "$env:appdata/Microsoft/Windows/Start Menu/Programs/Startup"
    "hosts"     = "$env:windir\system32\drivers\etc"
}

if ($ListAll) { return $shortcuts }
return $shortcuts[$Shortcut] # or $null

