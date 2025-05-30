# Finds a shortcut definition from a list of global shortcuts
param($Shortcut, [switch] $ListAll)

$shortcuts = [ordered] @{
    "a"   = "/a"
    "b"   = "/a/b"
}

if ($ListAll) { return $shortcuts }
return $shortcuts[$Shortcut] # or $null

