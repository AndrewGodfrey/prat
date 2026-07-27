BeforeDiscovery {
    . "$PSScriptRoot/PlanState.ps1"
}

BeforeAll {
    Import-Module "$PSScriptRoot/../PratBase/PratBase.psd1" -Force
    . "$PSScriptRoot/PlanState.ps1"
}

Describe "Get-PlanStageLabel" {
    It "maps ready-to-plan to planning" {
        Get-PlanStageLabel 'ready-to-plan' | Should -Be 'planning'
    }

    It "maps ready-to-implement to coding" {
        Get-PlanStageLabel 'ready-to-implement' | Should -Be 'coding'
    }

    It "maps ready-for-user-review to reviewing" {
        Get-PlanStageLabel 'ready-for-user-review' | Should -Be 'reviewing'
    }

    It "defaults checkpointed to planning (pl always resolves it before a session goes live)" {
        Get-PlanStageLabel 'checkpointed' | Should -Be 'planning'
    }

    It "defaults null/unrecognized state to planning" {
        Get-PlanStageLabel $null | Should -Be 'planning'
        Get-PlanStageLabel 'made-up-state' | Should -Be 'planning'
    }
}
