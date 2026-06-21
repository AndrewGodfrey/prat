BeforeAll {
    $script:lastHarnessCalled = $null

    function Install-ClaudeHarness {
        param($stage, [string[]] $Suppress = @(), [string[]] $Enable = @(), [hashtable] $Config = @{})
        $script:lastHarnessCalled = 'claude'
    }
    function Install-CopilotHarness {
        param($stage)
        $script:lastHarnessCalled = 'copilot'
    }

    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $PSScriptRoot\instFilesAndFolders.ps1

    Import-Module "$PSScriptRoot\..\TextFileEditor\TextFileEditor.psd1"
    Import-Module "$PSScriptRoot\..\PratBase\PratBase.psd1"

    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
    }
}

Describe "Install-HarnessIntegration" {
    BeforeEach {
        $script:lastHarnessCalled = $null
    }

    It "dispatches 'claude' to Install-ClaudeHarness" {
        Install-HarnessIntegration ([MockStage]::new()) 'claude'
        $script:lastHarnessCalled | Should -Be 'claude'
    }

    It "dispatches 'copilot' to Install-CopilotHarness" {
        Install-HarnessIntegration ([MockStage]::new()) 'copilot'
        $script:lastHarnessCalled | Should -Be 'copilot'
    }

    It "throws for an unknown harness name" {
        { Install-HarnessIntegration ([MockStage]::new()) 'unknown-harness' } | Should -Throw
    }
}

Describe "Install-HarnessUserInstructions" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "instHarness.Tests"
        mkdir $testDir | Out-Null
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "prepends auto-generated header before fragment content" {
        "body content" | Out-File "$testDir\frag.md" -Encoding utf8NoBOM

        Install-HarnessUserInstructions $stage "$testDir\dest.md" @("$testDir\frag.md")

        $content = Get-Content "$testDir\dest.md" -Raw
        $content | Should -BeLike "<!-- Auto-generated*"
        $content.IndexOf("<!-- Auto-generated") | Should -BeLessThan ($content.IndexOf("body content"))
    }

    It "assembles multiple fragments in order" {
        "FIRST"  | Out-File "$testDir\frag1.md" -Encoding utf8NoBOM
        "SECOND" | Out-File "$testDir\frag2.md" -Encoding utf8NoBOM

        Install-HarnessUserInstructions $stage "$testDir\dest.md" @("$testDir\frag1.md", "$testDir\frag2.md")

        $content = Get-Content "$testDir\dest.md" -Raw
        $content.IndexOf("FIRST") | Should -BeLessThan ($content.IndexOf("SECOND"))
    }

    It "writes to the specified destination path" {
        "content" | Out-File "$testDir\frag.md" -Encoding utf8NoBOM

        Install-HarnessUserInstructions $stage "$testDir\custom-dest.md" @("$testDir\frag.md")

        "$testDir\custom-dest.md" | Should -Exist
    }

    It "sets the output file read-only" {
        "content" | Out-File "$testDir\frag.md" -Encoding utf8NoBOM

        Install-HarnessUserInstructions $stage "$testDir\dest.md" @("$testDir\frag.md")

        (Get-ItemProperty "$testDir\dest.md").IsReadOnly | Should -BeTrue
    }
}
