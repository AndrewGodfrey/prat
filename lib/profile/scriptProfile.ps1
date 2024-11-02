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
        Write-Host -ForegroundColor DarkCyan ([String]::Format("  Startup trace: {0} ({1:F1}s, {2:F2}s)", $msg, $duration, $delta))
    }
} else {
    function pratProfile_trace {}
}

pratProfile_trace "Start: scriptProfile.ps1"

$_pratroot = Resolve-Path $PSScriptRoot\..\..

pratProfile_trace "Done:  Resolve-Path"

. $PSScriptRoot\Define-ShortcutFunctions.ps1

pratProfile_trace "Done:  Define-ShortcutFunctions"


$aliasFile = "$_pratroot\auto\profile\scriptAliases.ps1"
if (Test-Path $aliasFile) { Import-PratAliases $aliasFile}
pratProfile_trace "Done:  Installed aliases"

# Customize 'dir' output - better output format for 'length' column:
Update-FormatData -PrependPath $PSScriptRoot\FileSystem.format.ps1xml

pratProfile_trace "Done:  Update-FormatData"

$env:path += (&$PSScriptRoot\getBinPaths.ps1)

# Remove curl alias, as Windows 10+ comes with curl.exe
if (Test-Path alias:curl) { del alias:curl }

# Remove the wget alias that WindowsPowershell installs, if we've installed a replacement. (This assumes that the replacement is an exe that's in PATH).
if ($PSVersionTable.PSVersion.Major -lt 6) {
    if ((Test-Path alias:wget) -and (Get-Command 'wget.exe' -ErrorAction SilentlyContinue)) {
        del alias:wget
    }
}

pratProfile_trace "End:   scriptProfile.ps1"

