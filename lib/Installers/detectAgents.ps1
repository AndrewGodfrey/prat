function agentFromFilename([string] $name) {
    if ($name.Contains("copilot-instructions.md")) {
        return "copilot"
    } elseif ($name.Contains("CLAUDE.md")) {
        return "claude"
    } elseif ($name.Contains("GEMINI.md")) {
        return "gemini"
    } elseif ($name.Contains("AGENTS.md")) {
        return "codex"
    } else {
        throw "Unknown agent type for file: $name"
    }
}

# Detects which agent or agents a codebase is set up for
function Get-AgentsForCodebase($startingDir, $defaultAgent) {
    if ($null -ne $env:__prat_selectedAgent) {
        return $env:__prat_selectedAgent
    }

    $results = @()
    $results += &$PSScriptRoot/../Get-ContainingItem.ps1 -Multiple ".github/copilot-instructions.md" $startingDir
    $results += &$PSScriptRoot/../Get-ContainingItem.ps1 -Multiple "CLAUDE.md" $startingDir
    $results += &$PSScriptRoot/../Get-ContainingItem.ps1 -Multiple "GEMINI.md" $startingDir
    $results += &$PSScriptRoot/../Get-ContainingItem.ps1 -Multiple "AGENTS.md" $startingDir
    $agents = @($results | ForEach-Object { agentFromFilename $_.Name } | Select-Object -Unique)
    
    return $agents
}

# Using Get-AgentsForCodebase, selects an agent to use, or fails if no matching agent is installed.
function Select-AgentForCodebase($startingDir, $defaultAgent, [string[]] $installedAgents) {
    $agentsFound = Get-AgentsForCodebase $startingDir $defaultAgent
    if ($agentsFound.Count -eq 0) {
        Write-Host "No agent indicators found in $startingDir or its parents. Defaulting to '$defaultAgent'."
        return $defaultAgent
    }

    $agents = @($agentsFound | ? { $installedAgents -contains $_ })
    if ($agents.Count -eq 0) {
        throw "All agent(s) detected in $startingDir are not installed: $($agentsFound -join ", ")."
        return $null
    }

    if ($agents.Count -gt 1) {
        Write-Warning "Multiple agent indicators found: $($agents -join ", "). Defaulting to '$defaultAgent'."
        return $defaultAgent
    }

    return $agents[0]
}

