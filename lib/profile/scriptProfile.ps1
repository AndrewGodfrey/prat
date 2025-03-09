using module ..\PratBase\PratBase.psd1

. $PSScriptRoot\initProfileTracing.ps1

pratProfile_trace start "scriptProfile.ps1"

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

&$PSScriptRoot\Add-PratBinPaths.ps1

# Remove curl alias, as Windows 10+ comes with curl.exe
if (Test-Path alias:curl) { del alias:curl }

# Remove the wget alias that WindowsPowershell installs, if we've installed a replacement. (This assumes that the replacement is an exe that's in PATH).
if ($PSVersionTable.PSVersion.Major -lt 6) {
    if ((Test-Path alias:wget) -and (Get-Command 'wget.exe' -ErrorAction SilentlyContinue)) {
        del alias:wget
    }
}

pratProfile_trace end "scriptProfile.ps1"