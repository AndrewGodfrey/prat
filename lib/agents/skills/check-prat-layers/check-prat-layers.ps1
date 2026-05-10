function Build-PratEffectiveConfig($pratConfig, $deConfig) {
    $eff = @{ bannedPatterns = [array]$pratConfig.bannedPatterns }
    if ($null -ne $deConfig -and $deConfig.augmentPrat.bannedPatterns) {
        $eff.bannedPatterns += $deConfig.augmentPrat.bannedPatterns
    }
    return $eff
}

function Build-PrefsEffectiveConfig($prefsConfig, $deConfig) {
    $eff = @{ bannedPatterns = @() }
    if ($null -ne $prefsConfig) {
        $eff.bannedPatterns += [array]$prefsConfig.bannedPatterns
    }
    if ($null -ne $deConfig -and $deConfig.augmentPrefs.bannedPatterns) {
        $eff.bannedPatterns += $deConfig.augmentPrefs.bannedPatterns
    }
    return $eff
}

function Invoke-FindSensitiveData($path) { Find-SensitiveData -Path $path }

function Invoke-CheckPratLayers($pratRoot, $prefsRoot, $deRoot) {
    . "$pratRoot/lib/layerViolationsConfig_prat.ps1"

    $prefsConfig = $null
    if ($prefsRoot) {
        $f = "$prefsRoot/lib/layerViolationsConfig_prefs.ps1"
        if (Test-Path $f) {
            . $f
            $prefsConfig = $prefsLayerViolationsConfig
        }
    }

    $deConfig = $null
    if ($deRoot) {
        $f = "$deRoot/lib/layerViolationsConfig_de.ps1"
        if (Test-Path $f) {
            . $f
            $deConfig = $deLayerViolationsConfig
        }
    }

    $pratEffective = Build-PratEffectiveConfig $pratLayerViolationsConfig $deConfig

    Write-Host "=== prat ==="
    Invoke-FindSensitiveData $pratRoot
    & "$pratRoot/pathbin/Find-LayerViolations.ps1" -Path $pratRoot -Config $pratEffective

    if ($prefsRoot) {
        Write-Host ""
        Write-Host "=== prefs ==="
        Invoke-FindSensitiveData $prefsRoot
        $prefsEffective = Build-PrefsEffectiveConfig $prefsConfig $deConfig
        & "$pratRoot/pathbin/Find-LayerViolations.ps1" -Path $prefsRoot -Config $prefsEffective
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $layers    = Get-CodebaseLayers
    $pratRoot  = ($layers | Where-Object Name -eq 'prat').Path
    $prefsRoot = ($layers | Where-Object Name -eq 'prefs')?.Path
    $deRoot    = ($layers | Where-Object Name -eq 'de')?.Path
    Invoke-CheckPratLayers $pratRoot $prefsRoot $deRoot
}
