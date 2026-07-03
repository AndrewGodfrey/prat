BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $PSScriptRoot\instSyncFolders.ps1
    . $PSScriptRoot\instFilesAndFolders.ps1

    Import-Module "$PSScriptRoot\..\TextFileEditor\TextFileEditor.psd1"
    Import-Module "$PSScriptRoot\..\PratBase\PratBase.psd1"

    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
    }
}

Describe "Install-ClaudeSkillSet" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "instClaude.Tests"
        mkdir $testDir | Out-Null
        $script:srcDir = "$testDir\skills-src"
        $script:destDir = "$testDir\skills-dest"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "deploys a skill in the set" {
        mkdir "$srcDir\my-skill" | Out-Null
        "skill content" | Out-File "$srcDir\my-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null  # pre-create so Install-Folder skips the mkdir+ACL path

        Install-ClaudeSkillSet $stage @(@{ set = @("my-skill"); srcDir = $srcDir }) $destDir

        "$destDir\my-skill\SKILL.md" | Should -Exist
    }

    It "does not deploy skills not in the set" {
        mkdir "$srcDir\wanted" | Out-Null
        "wanted" | Out-File "$srcDir\wanted\SKILL.md" -Encoding utf8NoBOM
        mkdir "$srcDir\unwanted" | Out-Null
        "unwanted" | Out-File "$srcDir\unwanted\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @(@{ set = @("wanted"); srcDir = $srcDir }) $destDir

        "$destDir\wanted\SKILL.md"   | Should -Exist
        "$destDir\unwanted\SKILL.md" | Should -Not -Exist
    }

    It "prepends auto-generated header to SKILL.md" {
        mkdir "$srcDir\my-skill" | Out-Null
        "skill content" | Out-File "$srcDir\my-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @(@{ set = @("my-skill"); srcDir = $srcDir }) $destDir

        Get-Content "$destDir\my-skill\SKILL.md" -Raw | Should -BeLike "<!-- Auto-generated*"
    }

    It "places header after YAML frontmatter in SKILL.md" {
        mkdir "$srcDir\my-skill" | Out-Null
        $content = "---`nname: my-skill`ndescription: does things`n---`nbody content"
        [System.IO.File]::WriteAllText("$srcDir\my-skill\SKILL.md", $content, [System.Text.Encoding]::UTF8)
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @(@{ set = @("my-skill"); srcDir = $srcDir }) $destDir

        $deployed = Get-Content "$destDir\my-skill\SKILL.md" -Raw
        $deployed | Should -BeLike "---*"
        $deployed.IndexOf("---") | Should -BeLessThan ($deployed.IndexOf("<!-- Auto-generated"))
    }

    It "sets SKILL.md read-only" {
        mkdir "$srcDir\my-skill" | Out-Null
        "skill content" | Out-File "$srcDir\my-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @(@{ set = @("my-skill"); srcDir = $srcDir }) $destDir

        (Get-ItemProperty "$destDir\my-skill\SKILL.md").IsReadOnly | Should -BeTrue
    }

    It "deploys multiple skills from the set" {
        mkdir "$srcDir\skill-a" | Out-Null
        "a" | Out-File "$srcDir\skill-a\SKILL.md" -Encoding utf8NoBOM
        mkdir "$srcDir\skill-b" | Out-Null
        "b" | Out-File "$srcDir\skill-b\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null  # pre-create so Install-Folder skips the mkdir+ACL path

        Install-ClaudeSkillSet $stage @(@{ set = @("skill-a", "skill-b"); srcDir = $srcDir }) $destDir

        "$destDir\skill-a\SKILL.md" | Should -Exist
        "$destDir\skill-b\SKILL.md" | Should -Exist
    }

    It "creates the per-skill subdirectory when it does not exist" {
        mkdir "$srcDir\my-skill" | Out-Null
        "skill content" | Out-File "$srcDir\my-skill\SKILL.md" -Encoding utf8NoBOM
        # $destDir intentionally not pre-created

        Install-ClaudeSkillSet $stage @(@{ set = @("my-skill"); srcDir = $srcDir }) $destDir

        "$destDir\my-skill" | Should -Exist
    }

    It "removes a stale skill dir from dest when not in the set" {
        mkdir "$srcDir\current-skill" | Out-Null
        "current" | Out-File "$srcDir\current-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir "$destDir\stale-skill" | Out-Null
        "stale" | Out-File "$destDir\stale-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir -ErrorAction SilentlyContinue | Out-Null

        Install-ClaudeSkillSet $stage @(@{ set = @("current-skill"); srcDir = $srcDir }) $destDir

        "$destDir\stale-skill" | Should -Not -Exist
    }

    It "does not remove a deployed skill dir that is still in the set" {
        mkdir "$srcDir\my-skill" | Out-Null
        "content" | Out-File "$srcDir\my-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir -ErrorAction SilentlyContinue | Out-Null

        Install-ClaudeSkillSet $stage @(@{ set = @("my-skill"); srcDir = $srcDir }) $destDir

        "$destDir\my-skill" | Should -Exist
    }

    It "throws if a skill in the set does not exist in srcDir" {
        mkdir "$srcDir\real-skill" | Out-Null
        "content" | Out-File "$srcDir\real-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        { Install-ClaudeSkillSet $stage @(@{ set = @("real-skill", "missing-skill"); srcDir = $srcDir }) $destDir } | Should -Throw
    }

    It "deploys skills from multiple source directories" {
        $srcDir2 = "$testDir\skills-src2"
        mkdir "$srcDir\skill-a" | Out-Null
        "a" | Out-File "$srcDir\skill-a\SKILL.md" -Encoding utf8NoBOM
        mkdir "$srcDir2\skill-b" | Out-Null
        "b" | Out-File "$srcDir2\skill-b\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @(
            @{ set = @("skill-a"); srcDir = $srcDir }
            @{ set = @("skill-b"); srcDir = $srcDir2 }
        ) $destDir

        "$destDir\skill-a\SKILL.md" | Should -Exist
        "$destDir\skill-b\SKILL.md" | Should -Exist
    }

    It "cleanup with multiple sources removes skills not in any set" {
        $srcDir2 = "$testDir\skills-src2"
        mkdir "$srcDir\skill-a" | Out-Null
        "a" | Out-File "$srcDir\skill-a\SKILL.md" -Encoding utf8NoBOM
        mkdir "$srcDir2\skill-b" | Out-Null
        "b" | Out-File "$srcDir2\skill-b\SKILL.md" -Encoding utf8NoBOM
        mkdir "$destDir\stale-skill" | Out-Null
        "stale" | Out-File "$destDir\stale-skill\SKILL.md" -Encoding utf8NoBOM

        Install-ClaudeSkillSet $stage @(
            @{ set = @("skill-a"); srcDir = $srcDir }
            @{ set = @("skill-b"); srcDir = $srcDir2 }
        ) $destDir

        "$destDir\stale-skill" | Should -Not -Exist
    }

    It "cleanup with multiple sources preserves skills from all sources" {
        $srcDir2 = "$testDir\skills-src2"
        mkdir "$srcDir\skill-a" | Out-Null
        "a" | Out-File "$srcDir\skill-a\SKILL.md" -Encoding utf8NoBOM
        mkdir "$srcDir2\skill-b" | Out-Null
        "b" | Out-File "$srcDir2\skill-b\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @(
            @{ set = @("skill-a"); srcDir = $srcDir }
            @{ set = @("skill-b"); srcDir = $srcDir2 }
        ) $destDir

        "$destDir\skill-a\SKILL.md" | Should -Exist
        "$destDir\skill-b\SKILL.md" | Should -Exist
    }

    It "throws if a skill in any source set does not exist" {
        $srcDir2 = "$testDir\skills-src2"
        mkdir "$srcDir\skill-a" | Out-Null
        "a" | Out-File "$srcDir\skill-a\SKILL.md" -Encoding utf8NoBOM
        mkdir $srcDir2 | Out-Null
        mkdir $destDir | Out-Null

        { Install-ClaudeSkillSet $stage @(
            @{ set = @("skill-a"); srcDir = $srcDir }
            @{ set = @("missing"); srcDir = $srcDir2 }
        ) $destDir } | Should -Throw
    }

    It "uses # comment header for .ps1 files" {
        mkdir "$srcDir\my-skill" | Out-Null
        "Get-Item ." | Out-File "$srcDir\my-skill\Helper.ps1" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @(@{ set = @("my-skill"); srcDir = $srcDir }) $destDir

        $deployed = Get-Content "$destDir\my-skill\Helper.ps1" -Raw
        $deployed | Should -BeLike "# Auto-generated*"
        $deployed | Should -Not -Match "<!--"
    }

    It "skips *.Tests.ps1 files" {
        mkdir "$srcDir\my-skill" | Out-Null
        "Get-Item ." | Out-File "$srcDir\my-skill\Helper.ps1" -Encoding utf8NoBOM
        "Describe 'foo' {}" | Out-File "$srcDir\my-skill\Helper.Tests.ps1" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @(@{ set = @("my-skill"); srcDir = $srcDir }) $destDir

        "$destDir\my-skill\Helper.ps1"       | Should -Exist
        "$destDir\my-skill\Helper.Tests.ps1" | Should -Not -Exist
    }
}

Describe "Install-ClaudeMarkdownFiles" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "instClaude.Tests"
        mkdir $testDir | Out-Null
        $script:srcDir = "$testDir\md-src"
        $script:destDir = "$testDir\md-dest"
        $script:stage = [MockStage]::new()
        mkdir $srcDir | Out-Null
        mkdir $destDir | Out-Null
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "deploys .md files to the destination" {
        "body content" | Out-File "$srcDir\agent.md" -Encoding utf8NoBOM

        Install-ClaudeMarkdownFiles $stage $srcDir $destDir

        "$destDir\agent.md" | Should -Exist
    }

    It "ignores subdirectories in the source" {
        "body content" | Out-File "$srcDir\agent.md" -Encoding utf8NoBOM
        mkdir "$srcDir\subdir" | Out-Null

        { Install-ClaudeMarkdownFiles $stage $srcDir $destDir } | Should -Not -Throw
        "$destDir\subdir" | Should -Not -Exist
    }

    It "sets file read-only" {
        "body content" | Out-File "$srcDir\agent.md" -Encoding utf8NoBOM

        Install-ClaudeMarkdownFiles $stage $srcDir $destDir

        (Get-ItemProperty "$destDir\agent.md").IsReadOnly | Should -BeTrue
    }

    It "prepends header when no frontmatter" {
        "body content" | Out-File "$srcDir\agent.md" -Encoding utf8NoBOM

        Install-ClaudeMarkdownFiles $stage $srcDir $destDir

        Get-Content "$destDir\agent.md" -Raw | Should -BeLike "<!-- Auto-generated*"
    }

    It "places header after YAML frontmatter so frontmatter remains first" {
        $content = "---`nname: my-agent`ndescription: does things`n---`nbody content"
        [System.IO.File]::WriteAllText("$srcDir\agent.md", $content, [System.Text.Encoding]::UTF8)

        Install-ClaudeMarkdownFiles $stage $srcDir $destDir

        $deployed = Get-Content "$destDir\agent.md" -Raw
        $deployed | Should -BeLike "---*"
        $deployed | Should -BeLike "*<!-- Auto-generated*"
        $deployed.IndexOf("---") | Should -BeLessThan ($deployed.IndexOf("<!-- Auto-generated"))
    }

    It "with -Cleanup, removes a deployed file when its source no longer exists" {
        "new content" | Out-File "$srcDir\agent.md" -Encoding utf8NoBOM
        "stale content" | Out-File "$destDir\old-agent.md" -Encoding utf8NoBOM

        Install-ClaudeMarkdownFiles $stage $srcDir $destDir -Cleanup

        "$destDir\old-agent.md" | Should -Not -Exist
    }

    It "without -Cleanup, retains a deployed file even when its source no longer exists" {
        "new content" | Out-File "$srcDir\agent.md" -Encoding utf8NoBOM
        "stale content" | Out-File "$destDir\old-agent.md" -Encoding utf8NoBOM

        Install-ClaudeMarkdownFiles $stage $srcDir $destDir

        "$destDir\old-agent.md" | Should -Exist
    }
}

Describe "Install-ClaudeSyncFolders" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "instClaude.Tests"
        mkdir $testDir | Out-Null
        $script:claudeDir = "$testDir\.claude"
        $script:syncRoot = "$testDir\sync"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Syncs the expected directories" {
        mkdir $claudeDir | Out-Null

        Install-ClaudeSyncFolders $stage $syncRoot $claudeDir

        foreach ($dir in @("plans")) {
            (Get-Item "$claudeDir\$dir").LinkType | Should -Be "Junction"
        }
    }

    It "Does not junction the projects, tasks, or todos directories" {
        mkdir $claudeDir | Out-Null

        Install-ClaudeSyncFolders $stage $syncRoot $claudeDir

        foreach ($dir in @("projects", "tasks", "todos")) {
            (Get-Item "$claudeDir\$dir" -ErrorAction SilentlyContinue).LinkType | Should -BeNullOrEmpty -Because "$dir should be local"
        }
    }
}

Describe "Install-ClaudeProjectMemory" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "instClaude.Tests"
        mkdir $testDir | Out-Null
        $script:claudeDir = "$testDir\.claude"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "does nothing if the projects dir does not exist" {
        mkdir $claudeDir | Out-Null

        { Install-ClaudeProjectMemory $stage $claudeDir } | Should -Not -Throw
    }

    It "creates MEMORY.md in each project's memory subdir" {
        mkdir "$claudeDir\projects\my-project" | Out-Null

        Install-ClaudeProjectMemory $stage $claudeDir

        "$claudeDir\projects\my-project\memory\MEMORY.md" | Should -Exist
    }

    It "MEMORY.md starts with the auto-generated header" {
        mkdir "$claudeDir\projects\my-project" | Out-Null

        Install-ClaudeProjectMemory $stage $claudeDir

        Get-Content "$claudeDir\projects\my-project\memory\MEMORY.md" -Raw |
            Should -BeLike "<!-- Auto-generated by Prat deployment*"
    }

    It "sets MEMORY.md read-only" {
        mkdir "$claudeDir\projects\my-project" | Out-Null

        Install-ClaudeProjectMemory $stage $claudeDir

        (Get-ItemProperty "$claudeDir\projects\my-project\memory\MEMORY.md").IsReadOnly | Should -BeTrue
    }

    It "handles multiple project dirs" {
        mkdir "$claudeDir\projects\project-a" | Out-Null
        mkdir "$claudeDir\projects\project-b" | Out-Null

        Install-ClaudeProjectMemory $stage $claudeDir

        "$claudeDir\projects\project-a\memory\MEMORY.md" | Should -Exist
        "$claudeDir\projects\project-b\memory\MEMORY.md" | Should -Exist
    }

    It "overwrites an existing generated MEMORY.md" {
        $memoryDir = "$claudeDir\projects\my-project\memory"
        mkdir $memoryDir | Out-Null
        $header = "<!-- Auto-generated by Prat deployment. Do not edit — see source. -->"
        Set-Content "$memoryDir\MEMORY.md" "$header`n`nold content" -Encoding utf8NoBOM

        Install-ClaudeProjectMemory $stage $claudeDir

        Get-Content "$memoryDir\MEMORY.md" -Raw | Should -Not -BeLike "*old content*"
    }

    It "warns and skips a non-generated MEMORY.md" {
        $memoryDir = "$claudeDir\projects\my-project\memory"
        mkdir $memoryDir | Out-Null
        Set-Content "$memoryDir\MEMORY.md" "custom content" -Encoding utf8NoBOM

        $warnings = Install-ClaudeProjectMemory $stage $claudeDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -Not -BeNullOrEmpty
        Get-Content "$memoryDir\MEMORY.md" -Raw | Should -BeLike "*custom content*"
    }
}

Describe "Install-ClaudeAgentSandbox" {
    BeforeAll {
        $script:lasCapture = [PSCustomObject]@{ callCount = 0; rwPaths = $null }
        function global:Install-LocalAgentSandbox {
            param($stage, $agentUser, $rwPaths, $roPaths, $safeDirectories, $homeJunctions, $profileContent, $sshPublicKeyPath)
            $script:lasCapture.callCount++
            $script:lasCapture.rwPaths = $rwPaths
        }
        function global:Invoke-Gsudo([scriptblock]$sb) { }
    }

    BeforeEach {
        $script:lasCapture.callCount = 0
        $script:lasCapture.rwPaths = $null

        $script:stage = [PSCustomObject]@{}
        $script:stage | Add-Member -MemberType NoteProperty -Name migrationDates `
            -Value ([System.Collections.Generic.List[datetime]]::new())
        $script:stage | Add-Member ScriptMethod OnChange { }
        $script:stage | Add-Member ScriptMethod GetIsStepComplete { return $false }
        $script:stage | Add-Member ScriptMethod SetStepComplete { param($k) }
        $script:stage | Add-Member ScriptMethod NoteMigrationStep {
            param([datetime]$date) $this.migrationDates.Add($date)
        }
    }

    It "calls Install-LocalAgentSandbox" {
        Install-ClaudeAgentSandbox $script:stage -agentUser 'test_agent' -claudeHome 'C:\dummy\home'
        $script:lasCapture.callCount | Should -Be 1
    }

    It "registers migration steps for removed CC-specific items" {
        Install-ClaudeAgentSandbox $script:stage -agentUser 'test_agent' -claudeHome 'C:\dummy\home'
        $script:stage.migrationDates.Count | Should -BeGreaterOrEqual 4
    }
}

Describe "Install-ClaudeUserSettings" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "instClaude-settings.Tests"
        mkdir $testDir | Out-Null
        $script:claudeDir = "$testDir\.claude"
        mkdir $claudeDir | Out-Null
        $script:stage = [MockStage]::new()

        $script:settingsScript = "$testDir\Get-ClaudeUserSettings.ps1"
        '@{ theme = "dark" }' | Out-File $settingsScript -Encoding utf8NoBOM

        Mock Resolve-PratLibFile { return @($script:settingsScript) }
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "creates settings.json" {
        Install-ClaudeUserSettings $stage $claudeDir

        "$claudeDir\settings.json" | Should -Exist
    }

    It "does not set settings.json read-only" {
        Install-ClaudeUserSettings $stage $claudeDir

        (Get-ItemProperty "$claudeDir\settings.json").IsReadOnly | Should -BeFalse
    }
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

Describe "Install-AgentRoles" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "instAgentRoles.Tests"
        mkdir $testDir | Out-Null
        $script:pratSrc  = "$testDir\src-prat"
        $script:prefsSrc = "$testDir\src-prefs"
        $script:destParent = "$testDir\agentRoles"
        $script:stage = [MockStage]::new()

        # Helper to drop a skill source dir under a source root.
        function newSkill($srcRoot, $name) {
            $d = "$srcRoot\$name"
            mkdir $d -Force | Out-Null
            "content" | Out-File "$d\SKILL.md" -Encoding utf8NoBOM
        }
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "deploys a role's skills to destParent/<role>/.claude/skills" {
        newSkill $pratSrc 'git'
        newSkill $pratSrc 'test'

        Install-AgentRoles $stage @{ default = @{ skills = @('git', 'test') } } $destParent -skillSources @($pratSrc)

        "$destParent\default\.claude\skills\git\SKILL.md"  | Should -Exist
        "$destParent\default\.claude\skills\test\SKILL.md" | Should -Exist
    }

    It "groups skills by the source dir that provides them" {
        newSkill $pratSrc 'git'
        newSkill $prefsSrc 'kql'

        Install-AgentRoles $stage @{ default = @{ skills = @('git', 'kql') } } $destParent -skillSources @($pratSrc, $prefsSrc)

        "$destParent\default\.claude\skills\git\SKILL.md" | Should -Exist
        "$destParent\default\.claude\skills\kql\SKILL.md" | Should -Exist
    }

    It "throws when a role names a skill with no source dir" {
        newSkill $pratSrc 'git'

        { Install-AgentRoles $stage @{ default = @{ skills = @('git', 'ghost') } } $destParent -skillSources @($pratSrc) } |
            Should -Throw "*no source dir: ghost*"
    }

    It "removes a stale role dir not in the role set" {
        newSkill $pratSrc 'git'
        mkdir "$destParent\obsolete" -Force | Out-Null
        "stale" | Out-File "$destParent\obsolete\marker.txt" -Encoding utf8NoBOM

        Install-AgentRoles $stage @{ default = @{ skills = @('git') } } $destParent -skillSources @($pratSrc)

        "$destParent\default"  | Should -Exist
        "$destParent\obsolete" | Should -Not -Exist
    }

    It "deploys multiple roles" {
        newSkill $pratSrc 'git'
        newSkill $pratSrc 'cmake'

        Install-AgentRoles $stage @{
            default  = @{ skills = @('git', 'cmake') }
            llamacpp = @{ skills = @('git') }
        } $destParent -skillSources @($pratSrc)

        "$destParent\default\.claude\skills\cmake\SKILL.md"  | Should -Exist
        "$destParent\llamacpp\.claude\skills\git\SKILL.md"   | Should -Exist
        "$destParent\llamacpp\.claude\skills\cmake"          | Should -Not -Exist
    }
}
