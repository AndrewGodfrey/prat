BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $PSScriptRoot\instSyncFolders.ps1
    . $PSScriptRoot\instFilesAndFolders.ps1

    Import-Module "$PSScriptRoot\..\TextFileEditor\TextFileEditor.psd1"

    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
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
