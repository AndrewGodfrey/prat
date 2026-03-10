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
# grants NTFS access to the specified paths, links Claude config from an existing user's home,
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
# .PARAMETER claudeHome
# Home directory of the user whose Claude config the agent should share. Creates a junction
# for .claude/ and a symlink for .claude.json in the agent's home.
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
        [string] $claudeHome = $null,
        [string[]] $safeDirectories = @()
    )

    $agentHome = "$env:SystemDrive\Users\$agentUser"

    if ($stage.GetIsStepComplete("localAgentSandbox/$agentUser")) { return }

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

    # Grant the managing user Modify access to agentHome for unelevated management operations
    # (idempotency checks, config injection at launch time).
    $agentHomeNorm = $agentHome -replace '/', '\'
    $managerGrant  = "${env:USERNAME}:(OI)(CI)M"
    Invoke-Gsudo {
        icacls $using:agentHomeNorm /grant:r $using:managerGrant | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "icacls failed for $using:agentHomeNorm (exit $LASTEXITCODE)" }
    }

    # NTFS grants — always re-apply; /grant:r avoids duplicate ACEs on re-runs.
    # Run elevated so icacls can traverse subdirectories owned by the agent account.
    foreach ($path in $rwPaths) {
        $normPath = $path -replace '/', '\'
        $isDir    = Test-Path -PathType Container $normPath
        $grant    = if ($isDir) { "${agentUser}:(OI)(CI)M" } else { "${agentUser}:M" }
        $icacls   = if ($isDir) { "icacls `"$normPath`" /grant:r `"$grant`" /T" } `
                    else        { "icacls `"$normPath`" /grant:r `"$grant`"" }
        Invoke-Gsudo {
            Invoke-Expression $using:icacls | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "icacls failed for $using:normPath (exit $LASTEXITCODE)" }
        }
    }
    foreach ($path in $roPaths) {
        $normPath = $path -replace '/', '\'
        $isDir    = Test-Path -PathType Container $normPath
        $grant    = if ($isDir) { "${agentUser}:(OI)(CI)RX" } else { "${agentUser}:RX" }
        $icacls   = if ($isDir) { "icacls `"$normPath`" /grant:r `"$grant`" /T" } `
                    else        { "icacls `"$normPath`" /grant:r `"$grant`"" }
        Invoke-Gsudo {
            Invoke-Expression $using:icacls | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "icacls failed for $using:normPath (exit $LASTEXITCODE)" }
        }
    }

    # Link Claude config from the managing user's home — junction for .claude/, symlink for .claude.json
    if ($claudeHome) {
        $claudeHome = $claudeHome -replace '/', '\'
        $jLink   = "$agentHome\.claude"
        $jTarget = "$claudeHome\.claude"
        $jItem   = Get-Item $jLink -ErrorAction SilentlyContinue
        if ($null -eq $jItem -or $jItem.LinkType -ne 'Junction') {
            $stage.OnChange()
            if ($null -ne $jItem) { Invoke-Gsudo { Remove-Item -Force -Recurse $using:jLink } }
            Invoke-Gsudo { New-Item -ItemType Junction    -Path $using:jLink   -Target $using:jTarget | Out-Null }
        }
    }

    # gitconfig safe.directory entries
    $agentGitconfig = Join-Path $agentHome ".gitconfig"
    Install-TextToFile $stage $agentGitconfig (Get-AgentGitconfigContent $safeDirectories) -SudoOnWrite

    $stage.SetStepComplete("localAgentSandbox/$agentUser")
}
