# .SYNOPSIS
# Gets the most recent n files
#
# Alias: lsl
param($filespec=$null, $n, [switch] $Recurse=$false)
$default_n = 10

if ($null -eq $n) { $n = $default_n }

function Get-RelativePath($path) {
    $p = $pwd.Path
    if ($path.StartsWith($p)) { "." + $path.Substring($p.Length) } else { $path }
}

Get-ChildItem $filespec -Recurse:$Recurse | 
    Sort-Object -Property LastWriteTime -Descending | 
    Select-Object -First $n |
    Format-Table -Property Mode, LastWriteTime, @{Name="Length";Expression={Get-OptimalSize $_.Length}}, @{Name="Path";Expression={Get-RelativePath $_.FullName}}
