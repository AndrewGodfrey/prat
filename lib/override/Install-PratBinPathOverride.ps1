<#
  Add one or more override paths to Prat's binary search path. 
  They are added before Prat's own paths, so we can override things like Get-DevEnvironments.ps1.

  Note: For the bootstrap case, in order to get this far we would have put Prat in $env:Path already.
        So, after doing this step, a bootstrap script needs to rearrange $env:Path. 

  .PARAMETER overridePath
  A string, in the format "c:\foo;c:\bar".
#>
param($installationTracker, [string] $overrideBinPaths)

$stage = $installationTracker.StartStage("Install-PratBinPathOverride.ps1")
# Install a file "Get-OverrideBinPaths.ps1", which Add-PratBinPaths looks for.
Install-TextToFile $stage "$home\prat\auto\profile\Get-OverrideBinPaths.ps1" (ConvertTo-Expression $overrideBinPaths)
$installationTracker.EndStage($stage)

