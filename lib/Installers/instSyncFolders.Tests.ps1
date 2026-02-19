BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $PSScriptRoot\instFilesAndFolders.ps1

    Import-Module "$PSScriptRoot\..\TextFileEditor\TextFileEditor.psd1"

    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
    }
}

Describe "Install-SyncFolders" {
    BeforeEach {
        $script:testDir = (Resolve-Path "TestDrive:\").ProviderPath + "instSyncFolders.Tests"
        mkdir $testDir | Out-Null
        $script:appDir = "$testDir\.testapp"
        $script:syncRoot = "$testDir\sync"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Creates sync root and junctions when starting fresh" {
        mkdir $appDir | Out-Null

        Install-SyncFolders $stage ".testapp" $appDir $syncRoot @("data", "config") @()

        Test-Path $syncRoot -PathType Container | Should -BeTrue
        (Get-Item "$appDir\data").LinkType | Should -Be "Junction"
        (Get-Item "$appDir\config").LinkType | Should -Be "Junction"
    }

    It "Migrates existing data into sync folder" {
        mkdir $appDir | Out-Null
        mkdir "$appDir\data" | Out-Null
        "test content" | Out-File "$appDir\data\file.json"

        Install-SyncFolders $stage ".testapp" $appDir $syncRoot @("data") @()

        (Get-Item "$appDir\data").LinkType | Should -Be "Junction"
        Test-Path "$syncRoot\data\file.json" | Should -BeTrue
        Get-Content "$syncRoot\data\file.json" | Should -BeLike "*test content*"
    }

    It "Is idempotent on second run" {
        mkdir $appDir | Out-Null
        Install-SyncFolders $stage ".testapp" $appDir $syncRoot @("data") @()

        $stage2 = [MockStage]::new()
        Install-SyncFolders $stage2 ".testapp" $appDir $syncRoot @("data") @()

        $stage2.changeCount | Should -Be 0
    }

    It "Warns about unknown directories" {
        mkdir $appDir | Out-Null
        mkdir "$appDir\surprise" | Out-Null

        $warnings = Install-SyncFolders $stage ".testapp" $appDir $syncRoot @("data") @("local-stuff") 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -Not -BeNullOrEmpty
        ($warnings | Where-Object { $_.Message -match "surprise" }) | Should -Not -BeNullOrEmpty
        ($warnings | Where-Object { $_.Message -match "\.testapp" }) | Should -Not -BeNullOrEmpty
    }

    It "Does not warn about known local directories" {
        mkdir $appDir | Out-Null
        mkdir "$appDir\local-stuff" | Out-Null

        $warnings = Install-SyncFolders $stage ".testapp" $appDir $syncRoot @("data") @("local-stuff") 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -BeNullOrEmpty
    }

    It "Does not warn about files" {
        mkdir $appDir | Out-Null
        "data" | Out-File "$appDir\config.json"
        "data" | Out-File "$appDir\unknown.txt"

        $warnings = Install-SyncFolders $stage ".testapp" $appDir $syncRoot @("data") @() 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -BeNullOrEmpty
    }
}
