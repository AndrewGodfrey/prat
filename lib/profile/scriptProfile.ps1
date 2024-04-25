using module ..\PratBase\PratBase.psd1

$pratProfile_shouldTrace = $false
if ($pratProfile_shouldTrace) {
    $pratProfile_startDate = Get-Date
    $pratProfile_prevDate = $pratProfile_startDate
    function pratProfile_trace {
        param ([string] $msg)

        $now = Get-Date
        $duration = ($now - $pratProfile_startDate).TotalSeconds
        $delta = ($now - $pratProfile_prevDate).TotalSeconds
        $script:pratProfile_prevDate = $now
        echo ([String]::Format("{0} ({1:F1}s, {2:F2}s)", $msg, $duration, $delta))
    }
} else {
    function pratProfile_trace {}
}

$_pratroot = Resolve-Path $PSScriptRoot\..\..

pratProfile_trace "scriptProfile.ps1 starting"

. $PSScriptRoot\Define-ShortcutFunctions.ps1

pratProfile_trace "Done: Define-ShortcutFunctions"


$aliasFile = "$_pratroot\auto\profile\scriptAliases.ps1"
if (Test-Path $aliasFile) { Import-PratAliases $aliasFile}
pratProfile_trace "Done: Installed aliases"

# Customize 'dir' output - better output format for 'length' column:
. $PSScriptRoot\profile_GetOptimalSize.ps1
Update-FormatData -PrependPath $PSScriptRoot\FileSystem.format.ps1xml

pratProfile_trace "Done: Update-FormatData"

$env:path += (&$PSScriptRoot\getBinPaths.ps1)

# Remove curl alias, as Windows 10+ comes with curl.exe
if (Test-Path alias:curl) { del alias:curl }

pratProfile_trace "scriptProfile.ps1 ending"

