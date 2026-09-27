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

Describe "Get-HarnessFragmentList" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "harnessFragments.Tests"
        mkdir $testDir | Out-Null
        $script:layerFragments = @(
            "$testDir\agent-user_prat.md",
            "$testDir\agent-user_prefs.md",
            "$testDir\agent-user_de.md"
        )
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "returns the layer fragments in the given order, with forward slashes" {
        $result = @(Get-HarnessFragmentList -Fragments $layerFragments -HarnessFragment "$testDir\harness.md")

        $result | Should -Be @(
            "$testDir/agent-user_prat.md"  -replace '\\', '/'
            "$testDir/agent-user_prefs.md" -replace '\\', '/'
            "$testDir/agent-user_de.md"    -replace '\\', '/'
        )
    }

    It "splices the harness fragment after the base fragment when it exists" {
        "harness-specific content" | Out-File "$testDir\harness.md"

        $result = @(Get-HarnessFragmentList -Fragments $layerFragments -HarnessFragment "$testDir\harness.md")

        $result.Count | Should -Be 4
        $result[0] | Should -BeLike "*/agent-user_prat.md"
        $result[1] | Should -BeLike "*/harness.md"
        $result[2] | Should -BeLike "*/agent-user_prefs.md"
    }

    It "handles a single-layer fragment list with a harness fragment" {
        "harness-specific content" | Out-File "$testDir\harness.md"

        $result = @(Get-HarnessFragmentList -Fragments @($layerFragments[0]) -HarnessFragment "$testDir\harness.md")

        $result.Count | Should -Be 2
        $result[1] | Should -BeLike "*/harness.md"
    }

    It "appends model fragments last, so they narrow everything before them" {
        $modelFragments = @("$testDir\agent-user-claude_prat.md", "$testDir\agent-user-claude_prefs.md")

        $result = @(Get-HarnessFragmentList -Fragments $layerFragments -ModelFragments $modelFragments)

        $result.Count | Should -Be 5
        $result[3] | Should -BeLike "*/agent-user-claude_prat.md"
        $result[4] | Should -BeLike "*/agent-user-claude_prefs.md"
    }

    It "omits the model fragments when none are supplied" {
        $result = @(Get-HarnessFragmentList -Fragments $layerFragments)

        $result.Count | Should -Be 3
    }
}
