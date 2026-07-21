BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-AgentRoles" {
    It "expands a role's skillGroups into a flat skill list" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git', 'test') } }
            @{ roles = @{ default = @{ skillGroups = @('core') } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.default.skills | Should -Be @('git', 'test')
    }

    It "merges skillGroups from multiple layers" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git') } }
            @{ skillGroups = @{ writing = @('kql') } }
            @{ roles = @{ default = @{ skillGroups = @('core', 'writing') } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.default.skills | Should -Be @('git', 'kql')
    }

    It "lets a higher layer override a skillGroup on name collision (base-first merge)" {
        $contribs = @(
            @{ skillGroups = @{ core = @('old') } }        # base
            @{ skillGroups = @{ core = @('new') } }        # higher — wins
            @{ roles = @{ default = @{ skillGroups = @('core') } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.default.skills | Should -Be @('new')
    }

    It "includes a role's explicit skills alongside its groups" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git') } }
            @{ roles = @{ default = @{ skillGroups = @('core'); skills = @('extra') } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.default.skills | Should -Be @('git', 'extra')
    }

    It "de-duplicates a skill that appears in more than one group" {
        $contribs = @(
            @{ skillGroups = @{ a = @('git', 'test'); b = @('git', 'review') } }
            @{ roles = @{ default = @{ skillGroups = @('a', 'b') } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        @($roles.default.skills | Where-Object { $_ -eq 'git' }).Count | Should -Be 1
    }

    It "carries a role's repo binding through" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git') } }
            @{ roles = @{ llamacpp = @{ skillGroups = @('core'); repo = 'llamacpp' } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.llamacpp.repo | Should -Be 'llamacpp'
    }

    It "omits repo for roles without a binding" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git') } }
            @{ roles = @{ default = @{ skillGroups = @('core') } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.default.ContainsKey('repo') | Should -BeFalse
    }

    It "carries a role's repoSkills through" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git') } }
            @{ roles = @{ myrole = @{ skillGroups = @('core'); repoSkills = @(@{ repo = 'myrepo'; from = '.claude/skills'; skills = @('myskill') }) } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.myrole.repoSkills[0].repo   | Should -Be 'myrepo'
        $roles.myrole.repoSkills[0].skills | Should -Be @('myskill')
    }

    It "omits repoSkills for roles without any" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git') } }
            @{ roles = @{ default = @{ skillGroups = @('core') } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.default.ContainsKey('repoSkills') | Should -BeFalse
    }

    It "carries a role's repoAgents through" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git') } }
            @{ roles = @{ myrole = @{ skillGroups = @('core'); repoAgents = @(@{ repo = 'myrepo'; from = '.github/agents' }) } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.myrole.repoAgents[0].repo | Should -Be 'myrepo'
        $roles.myrole.repoAgents[0].from | Should -Be '.github/agents'
    }

    It "omits repoAgents for roles without any" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git') } }
            @{ roles = @{ default = @{ skillGroups = @('core') } } }
        )

        $roles = Get-AgentRoles -Contributions $contribs

        $roles.default.ContainsKey('repoAgents') | Should -BeFalse
    }

    Context "harness filtering" {
        It "drops skills whose skillHarnesses allowlist excludes the harness" {
            $contribs = @(
                @{ skillGroups = @{ core = @('git', 'ccOnly') }; skillHarnesses = @{ ccOnly = @('cc') } }
                @{ roles = @{ default = @{ skillGroups = @('core') } } }
            )

            $roles = Get-AgentRoles -Contributions $contribs -Harness myharness

            $roles.default.skills | Should -Be @('git')
        }

        It "keeps skills whose allowlist includes the harness" {
            $contribs = @(
                @{ skillGroups = @{ core = @('multi') }; skillHarnesses = @{ multi = @('cc', 'myharness') } }
                @{ roles = @{ default = @{ skillGroups = @('core') } } }
            )

            $roles = Get-AgentRoles -Contributions $contribs -Harness myharness

            $roles.default.skills | Should -Be @('multi')
        }

        It "keeps skills absent from the skillHarnesses map (allowlist default)" {
            $contribs = @(
                @{ skillGroups = @{ core = @('git') } }
                @{ roles = @{ default = @{ skillGroups = @('core') } } }
            )

            $roles = Get-AgentRoles -Contributions $contribs -Harness myharness

            $roles.default.skills | Should -Be @('git')
        }

        It "does not filter when -Harness is omitted" {
            $contribs = @(
                @{ skillGroups = @{ core = @('git', 'ccOnly') }; skillHarnesses = @{ ccOnly = @('cc') } }
                @{ roles = @{ default = @{ skillGroups = @('core') } } }
            )

            $roles = Get-AgentRoles -Contributions $contribs

            $roles.default.skills | Should -Be @('git', 'ccOnly')
        }

        It "merges skillHarnesses maps base-first (higher layer wins per skill)" {
            $contribs = @(
                @{ skillGroups = @{ core = @('sk') }; skillHarnesses = @{ sk = @('cc') } }       # base
                @{ skillHarnesses = @{ sk = @('cc', 'myharness') } }                                 # higher — wins
                @{ roles = @{ default = @{ skillGroups = @('core') } } }
            )

            $roles = Get-AgentRoles -Contributions $contribs -Harness myharness

            $roles.default.skills | Should -Be @('sk')
        }

        It "filters a role's explicit skills, not just group-sourced ones" {
            $contribs = @(
                @{ skillGroups = @{ core = @('git') }; skillHarnesses = @{ extra = @('cc') } }
                @{ roles = @{ default = @{ skillGroups = @('core'); skills = @('extra') } } }
            )

            $roles = Get-AgentRoles -Contributions $contribs -Harness myharness

            $roles.default.skills | Should -Be @('git')
        }
    }

    It "throws when a role references an unknown skillGroup" {
        $contribs = @(
            @{ skillGroups = @{ core = @('git') } }
            @{ roles = @{ default = @{ skillGroups = @('nope') } } }
        )

        { Get-AgentRoles -Contributions $contribs } | Should -Throw "*unknown skillGroup 'nope'*"
    }

    It "reads, reverses (highest-first to base-first), and evaluates role files from disk" {
        $dir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "roles-disk"
        mkdir $dir | Out-Null
        '@{ skillGroups = @{ core = @("old") } }' | Out-File "$dir\roles_prat.ps1" -Encoding utf8NoBOM
        '@{ skillGroups = @{ core = @("new") }; roles = @{ default = @{ skillGroups = @("core") } } }' |
            Out-File "$dir\roles_de.ps1" -Encoding utf8NoBOM

        # -RolesFiles is highest-first (as Resolve-PratLibFile returns); the high (de) layer wins.
        $roles = Get-AgentRoles -RolesFiles @("$dir\roles_de.ps1", "$dir\roles_prat.ps1")

        $roles.default.skills | Should -Be @('new')
    }
}
