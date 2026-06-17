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
