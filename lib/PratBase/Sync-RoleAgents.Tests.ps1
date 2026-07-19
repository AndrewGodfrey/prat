BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Sync-RoleAgents" {
    BeforeEach {
        $script:root    = Join-Path (Get-Item "TestDrive:\").FullName ("sra_" + [guid]::NewGuid().ToString('N'))
        $script:roleDir = Join-Path $root 'agentRole'
        $script:repoA   = Join-Path $root 'repoA'
        $script:repoB   = Join-Path $root 'repoB'
        New-Item -ItemType Directory -Path $roleDir, $repoA, $repoB -Force | Out-Null

        $map = @{ repoA = $repoA; repoB = $repoB }
        $script:resolver = { param($id) $map[$id] }.GetNewClosure()

        # Create an agents source dir <repoRoot>/<from> with one .agent.md file (name/content configurable);
        # returns its full path.
        function newAgentsSource($repoRoot, $from, [string] $name = 'sample-reviewer.agent.md', [string] $content = 'agent body') {
            $d = Join-Path $repoRoot $from
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            $content | Out-File (Join-Path $d $name) -Encoding utf8NoBOM
            $d
        }

        function linkType($path) { (Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue).LinkType }
        function linkTarget($path) {
            $t = @((Get-Item -LiteralPath $path -Force).Target)[0]
            [System.IO.Path]::GetFullPath($t).TrimEnd('\')
        }

        $script:subagentsDir = Join-Path $roleDir 'subagents'
        $script:claudeLink   = Join-Path $roleDir '.claude\agents'
        $script:githubLink   = Join-Path $roleDir '.github\agents'
    }

    Context "subagents dir (merged, owned copy of repo agent files)" {
        It "copies agent files from the repo source into subagents" {
            newAgentsSource $repoA '.github\agents' | Out-Null
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Get-Content (Join-Path $subagentsDir 'sample-reviewer.agent.md') | Should -Be 'agent body'
        }

        It "preserves relative subdirectory structure from the source" {
            $src = newAgentsSource $repoA '.github\agents'
            New-Item -ItemType Directory -Path (Join-Path $src 'nested') -Force | Out-Null
            "nested body" | Out-File (Join-Path $src 'nested\extra.agent.md') -Encoding utf8NoBOM

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Get-Content (Join-Path $subagentsDir 'nested\extra.agent.md') | Should -Be 'nested body'
        }

        It "skips and warns when the repo is not registered" {
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -WarningVariable w `
                -RepoAgents @(@{ repo = 'ghost'; from = '.github\agents' })

            $subagentsDir | Should -Not -Exist
            "$w" | Should -BeLike '*not registered*'
        }

        It "skips and warns when the agents source dir does not exist" {
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -WarningVariable w `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            $subagentsDir | Should -Not -Exist
            "$w" | Should -BeLike '*does not exist*'
        }

        It "removes subagents entirely when no longer desired" {
            newAgentsSource $repoA '.github\agents' | Out-Null
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })
            $subagentsDir | Should -Exist

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -RepoAgents @()
            $subagentsDir | Should -Not -Exist
        }

        It "prunes a file whose source no longer exists (self-heal)" {
            $src = newAgentsSource $repoA '.github\agents'
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Remove-Item -LiteralPath (Join-Path $src 'sample-reviewer.agent.md') -Force
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Join-Path $subagentsDir 'sample-reviewer.agent.md' | Should -Not -Exist
        }

        It "copies an updated file when the source content changes" {
            $src = newAgentsSource $repoA '.github\agents'
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Start-Sleep -Milliseconds 50
            "updated body" | Out-File (Join-Path $src 'sample-reviewer.agent.md') -Encoding utf8NoBOM
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Get-Content (Join-Path $subagentsDir 'sample-reviewer.agent.md') | Should -Be 'updated body'
        }

        It "does not re-copy a file that's already up to date" {
            newAgentsSource $repoA '.github\agents' | Out-Null
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            $dest = Join-Path $subagentsDir 'sample-reviewer.agent.md'
            "manually edited, should survive" | Out-File $dest -Encoding utf8NoBOM
            (Get-Item $dest).LastWriteTime = (Get-Date).AddDays(1)   # newer than the source

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Get-Content $dest | Should -Be 'manually edited, should survive'
        }

        It "merges agent files from two different repos" {
            newAgentsSource $repoA '.github\agents' -Name 'from-a.agent.md' -Content 'a body' | Out-Null
            newAgentsSource $repoB '.github\agents' -Name 'from-b.agent.md' -Content 'b body' | Out-Null

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -RepoAgents @(
                @{ repo = 'repoA'; from = '.github\agents' }
                @{ repo = 'repoB'; from = '.github\agents' }
            )

            Get-Content (Join-Path $subagentsDir 'from-a.agent.md') | Should -Be 'a body'
            Get-Content (Join-Path $subagentsDir 'from-b.agent.md') | Should -Be 'b body'
        }

        It "keeps the first entry and warns on a filename collision between repos" {
            newAgentsSource $repoA '.github\agents' -Content 'a body' | Out-Null
            newAgentsSource $repoB '.github\agents' -Content 'b body' | Out-Null

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -WarningVariable w -RepoAgents @(
                @{ repo = 'repoA'; from = '.github\agents' }
                @{ repo = 'repoB'; from = '.github\agents' }
            )

            Get-Content (Join-Path $subagentsDir 'sample-reviewer.agent.md') | Should -Be 'a body'
            "$w" | Should -BeLike '*declared by more than one source*'
        }

        It "removing one repo's entry prunes only that repo's files" {
            newAgentsSource $repoA '.github\agents' -Name 'from-a.agent.md' | Out-Null
            newAgentsSource $repoB '.github\agents' -Name 'from-b.agent.md' | Out-Null
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -RepoAgents @(
                @{ repo = 'repoA'; from = '.github\agents' }
                @{ repo = 'repoB'; from = '.github\agents' }
            )

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoB'; from = '.github\agents' })

            Join-Path $subagentsDir 'from-a.agent.md' | Should -Not -Exist
            Join-Path $subagentsDir 'from-b.agent.md' | Should -Exist
        }

        It "replaces a legacy junction-based subagents dir with an owned copy" {
            $src = newAgentsSource $repoA '.github\agents'
            New-Item -ItemType Junction -Path $subagentsDir -Target $src | Out-Null   # simulate the prior design's state

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            linkType $subagentsDir | Should -BeNullOrEmpty
            Get-Content (Join-Path $subagentsDir 'sample-reviewer.agent.md') | Should -Be 'agent body'
            Join-Path $src 'sample-reviewer.agent.md' | Should -Exist   # removing the junction didn't touch its target
        }

        It "removes a legacy junction-based subagents dir (link only) when nothing is desired" {
            $src = newAgentsSource $repoA '.github\agents'
            New-Item -ItemType Junction -Path $subagentsDir -Target $src | Out-Null   # simulate the prior design's state

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -RepoAgents @()

            $subagentsDir | Should -Not -Exist
            Join-Path $src 'sample-reviewer.agent.md' | Should -Exist   # removing the junction didn't touch its target
        }

        It "prunes an empty subdirectory left behind after its last file is removed" {
            $src = newAgentsSource $repoA '.github\agents'
            New-Item -ItemType Directory -Path (Join-Path $src 'nested') -Force | Out-Null
            "nested body" | Out-File (Join-Path $src 'nested\extra.agent.md') -Encoding utf8NoBOM
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })
            Join-Path $subagentsDir 'nested' | Should -Exist

            Remove-Item -LiteralPath (Join-Path $src 'nested') -Recurse -Force
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Join-Path $subagentsDir 'nested' | Should -Not -Exist
        }
    }

    Context "harness links (.claude/agents and .github/agents -> subagents)" {
        It "creates a junction from <_.rel> to subagents" -ForEach @(
            @{ rel = '.claude\agents' }
            @{ rel = '.github\agents' }
        ) {
            newAgentsSource $repoA '.github\agents' | Out-Null
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            $link = Join-Path $roleDir $rel
            linkType $link | Should -Be 'Junction'
            linkTarget $link | Should -Be ([System.IO.Path]::GetFullPath($subagentsDir).TrimEnd('\'))
        }

        It "exposes the agent file through <_.rel>" -ForEach @(
            @{ rel = '.claude\agents' }
            @{ rel = '.github\agents' }
        ) {
            newAgentsSource $repoA '.github\agents' | Out-Null
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Join-Path (Join-Path $roleDir $rel) 'sample-reviewer.agent.md' | Should -Exist
        }

        It "removes <_.rel> when subagents is no longer desired" -ForEach @(
            @{ rel = '.claude\agents' }
            @{ rel = '.github\agents' }
        ) {
            newAgentsSource $repoA '.github\agents' | Out-Null
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -RepoAgents @()

            Join-Path $roleDir $rel | Should -Not -Exist
        }

        It "leaves a real (non-junction) <_.rel> dir untouched and warns" -ForEach @(
            @{ rel = '.claude\agents' }
            @{ rel = '.github\agents' }
        ) {
            $link = Join-Path $roleDir $rel
            New-Item -ItemType Directory -Path $link -Force | Out-Null
            "hand-authored" | Out-File (Join-Path $link 'local.agent.md') -Encoding utf8NoBOM
            newAgentsSource $repoA '.github\agents' | Out-Null

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -WarningVariable w `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            linkType $link | Should -BeNullOrEmpty
            Get-Content (Join-Path $link 'local.agent.md') | Should -Be 'hand-authored'
            "$w" | Should -BeLike '*non-junction*'
        }

        It "does not create harness links when no agents are configured" {
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -RepoAgents @()

            $claudeLink | Should -Not -Exist
            $githubLink | Should -Not -Exist
        }

        It "leaves already-correct harness junctions in place across a resync (idempotent)" {
            newAgentsSource $repoA '.github\agents' | Out-Null
            $entries = @(@{ repo = 'repoA'; from = '.github\agents' })
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -RepoAgents $entries
            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver -RepoAgents $entries

            linkType $claudeLink | Should -Be 'Junction'
            linkType $githubLink | Should -Be 'Junction'
        }

        It "re-points <_.rel> when it's a junction pointing somewhere else" -ForEach @(
            @{ rel = '.claude\agents' }
            @{ rel = '.github\agents' }
        ) {
            newAgentsSource $repoA '.github\agents' | Out-Null
            $link   = Join-Path $roleDir $rel
            $parent = Split-Path $link -Parent
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
            New-Item -ItemType Junction -Path $link -Target $repoB | Out-Null   # stale target

            Sync-RoleAgents -RoleDir $roleDir -ResolveRepoRoot $resolver `
                -RepoAgents @(@{ repo = 'repoA'; from = '.github\agents' })

            linkType $link | Should -Be 'Junction'
            linkTarget $link | Should -Be ([System.IO.Path]::GetFullPath($subagentsDir).TrimEnd('\'))
        }
    }
}
