BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    # Import-TextFile is used by Install-TextToFile
    Import-Module "$PSScriptRoot\..\TextFileEditor\TextFileEditor.psd1"

    # Mock for InstallationStage
    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
    }
}

Describe "Install-TextToFile" {
    BeforeEach {
        $testDir = "TestDrive:\instFilesAndFolders.Tests"
        mkdir $testDir | Out-Null
        $testFile = "$testDir\test.txt"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Creates a new file with SetReadOnly" {
        Install-TextToFile $stage $testFile "hello" -SetReadOnly

        Import-TextFile $testFile | Should -Be "hello"
        (Get-ItemProperty $testFile).IsReadOnly | Should -BeTrue
        $stage.changeCount | Should -Be 1
    }

    It "Is idempotent when content and read-only flag match" {
        "hello" | Out-File -Encoding ASCII $testFile
        Set-ItemProperty $testFile -Name IsReadOnly -Value $true

        Install-TextToFile $stage $testFile "hello" -SetReadOnly

        (Get-ItemProperty $testFile).IsReadOnly | Should -BeTrue
        $stage.changeCount | Should -Be 0
    }

    It "Updates content on a read-only file" {
        "old content" | Out-File -Encoding ASCII $testFile
        Set-ItemProperty $testFile -Name IsReadOnly -Value $true

        Install-TextToFile $stage $testFile "new content" -SetReadOnly

        Import-TextFile $testFile | Should -Be "new content"
        (Get-ItemProperty $testFile).IsReadOnly | Should -BeTrue
        $stage.changeCount | Should -Be 1
    }

    It "Sets read-only when content matches but flag is missing" {
        "hello" | Out-File -Encoding ASCII $testFile

        Install-TextToFile $stage $testFile "hello" -SetReadOnly

        (Get-ItemProperty $testFile).IsReadOnly | Should -BeTrue
        $stage.changeCount | Should -Be 1
    }

    It "Leaves file writable without SetReadOnly" {
        Install-TextToFile $stage $testFile "hello"

        Import-TextFile $testFile | Should -Be "hello"
        (Get-ItemProperty $testFile).IsReadOnly | Should -BeFalse
    }
}
