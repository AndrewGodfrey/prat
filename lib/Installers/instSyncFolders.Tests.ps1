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
        # Junctions require absolute filesystem paths
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "instSyncFolders.Tests"
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
}
