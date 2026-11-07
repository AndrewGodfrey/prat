BeforeAll {
    . "$PSScriptRoot/instScheduledTasks.ps1"

    class MockStage {
        [int] $changeCount = 0
        [hashtable] $completeSteps = @{}
        [void] OnChange() { $this.changeCount++ }
        [bool] GetIsStepComplete($stepId) { return $this.completeSteps.ContainsKey($stepId) }
        [void] ClearManualStep($stepId) { $this.OnChange(); $this.completeSteps.Remove($stepId) }
        [void] SetStepComplete($stepId) { $this.completeSteps[$stepId] = $true }
    }
}

Describe "Install-DailyScheduledTask / Install-AtLogonScheduledTask" {
    BeforeEach {
        $script:stage = [MockStage]::new()
        $script:scriptFile = (New-Item "TestDrive:\task_$(New-Guid).ps1" -Value '' -Force).FullName
        $script:registered = @{}
        # Register-ScheduledTask's parameters are typed CimInstance; -ClientOnly makes one without a CIM server.
        Mock New-ScheduledTaskTrigger { New-CimInstance -ClientOnly -ClassName 'MSFT_TaskTrigger' -Property @{ Delay = '' } }
        Mock New-ScheduledTaskAction { New-CimInstance -ClientOnly -ClassName 'MSFT_TaskAction' -Property @{ Arguments = $Argument } }
        Mock Register-ScheduledTask { $script:registered[$TaskName] = $Trigger }
        Mock Get-ScheduledTask { if ($script:registered[$TaskName[0]]) { [pscustomobject] @{ TaskName = $TaskName[0] } } }
    }

    It "registers a daily task running the script, and marks its step complete" {
        Install-DailyScheduledTask $stage 'myTask' 'My task' $scriptFile '1:30AM'

        Should -Invoke Register-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskName -eq 'My task' }
        Should -Invoke New-ScheduledTaskAction -Times 1 -Exactly -ParameterFilter { $Argument -like "*$scriptFile*" }
        Should -Invoke New-ScheduledTaskTrigger -Times 1 -Exactly -ParameterFilter { $Daily -and ($At -eq '1:30AM') }
        $stage.GetIsStepComplete('schTasks\myTask') | Should -BeTrue
        $stage.changeCount | Should -Be 1
    }

    It "does nothing once its step is complete" {
        $stage.completeSteps['schTasks\myTask'] = $true

        Install-DailyScheduledTask $stage 'myTask' 'My task' $scriptFile '1:30AM'

        Should -Invoke Register-ScheduledTask -Times 0
        $stage.changeCount | Should -Be 0
    }

    It "registers an at-logon task for the current user only, with a delay" {
        Install-AtLogonScheduledTask $stage 'myTask' 'My task' $scriptFile

        Should -Invoke New-ScheduledTaskTrigger -Times 1 -Exactly -ParameterFilter { $AtLogon -and ($User -eq $env:username) }
        $script:registered['My task'].Delay | Should -Be 'PT5S'
        $stage.GetIsStepComplete('schTasks\myTask') | Should -BeTrue
    }

    It "throws, and leaves its step incomplete, when registration silently fails" {
        Mock Register-ScheduledTask {}

        { Install-DailyScheduledTask $stage 'myTask' 'My task' $scriptFile '1:30AM' } | Should -Throw "*Failed to create scheduled task 'My task'*"
        $stage.GetIsStepComplete('schTasks\myTask') | Should -BeFalse
    }
}

Describe "Uninstall-ScheduledTask" {
    BeforeEach {
        $script:stage = [MockStage]::new()
        # TestDrive persists across this Describe's tests, so each test gets its own result dir.
        $script:resultDir = "TestDrive:\results_$(New-Guid)"
        $script:registered = @{}
        # Both cmdlets' -TaskName is a string[].
        Mock Get-ScheduledTask { if ($script:registered[$TaskName[0]]) { [pscustomobject] @{ TaskName = $TaskName[0] } } }
        Mock Unregister-ScheduledTask { $script:registered.Remove($TaskName[0]) }
    }

    It "unregisters the task, removes its result, and clears its install step" {
        $script:registered['My task'] = $true
        $stage.completeSteps['schTasks\myTask'] = $true
        Save-ScheduledTaskResult 'My task' Failure 'boom' -ResultDir $resultDir

        Uninstall-ScheduledTask $stage 'myTask' 'My task' -ResultDir $resultDir

        Should -Invoke Unregister-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskName -eq 'My task' }
        Test-Path "$resultDir\My task.json" | Should -BeFalse
        $stage.GetIsStepComplete('schTasks\myTask') | Should -BeFalse
        $stage.changeCount | Should -BeGreaterThan 0
    }

    It "is a no-op once the task is gone" {
        Uninstall-ScheduledTask $stage 'myTask' 'My task' -ResultDir $resultDir

        Should -Invoke Unregister-ScheduledTask -Times 0
        $stage.changeCount | Should -Be 0
    }

    It "throws if the task is still registered afterward" {
        $script:registered['My task'] = $true
        Mock Unregister-ScheduledTask {}

        { Uninstall-ScheduledTask $stage 'myTask' 'My task' -ResultDir $resultDir } | Should -Throw "*Failed to remove scheduled task 'My task'*"
    }
}
