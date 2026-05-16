BeforeAll {
    $script:configFile = "$PSScriptRoot/Get-LayerViolationsConfig_prat.ps1"
}

Describe "Get-LayerViolationsConfig_prat" {
    It "returns a hashtable" {
        $result = & $script:configFile

        $result | Should -BeOfType [hashtable]
    }

    It "has a bannedPatterns key that is an array" {
        $result = & $script:configFile

        $result.ContainsKey('bannedPatterns') | Should -Be $true
        ($result.bannedPatterns -is [array]) | Should -Be $true
    }

    # Prat has no own banned patterns — higher layers contribute via augmentPrat.
    # If a pattern appears here it's a layer violation: the rule belongs to the layer that owns the name.
    It "bannedPatterns is empty" {
        $result = & $script:configFile

        $result.bannedPatterns | Should -HaveCount 0
    }

    It "excludedPaths contains 'auto/'" {
        $result = & $script:configFile

        $result.excludedPaths | Should -Contain 'auto/'
    }
}
