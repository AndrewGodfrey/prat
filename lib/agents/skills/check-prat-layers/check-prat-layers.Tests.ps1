BeforeAll {
    . "$PSScriptRoot/check-prat-layers.ps1"

    $script:pratBase  = @{ bannedPatterns = @(@{ pattern = 'prat-rule';  description = 'prat rule'  }) }
    $script:prefsBase = @{ bannedPatterns = @(@{ pattern = 'prefs-rule'; description = 'prefs rule' }) }
    $script:augPrat   = @{ bannedPatterns = @(@{ pattern = 'de-prat-rule';  description = 'de prat rule'  }) }
    $script:augPrefs  = @{ bannedPatterns = @(@{ pattern = 'de-prefs-rule'; description = 'de prefs rule' }) }
}

Describe 'Build-PratEffectiveConfig' {
    Context 'no de config' {
        It 'returns prat patterns unchanged' {
            $result = Build-PratEffectiveConfig $script:pratBase $null

            $result.bannedPatterns | Should -HaveCount 1
            $result.bannedPatterns[0].pattern | Should -Be 'prat-rule'
        }
    }

    Context 'de config with augmentPrat' {
        It 'merges de augment patterns into prat config' {
            $deConfig = @{ augmentPrat = $script:augPrat }

            $result = Build-PratEffectiveConfig $script:pratBase $deConfig

            $result.bannedPatterns | Should -HaveCount 2
            $result.bannedPatterns[1].pattern | Should -Be 'de-prat-rule'
        }
    }

    Context 'de config without augmentPrat key' {
        It 'returns prat patterns unchanged' {
            $result = Build-PratEffectiveConfig $script:pratBase @{ }

            $result.bannedPatterns | Should -HaveCount 1
        }
    }

    Context 'de config with augmentPrat but no bannedPatterns key' {
        It 'does not add null entries' {
            $result = Build-PratEffectiveConfig $script:pratBase @{ augmentPrat = @{ } }

            $result.bannedPatterns | Should -HaveCount 1
        }
    }
}

Describe 'Build-PrefsEffectiveConfig' {
    Context 'no prefs config' {
        It 'returns empty patterns (not prat rules — prat rules do not apply within prefs)' {
            $result = Build-PrefsEffectiveConfig $null $null

            $result.bannedPatterns | Should -HaveCount 0
        }
    }

    Context 'no prefs config, de with augmentPrefs' {
        It 'applies de augmentation on top of empty base' {
            $deConfig = @{ augmentPrefs = $script:augPrefs }

            $result = Build-PrefsEffectiveConfig $null $deConfig

            $result.bannedPatterns | Should -HaveCount 1
            $result.bannedPatterns[0].pattern | Should -Be 'de-prefs-rule'
        }
    }

    Context 'prefs config, no de config' {
        It 'returns prefs own patterns' {
            $result = Build-PrefsEffectiveConfig $script:prefsBase $null

            $result.bannedPatterns | Should -HaveCount 1
            $result.bannedPatterns[0].pattern | Should -Be 'prefs-rule'
        }
    }

    Context 'prefs config, de config with augmentPrefs' {
        It 'merges de augment patterns into prefs config' {
            $deConfig = @{ augmentPrefs = $script:augPrefs }

            $result = Build-PrefsEffectiveConfig $script:prefsBase $deConfig

            $result.bannedPatterns | Should -HaveCount 2
            $result.bannedPatterns[1].pattern | Should -Be 'de-prefs-rule'
        }
    }

    Context 'prefs config, de config without augmentPrefs key' {
        It 'returns prefs patterns unchanged' {
            $result = Build-PrefsEffectiveConfig $script:prefsBase @{ }

            $result.bannedPatterns | Should -HaveCount 1
        }
    }

    Context 'prefs config, de config with augmentPrefs but no bannedPatterns key' {
        It 'does not add null entries' {
            $result = Build-PrefsEffectiveConfig $script:prefsBase @{ augmentPrefs = @{ } }

            $result.bannedPatterns | Should -HaveCount 1
        }
    }
}

Describe 'Invoke-FindSensitiveData' {
    It 'delegates to Find-SensitiveData' {
        $td = (Get-Item 'TestDrive:\').FullName -replace '\\', '/'
        { Invoke-FindSensitiveData $td } | Should -Not -Throw
    }
}

Describe 'Invoke-CheckPratLayers' {
    BeforeAll {
        $script:td = ((Get-Item 'TestDrive:\').FullName -replace '\\', '/').TrimEnd('/')

        New-Item -ItemType Directory "$script:td/prat/lib"     -Force | Out-Null
        New-Item -ItemType Directory "$script:td/prat/pathbin" -Force | Out-Null
        Set-Content "$script:td/prat/lib/layerViolationsConfig_prat.ps1" `
            '$pratLayerViolationsConfig = @{ bannedPatterns = @(@{ pattern = "prat-rule"; description = "prat" }) }'
        Set-Content "$script:td/prat/pathbin/Find-LayerViolations.ps1" 'param($Path, $Config)'

        New-Item -ItemType Directory "$script:td/prefs/lib" -Force | Out-Null
        Set-Content "$script:td/prefs/lib/layerViolationsConfig_prefs.ps1" `
            '$prefsLayerViolationsConfig = @{ bannedPatterns = @(@{ pattern = "prefs-rule"; description = "prefs" }) }'

        New-Item -ItemType Directory "$script:td/prefs-noconfig/lib" -Force | Out-Null

        New-Item -ItemType Directory "$script:td/de/lib" -Force | Out-Null
        Set-Content "$script:td/de/lib/layerViolationsConfig_de.ps1" @'
$deLayerViolationsConfig = @{
    augmentPrat  = @{ bannedPatterns = @(@{ pattern = "de-prat";  description = "de prat"  }) }
    augmentPrefs = @{ bannedPatterns = @(@{ pattern = "de-prefs"; description = "de prefs" }) }
}
'@
    }

    BeforeEach {
        Mock Invoke-FindSensitiveData { }
    }

    Context 'prat only' {
        It 'scans prat once' {
            Invoke-CheckPratLayers "$script:td/prat" $null $null

            Should -Invoke Invoke-FindSensitiveData -Times 1 -ParameterFilter { $Path -eq "$script:td/prat" }
        }
    }

    Context 'prat + prefs with config file' {
        It 'scans both repos' {
            Invoke-CheckPratLayers "$script:td/prat" "$script:td/prefs" $null

            Should -Invoke Invoke-FindSensitiveData -Times 1 -ParameterFilter { $Path -eq "$script:td/prat" }
            Should -Invoke Invoke-FindSensitiveData -Times 1 -ParameterFilter { $Path -eq "$script:td/prefs" }
        }
    }

    Context 'prefs dir present but no config file' {
        It 'still scans prefs (with prat fallback config)' {
            Invoke-CheckPratLayers "$script:td/prat" "$script:td/prefs-noconfig" $null

            Should -Invoke Invoke-FindSensitiveData -Times 2
        }
    }

    Context 'prat + prefs + de with config and augmentations' {
        It 'scans both repos with merged configs' {
            Invoke-CheckPratLayers "$script:td/prat" "$script:td/prefs" "$script:td/de"

            Should -Invoke Invoke-FindSensitiveData -Times 2
        }
    }
}
