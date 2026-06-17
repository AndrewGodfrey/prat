# Translates an abstract harness event name to the Copilot CLI event name.
# Returns $null for events with no Copilot equivalent.
function ConvertTo-CopilotEvent([string] $abstractEvent) {
    switch ($abstractEvent) {
        'TurnCompleted' { return 'Stop' }
        default         { return $null }
    }
}

# Translates an abstract hook spec to the Copilot CLI hook entry format.
function ConvertTo-CopilotHook($spec) {
    @{ type = "command"; powershell = "& `"$($spec.Script)`""; timeoutSec = 15 }
}

# Merges a list of layer hook specs into a Copilot event → hook-entries hashtable.
# Skips abstract events that have no Copilot equivalent.
function Merge-AgentHooksToCopilot([object[]] $hooksSpecList) {
    $merged = @{}
    foreach ($spec in $hooksSpecList) {
        foreach ($abstractEvent in $spec.Keys) {
            $copilotEvent = ConvertTo-CopilotEvent $abstractEvent
            if ($null -eq $copilotEvent) { continue }
            if (-not $merged[$copilotEvent]) { $merged[$copilotEvent] = @() }
            $merged[$copilotEvent] += @(ConvertTo-CopilotHook $spec[$abstractEvent])
        }
    }
    return $merged
}

# Installs Copilot CLI user-level hooks from the layered harness-agnostic hook spec.
# Copilot hooks go in ~/.copilot/hooks/*.json (all files are loaded).
# We write a single prat-hooks.json that is regenerated on each deploy.
function Install-CopilotHooks($stage, [string] $copilotDir = "$home\.copilot") {
    $hooksDir = Join-Path $copilotDir "hooks"
    $destFile = Join-Path $hooksDir "prat-hooks.json"

    $sourceFiles = @(Resolve-PratLibFile "lib/inst/Get-AgentHooks.ps1" -ListAll)
    if ($sourceFiles.Count -eq 0) { return }

    $hooksSpecList = @($sourceFiles | ForEach-Object { & $_ })
    $merged = Merge-AgentHooksToCopilot $hooksSpecList

    if ($merged.Count -eq 0) { return }

    $hookFile = [ordered]@{ version = 1; hooks = [ordered]@{} }
    foreach ($eventName in ($merged.Keys | Sort-Object)) {
        $hookFile.hooks[$eventName] = @($merged[$eventName])
    }

    $newText = ConvertTo-Json $hookFile -Depth 10

    Install-Folder $stage $hooksDir
    Install-JsonToFile $stage $destFile $newText -SetReadOnly
}

function Install-CopilotHarness($stage) {
    Install-CopilotHooks $stage
}
