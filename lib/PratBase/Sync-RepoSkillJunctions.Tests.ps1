BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Sync-RepoSkillJunctions" {
    BeforeEach {
        $script:root      = Join-Path (Get-Item "TestDrive:\").FullName ("srj_" + [guid]::NewGuid().ToString('N'))
        $script:skillsDir = Join-Path $root 'agentRole\.claude\skills'
        $script:repoA     = Join-Path $root 'repoA'
        $script:repoB     = Join-Path $root 'repoB'
        New-Item -ItemType Directory -Path $skillsDir, $repoA, $repoB -Force | Out-Null

        $map = @{ repoA = $repoA; repoB = $repoB }
        $script:resolver = { param($id) $map[$id] }.GetNewClosure()

        # Create a skill source dir <repoRoot>/<from>/<name> and return its full path.
        function newSource($repoRoot, $from, $name) {
            $d = Join-Path $repoRoot (Join-Path $from $name)
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            "skill body" | Out-File (Join-Path $d 'SKILL.md') -Encoding utf8NoBOM
            $d
        }

        function linkType($path) { (Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue).LinkType }
        function linkTarget($path) {
            $t = @((Get-Item -LiteralPath $path -Force).Target)[0]
            [System.IO.Path]::GetFullPath($t).TrimEnd('\')
        }
    }

    It "creates a junction to the skill source when it exists" {
        newSource $repoA '.github\skills' 'alpha' | Out-Null
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver `
            -RepoSkills @(@{ repo = 'repoA'; from = '.github\skills'; skills = @('alpha') })

        $link = Join-Path $skillsDir 'alpha'
        linkType $link | Should -Be 'Junction'
        Join-Path $link 'SKILL.md' | Should -Exist
    }

    It "points the junction at the correct target" {
        $src = newSource $repoA '.claude\skills' 'beta'
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver `
            -RepoSkills @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('beta') })

        linkTarget (Join-Path $skillsDir 'beta') | Should -Be ([System.IO.Path]::GetFullPath($src).TrimEnd('\'))
    }

    It "creates the skills dir if it does not exist" {
        Remove-Item -LiteralPath $skillsDir -Recurse -Force
        newSource $repoA '.claude\skills' 'alpha' | Out-Null
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver `
            -RepoSkills @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('alpha') })

        linkType (Join-Path $skillsDir 'alpha') | Should -Be 'Junction'
    }

    It "skips and warns when the repo is not registered" {
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver -WarningVariable w `
            -RepoSkills @(@{ repo = 'ghost'; from = '.claude\skills'; skills = @('alpha') })

        Join-Path $skillsDir 'alpha' | Should -Not -Exist
        "$w" | Should -BeLike '*not registered*'
    }

    It "skips and warns when the skill source dir does not exist" {
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver -WarningVariable w `
            -RepoSkills @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('nope') })

        Join-Path $skillsDir 'nope' | Should -Not -Exist
        "$w" | Should -BeLike '*does not exist*'
    }

    It "removes a junction that is no longer desired" {
        newSource $repoA '.claude\skills' 'alpha' | Out-Null
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver `
            -RepoSkills @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('alpha') })
        Join-Path $skillsDir 'alpha' | Should -Exist

        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver -RepoSkills @()
        Join-Path $skillsDir 'alpha' | Should -Not -Exist
    }

    It "removes a dangling junction whose source disappeared (self-heal)" {
        $src = newSource $repoA '.claude\skills' 'alpha'
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver `
            -RepoSkills @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('alpha') })

        Remove-Item -LiteralPath $src -Recurse -Force   # e.g. branch switch removes the source
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver `
            -RepoSkills @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('alpha') })

        Join-Path $skillsDir 'alpha' | Should -Not -Exist
    }

    It "re-points a junction when the target changes" {
        newSource $repoA '.claude\skills' 'gamma' | Out-Null
        $srcB = newSource $repoB '.claude\skills' 'gamma'
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver `
            -RepoSkills @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('gamma') })

        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver `
            -RepoSkills @(@{ repo = 'repoB'; from = '.claude\skills'; skills = @('gamma') })

        linkTarget (Join-Path $skillsDir 'gamma') | Should -Be ([System.IO.Path]::GetFullPath($srcB).TrimEnd('\'))
    }

    It "leaves an already-correct junction in place (idempotent)" {
        newSource $repoA '.claude\skills' 'alpha' | Out-Null
        $entries = @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('alpha') })
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver -RepoSkills $entries
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver -RepoSkills $entries

        linkType (Join-Path $skillsDir 'alpha') | Should -Be 'Junction'
        Join-Path $skillsDir 'alpha' 'SKILL.md' | Should -Exist
    }

    It "leaves a deploy-copied (non-junction) dir untouched and warns on name collision" {
        # A layer skill copied by Install-AgentRoles: a real dir, not a junction.
        $copied = Join-Path $skillsDir 'dup'
        New-Item -ItemType Directory -Path $copied -Force | Out-Null
        "layer copy" | Out-File (Join-Path $copied 'SKILL.md') -Encoding utf8NoBOM
        newSource $repoA '.claude\skills' 'dup' | Out-Null

        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver -WarningVariable w `
            -RepoSkills @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('dup') })

        linkType $copied | Should -BeNullOrEmpty                 # still a regular dir, not a junction
        Get-Content (Join-Path $copied 'SKILL.md') | Should -Be 'layer copy'
        "$w" | Should -BeLike '*non-junction*'
    }

    It "does not delete the target's contents when removing a junction" {
        $src = newSource $repoA '.claude\skills' 'alpha'
        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver `
            -RepoSkills @(@{ repo = 'repoA'; from = '.claude\skills'; skills = @('alpha') })

        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver -RepoSkills @()

        Join-Path $src 'SKILL.md' | Should -Exist
    }

    It "keeps the first source and warns when a skill is declared by two sources" {
        $srcA = newSource $repoA '.claude\skills' 'omega'
        newSource $repoB '.claude\skills' 'omega' | Out-Null

        Sync-RepoSkillJunctions -SkillsDir $skillsDir -ResolveRepoRoot $resolver -WarningVariable w -RepoSkills @(
            @{ repo = 'repoA'; from = '.claude\skills'; skills = @('omega') }
            @{ repo = 'repoB'; from = '.claude\skills'; skills = @('omega') }
        )

        linkTarget (Join-Path $skillsDir 'omega') | Should -Be ([System.IO.Path]::GetFullPath($srcA).TrimEnd('\'))
        "$w" | Should -BeLike '*more than one*'
    }
}
