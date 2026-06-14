using module ..\PratBase\PratBase.psd1

# Snapshot module hashes at session start for stale-module detection
. "$PSScriptRoot/../moduleHashes.ps1"
$global:__prat_moduleHashesAtStart = pratGetModuleHashSnapshot

# If we were spawned by something other than the loop controller (e.g. Enter-Codebase),
# reset depth so 'rs' works correctly in this shell.
if ($env:__prat_shellDepth -eq '1' -and $null -ne $env:__prat_loopControllerPid) {
    $parentPid = (Get-Process -Id $pid -ErrorAction SilentlyContinue)?.Parent?.Id
    if ($env:__prat_loopControllerPid -ne "$parentPid") {
        $env:__prat_shellDepth = $null
    }
}

. $PSScriptRoot\initProfileTracing.ps1

pratProfile_trace start "scriptProfile.ps1"

$env:PYTHONPYCACHEPREFIX = "$home/prat/auto/pycache"

$_pratroot = Resolve-Path $PSScriptRoot\..\..

pratProfile_trace done "Resolve-Path"

. $PSScriptRoot\Define-ShortcutFunctions.ps1

pratProfile_trace done "Define-ShortcutFunctions"


$aliasFile = "$_pratroot\auto\profile\scriptAliases.ps1"
if (Test-Path $aliasFile) { Import-PratAliases $aliasFile}
pratProfile_trace done "Installed aliases"

# Customize 'dir' output - better output format for 'length' column:
Update-FormatData -PrependPath $PSScriptRoot\FileSystem.format.ps1xml

pratProfile_trace done "Update-FormatData"

&$PSScriptRoot\Set-PratBinPaths.ps1

# Remove curl alias, as Windows 10+ comes with curl.exe
if (Test-Path alias:curl) { del alias:curl }

# Remove the wget alias that WindowsPowershell installs, if we've installed a replacement. (This assumes that the replacement is an exe that's in PATH).
if ($PSVersionTable.PSVersion.Major -lt 6) {
    if ((Test-Path alias:wget) -and (Get-Command 'wget.exe' -ErrorAction SilentlyContinue)) {
        del alias:wget
    }
}

pratProfile_trace end "scriptProfile.ps1"