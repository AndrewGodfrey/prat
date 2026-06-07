function Get-DevToolRegistry([string[]] $Files) {
    $registry = @{}
    foreach ($file in $Files) {
        $layerData = Import-Scriptblock $file
        foreach ($key in $layerData.Keys) {
            if (-not $registry.ContainsKey($key)) {
                $registry[$key] = $layerData[$key]
            }
        }
    }
    return $registry
}

function Get-DevToolPath([string] $ToolName) {
    $files = @(Resolve-PratLibFile "lib/toolRegistry.ps1" -ListAll)
    return (Get-DevToolRegistry $files)[$ToolName]
}
