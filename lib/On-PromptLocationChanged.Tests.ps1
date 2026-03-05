BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "On-PromptLocationChanged" {
    BeforeEach {
        $global:__prat_currentLocation = $null
    }
    AfterEach {
        $global:__prat_currentLocation = $null
    }

    It "Sets currentLocation to newLocation when not inside any known repo" {
        Mock Get-PratProject { return $null }

        &$scriptToTest "/some/unknown/path"

        $global:__prat_currentLocation | Should -Be "/some/unknown/path"
    }

    It "Sets currentLocation to bracketed repo id when at repo root" {
        Mock Get-PratProject { return @{ id = 'MyRepo'; subdir = ''; buildKind = $null } }

        &$scriptToTest "/some/path"

        $global:__prat_currentLocation | Should -Be "[myrepo]"
    }

    It "Includes subdir when inside a subdirectory" {
        Mock Get-PratProject { return @{ id = 'MyRepo'; subdir = 'src\lib'; buildKind = $null } }

        &$scriptToTest "/some/path"

        $global:__prat_currentLocation | Should -Be "[myrepo] src/lib/"
    }

    It "Includes buildKind in parentheses when set" {
        Mock Get-PratProject { return @{ id = 'MyRepo'; subdir = ''; buildKind = 'CMake' } }

        &$scriptToTest "/some/path"

        $global:__prat_currentLocation | Should -Be "[myrepo](CMake)"
    }
}
