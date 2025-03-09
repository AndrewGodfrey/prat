# Used by ArgumentCompleters. Gets a list of available options,
# either by calculation, or from a cache
param ($listId)

function CalculateAnswer($listId) {
    switch ($listId) {
        "Set-LocationUsingShortcut-Shortcut" {
            return (Set-LocationUsingShortcut -ListAll).Keys
        }
        default {
            throw "Unknown listId: $listId"
        }
    }
}

function GetCacheLocation($listId) {
    $dir = "$home\prat\auto\cachedCompletionLists"
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
    return "$dir\$listId.ps1"
}

function IsCurrent($file) {
    if (!(Test-Path $file)) { return $false }
    $age = (Get-ChildItem $file).LastWriteTime - (Get-Date)
    if ($age.TotalDays -gt 1) { return $false }
    return $true
}

$loc = GetCacheLocation $listId
if (IsCurrent $loc) {
    return &$loc
}

$answer = CalculateAnswer $listId
(ConvertTo-Expression $answer) | Out-File $loc 
return $answer