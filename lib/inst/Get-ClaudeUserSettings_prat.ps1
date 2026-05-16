# Returns the prat-layer Claude user settings as a hashtable.
# Merged with other layers by Install-ClaudeUserSettings.
return @{
    hooks = @{
        Stop = @(
            @{hooks = @(@{type = "command"; command = 'pwsh -c ''& "$home/prat/lib/On-AgentTurnCompleted.ps1"'''})}
        )
        StopFailure = @(
            @{hooks = @(@{type = "command"; command = 'pwsh -c ''& "$home/prat/lib/On-AgentTurnCompleted.ps1"'''})}
        )
        UserPromptSubmit = @(
            @{hooks = @(@{type = "command"; command = 'pwsh -c ''& "$home/prat/lib/agents/On-UserPromptSubmit.ps1"'''})}
        )
    }
}
