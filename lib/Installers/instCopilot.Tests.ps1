BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $PSScriptRoot\instFilesAndFolders.ps1

    Import-Module "$PSScriptRoot\..\TextFileEditor\TextFileEditor.psd1"

    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
    }
}

Describe "Install-CopilotSyncFolders" {
    BeforeEach {
        $script:testDir = (Resolve-Path "TestDrive:\").ProviderPath + "instCopilot.Tests"
        mkdir $testDir | Out-Null
        $script:copilotDir = "$testDir\.copilot"
        $script:syncRoot = "$testDir\sync"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Creates sync root and junctions when starting fresh" {
        mkdir $copilotDir | Out-Null

        Install-CopilotSyncFolders $stage $syncRoot $copilotDir

        Test-Path $syncRoot -PathType Container | Should -BeTrue
        foreach ($dir in @("session-state")) {
            (Get-Item "$copilotDir\$dir").LinkType | Should -Be "Junction"
        }
    }

    It "Migrates existing data into sync folder" {
        mkdir $copilotDir | Out-Null
        mkdir "$copilotDir\session-state" | Out-Null
        "session data" | Out-File "$copilotDir\session-state\state.json"

        Install-CopilotSyncFolders $stage $syncRoot $copilotDir

        (Get-Item "$copilotDir\session-state").LinkType | Should -Be "Junction"
        Test-Path "$syncRoot\session-state\state.json" | Should -BeTrue
        Get-Content "$syncRoot\session-state\state.json" | Should -BeLike "*session data*"
    }

    It "Is idempotent on second run" {
        mkdir $copilotDir | Out-Null
        Install-CopilotSyncFolders $stage $syncRoot $copilotDir

        $stage2 = [MockStage]::new()
        Install-CopilotSyncFolders $stage2 $syncRoot $copilotDir

        $stage2.changeCount | Should -Be 0
    }

    It "Warns about unknown directories" {
        mkdir $copilotDir | Out-Null
        mkdir "$copilotDir\some-new-feature" | Out-Null

        $warnings = Install-CopilotSyncFolders $stage $syncRoot $copilotDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -Not -BeNullOrEmpty
        ($warnings | Where-Object { $_.Message -match "some-new-feature" }) | Should -Not -BeNullOrEmpty
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

    It "Does not warn about files" {
        mkdir $copilotDir | Out-Null
        "data" | Out-File "$copilotDir\config.json"
        "data" | Out-File "$copilotDir\unknown-file.json"

        $warnings = Install-CopilotSyncFolders $stage $syncRoot $copilotDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -BeNullOrEmpty
    }
}
