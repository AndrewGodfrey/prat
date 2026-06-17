# Returns the prat-layer Claude user settings as a hashtable.
# Merged with other layers by Install-ClaudeUserSettings.
$hooks = & "$PSScriptRoot/Get-AgentHooks_prat.ps1"

function script:toCcHook($spec) {
    @{ hooks = @(@{ type = "command"; command = "pwsh -c '& `"$($spec.Script)`"'" }) }
}

return @{
    hooks = @{
        Stop             = @(toCcHook $hooks.TurnCompleted)
        StopFailure      = @(toCcHook $hooks.TurnCompleted)
        UserPromptSubmit = @(toCcHook $hooks.PromptSubmitted)
    }
}
