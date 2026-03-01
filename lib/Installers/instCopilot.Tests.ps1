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

Describe "Install-CopilotSyncFolders" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "instCopilot.Tests"
        mkdir $testDir | Out-Null
        $script:copilotDir = "$testDir\.copilot"
        $script:syncRoot = "$testDir\sync"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Syncs the expected directories" {
        mkdir $copilotDir | Out-Null

        Install-CopilotSyncFolders $stage $syncRoot $copilotDir

        (Get-Item "$copilotDir\session-state").LinkType | Should -Be "Junction"
    }

    It "Does not warn about known local directories" {
        mkdir $copilotDir | Out-Null
        foreach ($dir in @("ide", "marketplace-cache", "pkg")) {
            mkdir "$copilotDir\$dir" | Out-Null
        }

        $warnings = Install-CopilotSyncFolders $stage $syncRoot $copilotDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -BeNullOrEmpty
    }
}
