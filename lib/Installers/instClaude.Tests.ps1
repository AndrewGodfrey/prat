BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $PSScriptRoot\instFilesAndFolders.ps1

    # Import-TextFile is used by Install-TextToFile
    Import-Module "$PSScriptRoot\..\TextFileEditor\TextFileEditor.psd1"

    # Mock for InstallationStage
    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
    }
}

Describe "Install-ClaudeSyncFolders" {
    BeforeEach {
        # Junctions require absolute filesystem paths
        $script:testDir = (Resolve-Path "TestDrive:\").ProviderPath + "instClaude.Tests"
        mkdir $testDir | Out-Null
        $script:claudeDir = "$testDir\.claude"
        $script:syncRoot = "$testDir\sync"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Creates sync root and junctions when starting fresh" {
        mkdir $claudeDir | Out-Null

        Install-ClaudeSyncFolders $stage $syncRoot $claudeDir

        Test-Path $syncRoot -PathType Container | Should -BeTrue
        foreach ($dir in @("projects", "tasks", "todos", "plans")) {
            (Get-Item "$claudeDir\$dir").LinkType | Should -Be "Junction"
        }
    }

    It "Migrates existing data into sync folder" {
        mkdir $claudeDir | Out-Null
        mkdir "$claudeDir\projects" | Out-Null
        "conversation data" | Out-File "$claudeDir\projects\abc123.jsonl"

        Install-ClaudeSyncFolders $stage $syncRoot $claudeDir

        (Get-Item "$claudeDir\projects").LinkType | Should -Be "Junction"
        Test-Path "$syncRoot\projects\abc123.jsonl" | Should -BeTrue
        Get-Content "$syncRoot\projects\abc123.jsonl" | Should -BeLike "*conversation data*"
    }

    It "Is idempotent on second run" {
        mkdir $claudeDir | Out-Null
        Install-ClaudeSyncFolders $stage $syncRoot $claudeDir

        $stage2 = [MockStage]::new()
        Install-ClaudeSyncFolders $stage2 $syncRoot $claudeDir

        $stage2.changeCount | Should -Be 0
    }

    It "Warns about unknown directories" {
        mkdir $claudeDir | Out-Null
        mkdir "$claudeDir\some-new-feature" | Out-Null

        $warnings = Install-ClaudeSyncFolders $stage $syncRoot $claudeDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -Not -BeNullOrEmpty
        ($warnings | Where-Object { $_.Message -match "some-new-feature" }) | Should -Not -BeNullOrEmpty
    }

    It "Warns about unknown files" {
        mkdir $claudeDir | Out-Null
        "data" | Out-File "$claudeDir\new-feature.json"

        $warnings = Install-ClaudeSyncFolders $stage $syncRoot $claudeDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -Not -BeNullOrEmpty
        ($warnings | Where-Object { $_.Message -match "new-feature.json" }) | Should -Not -BeNullOrEmpty
    }

    It "Does not warn about known local directories" {
        mkdir $claudeDir | Out-Null
        foreach ($dir in @("cache", "debug", "paste-cache", "shell-snapshots", "plugins")) {
            mkdir "$claudeDir\$dir" | Out-Null
        }

        $warnings = Install-ClaudeSyncFolders $stage $syncRoot $claudeDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -BeNullOrEmpty
    }

    It "Does not warn about known local files" {
        mkdir $claudeDir | Out-Null
        foreach ($file in @(".credentials.json", "CLAUDE.md", "settings.json", "stats-cache.json", "history.jsonl")) {
            "data" | Out-File "$claudeDir\$file"
        }

        $warnings = Install-ClaudeSyncFolders $stage $syncRoot $claudeDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -BeNullOrEmpty
    }

    It "Warns about settings.local.json" {
        mkdir $claudeDir | Out-Null
        "data" | Out-File "$claudeDir\settings.local.json"

        $warnings = Install-ClaudeSyncFolders $stage $syncRoot $claudeDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        ($warnings | Where-Object { $_.Message -match "settings.local.json" }) | Should -Not -BeNullOrEmpty
    }
}
