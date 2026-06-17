Describe "Get-ClaudeUserSettings_prat" {
    It "includes Stop hook mapped from TurnCompleted" {
        $result = & "$PSScriptRoot\Get-ClaudeUserSettings_prat.ps1"
        $result.hooks.Stop | Should -Not -BeNullOrEmpty
    }

    It "includes StopFailure hook mapped from TurnCompleted" {
        $result = & "$PSScriptRoot\Get-ClaudeUserSettings_prat.ps1"
        $result.hooks.StopFailure | Should -Not -BeNullOrEmpty
    }

    It "includes UserPromptSubmit hook mapped from PromptSubmitted" {
        $result = & "$PSScriptRoot\Get-ClaudeUserSettings_prat.ps1"
        $result.hooks.UserPromptSubmit | Should -Not -BeNullOrEmpty
    }

    It "Stop hook command references On-AgentTurnCompleted.ps1" {
        $result = & "$PSScriptRoot\Get-ClaudeUserSettings_prat.ps1"
        $result.hooks.Stop[0].hooks[0].command | Should -BeLike "*On-AgentTurnCompleted.ps1*"
    }

    It "UserPromptSubmit hook command references On-UserPromptSubmit.ps1" {
        $result = & "$PSScriptRoot\Get-ClaudeUserSettings_prat.ps1"
        $result.hooks.UserPromptSubmit[0].hooks[0].command | Should -BeLike "*On-UserPromptSubmit.ps1*"
    }
}
