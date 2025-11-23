#Requires -PSEdition Core, Desktop
<#
  Bootstrap scripts can use this to rearrange $env:Path, after they've called Install-PratBinPathOverride.ps1.

  .PARAMETER envPath
  A string, in the format "c:\foo;c:\bar".
#>
param ($envPath)

$paths = $envPath-split ";"
$pratPaths = @()
$otherPaths = @()
foreach ($p in $paths) {
    if ($p -match "\\prat(\\|$)") {
        $pratPaths += $p
    } else {
        $otherPaths += $p
    }
}
return ($otherPaths + $pratPaths) -join ";"
