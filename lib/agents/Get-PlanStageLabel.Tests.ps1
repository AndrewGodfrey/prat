BeforeDiscovery {
    . "$PSScriptRoot/PlanState.ps1"
}

BeforeAll {
    Import-Module "$PSScriptRoot/../PratBase/PratBase.psd1" -Force
    . "$PSScriptRoot/PlanState.ps1"
}

Describe "Get-PlanStageLabel" {
    It "maps ready-to-refine to refining" {
        Get-PlanStageLabel 'ready-to-refine' | Should -Be 'refining'
    }

    It "maps ready-for-refined-step-review to refining" {
        # Not a second kind of "reviewing" - the step is still in its refine phase, waiting to be
        # approved, so the label answers "what is happening" the same way ready-to-refine's does.
        Get-PlanStageLabel 'ready-for-refined-step-review' | Should -Be 'refining'
    }

    It "maps ready-to-implement to coding" {
        Get-PlanStageLabel 'ready-to-implement' | Should -Be 'coding'
    }

    It "maps ready-for-user-review to reviewing" {
        Get-PlanStageLabel 'ready-for-user-review' | Should -Be 'reviewing'
    }

    It "defaults null/unrecognized state to planning" {
        Get-PlanStageLabel $null | Should -Be 'planning'
        Get-PlanStageLabel 'made-up-state' | Should -Be 'planning'
    }
}
