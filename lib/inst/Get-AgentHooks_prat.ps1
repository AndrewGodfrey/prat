# Returns the prat-layer harness-agnostic hook spec.
# Consumed by harness adapters (Install-ClaudeUserSettings, Install-CopilotHooks) which translate
# to each harness's wire format.
return @{
    TurnCompleted   = @{ Script = '$home/prat/lib/agents/On-AgentTurnCompleted.ps1' }
    PromptSubmitted = @{ Script = '$home/prat/lib/agents/On-UserPromptSubmit.ps1' }
}
