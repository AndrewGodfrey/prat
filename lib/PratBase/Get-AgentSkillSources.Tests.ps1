BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
    # TestDrive: is a PowerShell provider path, which .NET file APIs and external tools reject.
    $script:testRoot = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
    $script:scenario = 0

    function makeDirs([string[]] $relativeDirs) {
        foreach ($d in $relativeDirs) { New-Item -ItemType Directory "$root/$d" -Force | Out-Null }
    }
    # Layer descriptors as Get-CodebaseLayers returns them: highest layer first.
    function layers([string[]] $names) {
        @($names | ForEach-Object { @{ Name = $_; Path = "$root/$_" } })
    }
    function relativeTo([string[]] $paths) {
        @($paths | ForEach-Object { ($_ -replace '\\', '/').Substring($root.Length + 1) })
    }
}

Describe "Get-AgentSkillSources" {
    BeforeEach {
        # TestDrive outlives an It, so each test arranges its layers under a root of its own.
        $script:scenario++
        $script:root = "$testRoot/scenario$($script:scenario)"
    }

    It "returns each layer's skills dir base-first, from layers given highest-first" {
        makeDirs @('prat/lib/agents/skills', 'prefs/lib/agents/skills', 'de/lib/agents/skills')

        $sources = @(Get-AgentSkillSources -Layers (layers @('de', 'prefs', 'prat')))

        relativeTo $sources | Should -Be @('prat/lib/agents/skills', 'prefs/lib/agents/skills', 'de/lib/agents/skills')
    }

    It "skips a layer that has no skills dir" {
        makeDirs @('prat/lib/agents/skills', 'prefs/lib', 'de/lib/agents/skills')

        $sources = @(Get-AgentSkillSources -Layers (layers @('de', 'prefs', 'prat')))

        relativeTo $sources | Should -Be @('prat/lib/agents/skills', 'de/lib/agents/skills')
    }

    It "returns an empty list when no layer has one" {
        makeDirs @('prat/lib', 'prefs/lib', 'de/lib')

        $sources = @(Get-AgentSkillSources -Layers (layers @('de', 'prefs', 'prat')))

        $sources | Should -BeNullOrEmpty
    }

    It "defaults to the installed layers" {
        # The production callers omit -Layers; prat is the base layer, so its own dir comes first.
        $pratSkills = (Resolve-Path "$PSScriptRoot/../agents/skills").Path

        $sources = @(Get-AgentSkillSources)

        $sources[0] | Should -Be $pratSkills
    }
}
