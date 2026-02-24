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

Describe "Install-ClaudeSkills" {
    BeforeEach {
        $script:testDir = (Resolve-Path "TestDrive:\").ProviderPath + "instClaude.Tests"
        mkdir $testDir | Out-Null
        $script:srcDir = "$testDir\skills-src"
        $script:destDir = "$testDir\skills-dest"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "deploys each skill subdirectory to the destination" {
        mkdir "$srcDir\my-skill" | Out-Null
        "skill content" | Out-File "$srcDir\my-skill\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null  # pre-create so Install-Folder skips the mkdir+ACL path

        Install-ClaudeSkills $stage $srcDir $destDir

        "$destDir\my-skill\SKILL.md" | Should -Exist
    }

    It "deploys multiple skills" {
        mkdir "$srcDir\skill-a" | Out-Null
        "a" | Out-File "$srcDir\skill-a\SKILL.md" -Encoding utf8NoBOM
        mkdir "$srcDir\skill-b" | Out-Null
        "b" | Out-File "$srcDir\skill-b\SKILL.md" -Encoding utf8NoBOM
        mkdir $destDir | Out-Null  # pre-create so Install-Folder skips the mkdir+ACL path

        Install-ClaudeSkills $stage $srcDir $destDir

        "$destDir\skill-a\SKILL.md" | Should -Exist
        "$destDir\skill-b\SKILL.md" | Should -Exist
    }
}

Describe "Install-ClaudeSyncFolders" {
    BeforeEach {
        $script:testDir = (Resolve-Path "TestDrive:\").ProviderPath + "instClaude.Tests"
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
        foreach ($dir in @("file-history", "cache", "debug", "paste-cache", "shell-snapshots", "plugins", "ide", "session-env", "statsig")) {
            mkdir "$claudeDir\$dir" | Out-Null
        }

        $warnings = Install-ClaudeSyncFolders $stage $syncRoot $claudeDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -BeNullOrEmpty
    }
}
