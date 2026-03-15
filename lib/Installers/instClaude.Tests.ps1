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

    It "places header after YAML frontmatter in SKILL.md" {
        mkdir "$srcDir\my-skill" | Out-Null
        $content = "---`nname: my-skill`ndescription: does things`n---`nbody content"
        [System.IO.File]::WriteAllText("$srcDir\my-skill\SKILL.md", $content, [System.Text.Encoding]::UTF8)
        mkdir $destDir | Out-Null

        Install-ClaudeSkillSet $stage @("my-skill") $srcDir $destDir

        $deployed = Get-Content "$destDir\my-skill\SKILL.md" -Raw
        $deployed | Should -BeLike "---*"
        $deployed.IndexOf("---") | Should -BeLessThan ($deployed.IndexOf("<!-- Auto-generated"))
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

Describe "Merge-DeepHashtable" {
    It "returns overlay scalar when both layers have the same key" {
        $result = Merge-DeepHashtable @{a = "base"} @{a = "overlay"}

        $result.a | Should -Be "overlay"
    }

    It "keeps base key when overlay does not have it" {
        $result = Merge-DeepHashtable @{a = "base"} @{}

        $result.a | Should -Be "base"
    }

    It "adds overlay key when base does not have it" {
        $result = Merge-DeepHashtable @{} @{b = "overlay"}

        $result.b | Should -Be "overlay"
    }

    It "concatenates arrays" {
        $result = Merge-DeepHashtable @{a = @("x")} @{a = @("y")}

        $result.a | Should -Be @("x", "y")
    }

    It "recurses into nested hashtables" {
        $result = Merge-DeepHashtable @{p = @{a = "base-a"; b = "base-b"}} @{p = @{b = "over-b"; c = "over-c"}}

        $result.p.a | Should -Be "base-a"
        $result.p.b | Should -Be "over-b"
        $result.p.c | Should -Be "over-c"
    }

    It "does not mutate the input hashtables" {
        $base    = @{a = "base"}
        $overlay = @{b = "overlay"}

        Merge-DeepHashtable $base $overlay | Out-Null

        $base.Keys    | Should -Not -Contain "b"
        $overlay.Keys | Should -Not -Contain "a"
    }

    It "throws when one value is a hashtable and the other is an array" {
        { Merge-DeepHashtable @{a = @{}} @{a = @()} } | Should -Throw
    }

    It "returns keys in sorted order" {
        $result = Merge-DeepHashtable @{b = 1; a = 2} @{c = 3}

        ($result.Keys | Select-Object -First 3) | Should -Be @("a", "b", "c")
    }

    It "preserves single-element arrays as arrays across sequential merges" {
        # The first layer has a single-element array; the second has two elements.
        # Without the fix, ConvertTo-DeepOrdered unboxes the single-element array to a scalar,
        # causing a type mismatch on the second merge.
        $layer1 = @{items = @("single")}
        $layer2 = @{items = @("a", "b")}

        $result = Merge-DeepHashtable (Merge-DeepHashtable @{} $layer1) $layer2

        $result.items | Should -Be @("single", "a", "b")
    }

    It "sorts keys in nested hashtables contributed by only one layer" {
        $inner = [ordered]@{}; $inner['z'] = 0; $inner['a'] = 1  # z before a — out of sorted order
        $result = Merge-DeepHashtable @{} @{outer = $inner}

        ($result.outer.Keys | Select-Object -First 1) | Should -Be "a"
    }

    It "correctly merges three layers with nested hashtables" {
        $layer1 = @{permissions = @{allow = @("a")}}
        $layer2 = @{permissions = @{allow = @("b")}}
        $layer3 = @{permissions = @{allow = @("c")}}

        $merged = Merge-DeepHashtable (Merge-DeepHashtable $layer1 $layer2) $layer3

        $merged.permissions.allow | Should -Be @("a", "b", "c")
    }
}
