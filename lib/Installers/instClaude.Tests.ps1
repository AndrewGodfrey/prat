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

        Install-ClaudeSkillSet $stage @("my-skill") $srcDir $destDir

        "$destDir\my-skill\SKILL.md" | Should -Exist
    }

    It "does not deploy skills not in the set" {
        mkdir "$srcDir\wanted" | Out-Null
        "wanted" | Out-File "$srcDir\wanted\SKILL.md" -Encoding utf8NoBOM
        mkdir "$srcDir\unwanted" | Out-Null
        "unwanted" | Out-File "$srcDir\unwanted\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @("wanted") $srcDir $destDir

        "$destDir\wanted\SKILL.md"   | Should -Exist
        "$destDir\unwanted\SKILL.md" | Should -Not -Exist
    }

    It "prepends auto-generated header to SKILL.md" {
        mkdir "$srcDir\my-skill" | Out-Null
        "skill content" | Out-File "$srcDir\my-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @("my-skill") $srcDir $destDir

        Get-Content "$destDir\my-skill\SKILL.md" -Raw | Should -BeLike "<!-- Auto-generated*"
    }

    It "sets SKILL.md read-only" {
        mkdir "$srcDir\my-skill" | Out-Null
        "skill content" | Out-File "$srcDir\my-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @("my-skill") $srcDir $destDir

        (Get-ItemProperty "$destDir\my-skill\SKILL.md").IsReadOnly | Should -BeTrue
    }

    It "deploys multiple skills from the set" {
        mkdir "$srcDir\skill-a" | Out-Null
        "a" | Out-File "$srcDir\skill-a\SKILL.md" -Encoding utf8NoBOM
        mkdir "$srcDir\skill-b" | Out-Null
        "b" | Out-File "$srcDir\skill-b\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null  # pre-create so Install-Folder skips the mkdir+ACL path

        Install-ClaudeSkillSet $stage @("skill-a", "skill-b") $srcDir $destDir

        "$destDir\skill-a\SKILL.md" | Should -Exist
        "$destDir\skill-b\SKILL.md" | Should -Exist
    }

    It "creates the per-skill subdirectory when it does not exist" {
        mkdir "$srcDir\my-skill" | Out-Null
        "skill content" | Out-File "$srcDir\my-skill\SKILL.md" -Encoding utf8NoBOM
        # $destDir intentionally not pre-created

        Install-ClaudeSkillSet $stage @("my-skill") $srcDir $destDir

        "$destDir\my-skill" | Should -Exist
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

        foreach ($dir in @("projects", "tasks", "todos", "plans")) {
            (Get-Item "$claudeDir\$dir").LinkType | Should -Be "Junction"
        }
    }

    It "Does not warn about known local directories" {
        mkdir $claudeDir | Out-Null
        foreach ($dir in @("agents", "commands", "skills", "file-history", "cache", "debug", "paste-cache", "shell-snapshots", "plugins", "ide", "session-env", "statsig")) {
            mkdir "$claudeDir\$dir" | Out-Null
        }

        $warnings = Install-ClaudeSyncFolders $stage $syncRoot $claudeDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -BeNullOrEmpty
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
