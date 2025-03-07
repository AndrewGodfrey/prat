
# Note: DisplayName is limited. e.g. spaces and dashes are allowed, but colons are not.
function Add-ScriptScheduledTask($displayName, $scriptFile, $trigger) {
    $ErrorActionPreference = "Stop"
    $scriptFile = Resolve-Path $scriptFile

    $action = New-ScheduledTaskAction -Execute $PSScriptRoot\Launch-PowershellSilently.vbs -Argument "C:\ `"$scriptFile`""
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $displayName -Force | Out-Null

    # Workaround:
    #   On error - at least on "Access Denied" - Register-ScheduledTask doesn't throw. And it doesn't support "-ErrorActionPreference".
    #   So... if it fails the first time, then it won't run again (because we'll think it completed, and it's slow to rerun / verify).
    #   So: Use Get-ScheduledTask to check the task now exists. It doesn't throw either, so...
    if ($null -eq (Get-ScheduledTask -TaskName $displayName)) {
        throw "Failed to create scheduled task '$displayName'."
    }
}

# Note: This only runs if the user is logged in at the time. It actually seems to run more often than I'd have thought for a laptop.
#       But, assume it is only effective during periods when you use the machine often.
function Install-DailyScheduledTask($stage, $taskId, $displayName, $scriptFile, $timeOfDay) {
    if (!($stage.GetIsStepComplete("schTasks\$taskId"))) {
        $stage.OnChange()

        $trigger = New-ScheduledTaskTrigger -At $timeOfDay -Daily
        Add-ScriptScheduledTask $displayName $scriptFile $trigger

        $stage.SetStepComplete("schTasks\$taskId")
    }
}

function Install-AtLogonScheduledTask($stage, $taskId, $displayName, $scriptFile) {
    if (!($stage.GetIsStepComplete("schTasks\$taskId"))) {
        $stage.OnChange()

        # IMPORTANT! If you don't specify a user, the default is "at log on of ANY user"!
        $trigger = New-ScheduledTaskTrigger -AtLogon -User $env:username
        $trigger.Delay = 'PT5S' # 5 seconds after login

        Add-ScriptScheduledTask $displayName $scriptFile $trigger
        $stage.SetStepComplete("schTasks\$taskId")
    }
}
