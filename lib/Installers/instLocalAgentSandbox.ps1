function Get-AgentGitconfigContent([string[]] $directories) {
    # Generate a .gitconfig [safe] section marking the given directories as safe
    # for a user account that doesn't own them (suppresses git's "dubious ownership" check).
    $lines = $directories | ForEach-Object { "`tdirectory = $($_ -replace '\\', '/')" }
    return "[safe]`n" + ($lines -join "`n") + "`n"
}

# .SYNOPSIS
# Set up a sandboxed local Windows account for running an AI coding agent.
#
# Creates the account interactively (prompts for password via sudo), stores the launch
# credential via runas /savecred (which also creates the home directory with correct ACLs),
# grants NTFS access to the specified paths, creates a directory junction for .claude config,
# and writes a gitconfig with safe.directory entries.
#
# .PARAMETER stage
# InstallationStage from the caller's Start-Installation tracker.
#
# .PARAMETER agentUser
# Local Windows username for the sandboxed agent account.
#
# .PARAMETER rwPaths
# Paths to grant Modify (read/write) access with inheritance: (OI)(CI)M.
#
# .PARAMETER roPaths
# Paths to grant ReadAndExecute access with inheritance: (OI)(CI)RX.
#
# .PARAMETER claudeJunction
# Hashtable @{ link = "path"; target = "path" } for a .claude directory junction in the agent's home.
#
# .PARAMETER safeDirectories
# Git repo paths to add as safe.directory in the agent's .gitconfig, so git doesn't
# reject repos owned by a different user.
function Install-LocalAgentSandbox {
    [CmdletBinding()]
    param(
        $stage,
        [string] $agentUser,
        [string[]] $rwPaths = @(),
        [string[]] $roPaths = @(),
        [hashtable] $claudeJunction = $null,
        [string[]] $safeDirectories = @()
    )

    $agentHome = "$env:SystemDrive\Users\$agentUser"

    # Create account — interactive: sudo prompts for password via 'net user *'
    if ($null -eq (Get-LocalUser $agentUser -ErrorAction SilentlyContinue)) {
        $stage.OnChange()
        sudo "net user $agentUser /add" | Out-Null 
        sudo "net user $agentUser *"
    }

    # Store credential for password-free launching. Also creates $agentHome with correct ACLs.
    if (-not (Test-Path $agentHome)) {
        $stage.OnChange()
        sudo "runas /savecred /user:$agentUser 'pwsh -Command exit'"
    }
    if (-not (Test-Path $agentHome)) {
        throw "Failed to create home directory for $agentUser at $agentHome"
    }

    # NTFS grants — always re-apply; /grant:r avoids duplicate ACEs on re-runs.
    # Run elevated so icacls can traverse subdirectories owned by the agent account.
    foreach ($path in $rwPaths) {
        $normPath = $path -replace '/', '\'
        Invoke-Gsudo {
            icacls $using:normPath /grant:r "${using:agentUser}:(OI)(CI)M" /T | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "icacls failed for $using:normPath (exit $LASTEXITCODE)" }
        }
    }
    foreach ($path in $roPaths) {
        $normPath = $path -replace '/', '\'
        Invoke-Gsudo {
            icacls $using:normPath /grant:r "${using:agentUser}:(OI)(CI)RX" /T | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "icacls failed for $using:normPath (exit $LASTEXITCODE)" }
        }
    }

    # Directory junction for .claude — idempotent via Test-Path
    if ($claudeJunction) {
        $jLink   = $claudeJunction.link   -replace '/', '\'
        $jTarget = $claudeJunction.target -replace '/', '\'
        if (-not (Test-Path $jLink)) {
            $stage.OnChange()
            Invoke-Gsudo { New-Item -ItemType Junction -Path $using:jLink -Target $using:jTarget | Out-Null }
        }
    }

    # gitconfig safe.directory entries
    $agentGitconfig = Join-Path $agentHome ".gitconfig"
    Install-TextToFile $stage $agentGitconfig (Get-AgentGitconfigContent $safeDirectories) -SudoOnWrite

    $stage.EnsureManualStep("localAgentSandbox/$agentUser/terminalProfile",
        "Add Windows Terminal profile for '$agentUser':`n" +
        "  Settings > Add new profile > New empty profile`n" +
        "  Name: '$agentUser (sandboxed claude)'`n" +
        "  Command line: runas /savecred /user:$agentUser pwsh`n" +
        "  Note: opens a console window, not a WT tab.")
}
