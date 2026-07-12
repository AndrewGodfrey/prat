function Get-SshdConfigContent {
    return @"
ListenAddress 127.0.0.1
PubkeyAuthentication yes
PasswordAuthentication no
"@
}

# .SYNOPSIS
# Set up OpenSSH Server as a loopback-only SSH server for sandbox access.
#
# Installs the OpenSSH Server Windows optional feature if absent, writes a minimal
# sshd_config (loopback-only, pubkey auth only), and starts/enables the sshd service.
# Intended for use with Install-LocalAgentSandbox to enable Windows Terminal access
# to the sandboxed agent account via SSH instead of a conhost window.
#
# .PARAMETER stage
# InstallationStage from the caller's Start-Installation tracker.
#
# .PARAMETER sshdConfigPath
# Path to sshd_config. Defaults to C:\ProgramData\ssh\sshd_config.
function Install-SandboxSshServer {
    [CmdletBinding()]
    param(
        $stage,
        [string] $sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
    )

    if ($stage.GetIsStepComplete("sandboxSshServer")) { return }

    # Install OpenSSH Server feature if not present (sshd service existence is the proxy)
    if ($null -eq (Get-Service sshd -ErrorAction SilentlyContinue)) {
        $stage.OnChange()
        Invoke-Gsudo { Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0" | Out-Null }
    }

    # Write minimal sshd_config: loopback-only, pubkey auth, no password auth
    Install-TextToFile $stage $sshdConfigPath (Get-SshdConfigContent) -SudoOnWrite

    # Start/restart the service and set to auto-start
    $stage.OnChange()
    Invoke-Gsudo {
        $sshd = Get-Service sshd -ErrorAction SilentlyContinue
        if ($null -ne $sshd) {
            $sshd | Set-Service -StartupType Automatic | Out-Null
            if ($sshd.Status -eq "Running") {
                $sshd | Restart-Service | Out-Null
            } else {
                $sshd | Start-Service | Out-Null
            }
        }
    }

    $stage.SetStepComplete("sandboxSshServer")
}

function Get-AgentGitconfigContent([string[]] $directories) {
    # Generate a .gitconfig for a sandboxed agent account:
    # - [safe] entries suppress git's "dubious ownership" check for repos owned by the managing user
    # - [credential] disables credential helpers to prevent interactive auth dialogs
    # - [user] provides a commit identity (commits are not expected but git errors without one)
    $safeLines = $directories | ForEach-Object { "`tdirectory = $($_ -replace '\\', '/')" }
    return @"
[safe]
$($safeLines -join "`n")
[credential]
	helper =
[user]
	name = agent
	email = agent@localhost
"@
}

function ensurePathExists($normPath) {
    if (Test-Path $normPath) { return }
    $ext = [System.IO.Path]::GetExtension($normPath)
    if ($ext -eq '') {
        New-Item -ItemType Directory -Path $normPath -Force | Out-Null
    } elseif ($ext -eq '.json' -or $normPath.EndsWith('.json.backup')) {
        Set-Content -Path $normPath -Value '{}' -Encoding utf8NoBOM
    } else {
        throw "Don't know how to create placeholder for: $normPath"
    }
}

function applyPathGrants($agentUser, $paths, $permission) {
    foreach ($path in $paths) {
        $normPath = $path -replace '/', '\'
        ensurePathExists $normPath
        $isDir  = Test-Path -PathType Container $normPath
        $grant  = if ($isDir) { "${agentUser}:(OI)(CI)$permission" } else { "${agentUser}:$permission" }
        $icacls = if ($isDir) { "icacls `"$normPath`" /grant:r `"$grant`" /T" } `
                  else        { "icacls `"$normPath`" /grant:r `"$grant`"" }
        Invoke-Gsudo {
            Invoke-Expression $using:icacls | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "icacls failed for $using:normPath (exit $LASTEXITCODE)" }
        }
    }
}

# Grants non-inherited access on the immediate parent of each given path. Tools that canonicalize
# paths (e.g. Node's fs.realpathSync, used by its module resolver) stat every ancestor directory to
# check for symlinks/junctions, not just the target path itself — even though nothing below that
# ancestor is otherwise accessible. Without this, such tools fail with EPERM on the parent even
# though the agent has full access to the target path underneath it.
# (RA) (FILE_READ_ATTRIBUTES alone) was tried first and was insufficient — Node's Windows lstat
# still failed with EPERM, implying it needs FILE_LIST_DIRECTORY too. (RX) grants that, so — since
# there's no (OI)(CI) — the agent account can list the *names* of the parent's immediate children (e.g.
# see "Desktop", "AppData" exist) but not their contents, and nothing propagates to descendants.
function applyAncestorTraverseGrants($agentUser, $paths) {
    $ancestors = $paths | ForEach-Object { Split-Path ($_ -replace '/', '\') -Parent } | Sort-Object -Unique
    foreach ($dir in $ancestors) {
        # A shallow path (e.g. 'C:\rw') has its parent resolve to the drive root itself. Skip
        # rather than explicitly granting there, instead of failing the whole call: an explicit
        # grant would assume every machine's drive root ACL is at least as permissive as the
        # agent needs, which doesn't hold universally, but on a typical Windows install
        # BUILTIN\Users already has (RX) on the drive root by default - so an explicit grant is
        # usually redundant anyway. Cost: Node-style fs.realpathSync-based tooling may still EPERM
        # walking up from a path this shallow - narrower than the alternative of not being able to
        # grant such a path at all.
        if ($dir -match '^[A-Za-z]:\\?$') {
            continue
        }
        $grant = "${agentUser}:(RX)"
        Invoke-Gsudo {
            icacls $using:dir /grant:r $using:grant | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "icacls failed for $using:dir (exit $LASTEXITCODE)" }
        }
    }
}

# Remove the agent's grant on a path that has dropped out of the desired spec. /T so descendants that
# got their own explicit ACEs are cleared too; /C so a single locked file doesn't abort the deploy. A
# descendant still covered by a surviving ancestor grant reverts to that ancestor's permission via
# inheritance. No-op if the path no longer exists - nothing to revoke.
function revokePathGrant($agentUser, $path) {
    $normPath = $path -replace '/', '\'
    if (-not (Test-Path $normPath)) { return }
    Invoke-Gsudo {
        icacls $using:normPath /remove:g $using:agentUser /T /C | Out-Null
    }
}

# Lexical path canonicalization for ACL-spec comparison and nesting checks: collapse ./.. and doubled
# separators, normalize '/' to '\', lowercase for case-insensitive matching (equivalent to Python's
# os.path.normcase(os.path.normpath(p))). Lexical only - does NOT resolve junctions/symlinks; the grant
# roots are already resolved paths. A separate agent-access policy layer may canonicalize the same
# roots for its own matching - it must use these same lexical rules for the two to agree.
function Get-CanonicalAclPath([string] $path) {
    return ([System.IO.Path]::GetFullPath($path)).TrimEnd('\').ToLowerInvariant()
}

# True if $child is $parent or a descendant of it. Inputs must already be canonical (see
# Get-CanonicalAclPath). Path-segment aware: 'c:\deFoo' is not under 'c:\de'.
function Test-AclPathIsUnder([string] $child, [string] $parent) {
    return $child -eq $parent -or $child.StartsWith($parent + '\', [System.StringComparison]::Ordinal)
}

# Sort canonical paths ascending, ordinal - guarantees a parent sorts before any descendant (the
# parent is a strict string prefix). Culture-aware sort does not guarantee that, so don't use it here.
function sortAclPathsOrdinal([string[]] $paths) {
    $arr = [string[]]$paths
    [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
    return $arr
}

# The desired ACL grant set as a canonical, deduped, parent-before-child ordered list of
# { Access = 'rw'|'ro'; Path = <canonical> }. This is the "concise description of what we want to
# apply" that gets diffed against the saved copy from the last apply (see Compare-AgentAclSpec).
function Get-AgentAclSpec([string[]] $rwPaths = @(), [string[]] $roPaths = @()) {
    # ro first, then rw, so rw wins on an exact-duplicate path (matches applyPathGrants' apply order).
    $accessByPath = @{}
    foreach ($p in $roPaths) { $accessByPath[(Get-CanonicalAclPath $p)] = 'ro' }
    foreach ($p in $rwPaths) { $accessByPath[(Get-CanonicalAclPath $p)] = 'rw' }

    # Build with an explicit list (not a pipeline): sortAclPathsOrdinal collapses an empty result to
    # $null, and '$null | ForEach-Object' would iterate once and emit a bogus null-path entry.
    $spec = [System.Collections.Generic.List[object]]::new()
    foreach ($p in (sortAclPathsOrdinal([string[]]$accessByPath.Keys))) {
        $spec.Add([pscustomobject]@{ Access = $accessByPath[$p]; Path = $p })
    }
    return @($spec)
}

# Serialize / parse the spec for the saved-state file. One 'access<TAB>path' line per entry.
function Format-AgentAclSpec($spec) {
    return ((@($spec | Where-Object { $null -ne $_ }) | ForEach-Object { "$($_.Access)`t$($_.Path)" }) -join "`n")
}
function ConvertFrom-AgentAclSpecText([string] $text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    return @(($text -split "`r?`n") | Where-Object { $_ -ne '' } | ForEach-Object {
        $parts = $_ -split "`t", 2
        [pscustomobject]@{ Access = $parts[0]; Path = $parts[1] }
    })
}

# Diff the desired spec against what was applied last time. Returns:
#   Apply  - desired entries that are new or whose access changed, parent-before-child order
#            (icacls /grant:r, so a deeper root's explicit ACE overrides the shallower's inherited one).
#   Revoke - paths no longer desired, reduced to the OUTERMOST removed roots (a removed root nested
#            under another removed root is already covered by the parent's recursive /remove). A
#            removed child nested under a SURVIVING root stays in Revoke - removing its explicit ACE
#            reverts it to the surviving parent's permission via inheritance.
function Compare-AgentAclSpec($Saved, $Desired) {
    # Normalize away PowerShell's empty/1-element-array collapse: an empty spec (e.g. first-ever run
    # with no saved copy, or a caller whose @()-returning call collapsed to $null) arrives as $null,
    # and a 1-entry spec as a bare object. '@($x | Where { $null -ne $_ })' yields a clean array in
    # every case ('$null | Where' iterates once with a null item, which the filter drops).
    $Saved   = @($Saved   | Where-Object { $null -ne $_ })
    $Desired = @($Desired | Where-Object { $null -ne $_ })

    $savedAccessByPath = @{}
    foreach ($e in $Saved)   { $savedAccessByPath[$e.Path]   = $e.Access }
    $desiredPaths = @{}
    foreach ($e in $Desired) { $desiredPaths[$e.Path] = $true }

    $apply = @($Desired | Where-Object { $savedAccessByPath[$_.Path] -ne $_.Access })

    $removed = @($Saved | Where-Object { -not $desiredPaths.ContainsKey($_.Path) } | ForEach-Object { $_.Path })
    $outermost = [System.Collections.Generic.List[string]]::new()
    foreach ($p in (sortAclPathsOrdinal([string[]]$removed))) {
        $coveredByKept = $false
        foreach ($kept in $outermost) {
            if (Test-AclPathIsUnder $p $kept) { $coveredByKept = $true; break }
        }
        if (-not $coveredByKept) { $outermost.Add($p) }
    }

    return @{ Apply = $apply; Revoke = @($outermost) }
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
# Paths to grant Full Control with inheritance: (OI)(CI)F.
#
# .PARAMETER roPaths
# Paths to grant ReadAndExecute access with inheritance: (OI)(CI)RX.
#
# .PARAMETER safeDirectories
# Git repo paths to add as safe.directory in the agent's .gitconfig, so git doesn't
# reject repos owned by a different user.
#
# .PARAMETER homeJunctions
# Hashtable of name => target: creates junctions in the agent's home so that ~/name resolves
# to the target path. E.g. @{ de = "C:\Users\xyz\de" } creates ~/de as a junction.
#
# .PARAMETER profileContent
# Content to write to the agent's PowerShell profile
# (Documents\PowerShell\Microsoft.PowerShell_profile.ps1). Typically used to dot-source
# the managing user's prat interactive profile so aliases like 't' are available.
function Install-LocalAgentSandbox {
    [CmdletBinding()]
    param(
        $stage,
        [string] $agentUser,
        [string[]] $rwPaths = @(),
        [string[]] $roPaths = @(),
        [string[]] $safeDirectories = @(),
        [hashtable] $homeJunctions = @{},
        [string] $profileContent = $null,
        [string] $sshPublicKeyPath = $null
    )

    $agentHome = "$env:SystemDrive\Users\$agentUser"

    # One-time setup: account creation and home directory. These steps are interactive or
    # depend only on the user's existence — never need repeating once done.
    if (-not $stage.GetIsStepComplete("localAgentSandbox/$($agentUser)")) {
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

        $stage.SetStepComplete("localAgentSandbox/$($agentUser)")
    }

    # NTFS grants — diff the desired grant spec against what we applied last time on this machine
    # (stored in the instDb) and act only on the delta: (re)grant new/changed roots, revoke dropped
    # ones. Runs every deploy but does real icacls work only when the spec changed, so a
    # grantAgentAccess edit is picked up (the old static version gate never re-ran on such a change)
    # without re-ACLing the whole tree. First run under this mechanism has no saved spec, so it
    # re-applies everything once, then records the spec.
    $aclStateId  = "sandboxacls/$($agentUser)"
    $desiredSpec = Get-AgentAclSpec -rwPaths $rwPaths -roPaths $roPaths
    $savedSpec   = ConvertFrom-AgentAclSpecText ($stage.GetStepState($aclStateId))
    $aclDelta    = Compare-AgentAclSpec -Saved $savedSpec -Desired $desiredSpec

    if (@($aclDelta.Apply).Count -gt 0 -or @($aclDelta.Revoke).Count -gt 0) {
        $stage.OnChange()

        # Revoke dropped roots first, then (re)grant in parent-before-child order (Apply is pre-sorted)
        # so a deeper root's explicit ACE overrides the inherited one from a shallower root.
        # Run elevated so icacls can traverse subdirectories owned by the agent account.
        foreach ($p in $aclDelta.Revoke) { revokePathGrant $agentUser $p }
        foreach ($e in $aclDelta.Apply) {
            $perm = if ($e.Access -eq 'rw') { 'F' } else { 'RX' }
            applyPathGrants $agentUser @($e.Path) $perm
        }
        # Ancestor-traverse grants for the applied roots only. A revoked root's ancestor grant is left
        # in place: it only lets the agent list a parent dir's immediate child names (no recursion, see
        # applyAncestorTraverseGrants), parents are often shared between roots, so refcounting removal
        # isn't worth it.
        applyAncestorTraverseGrants $agentUser @($aclDelta.Apply.Path)

        $stage.SetStepState($aclStateId, (Format-AgentAclSpec $desiredSpec))
    }

    # Home-account setup: junctions, PowerShell profile, gitconfig, SSH authorized_keys. Version-gated
    # (these inputs change rarely); the internally idempotent writers self-correct if re-run.
    if (-not $stage.GetIsStepComplete("sandboxHomeSetup/$($agentUser):1.0")) {

        # Home directory junctions — make ~/name resolve to the target from the agent's perspective.
        # Andrew has Modify on agentHome (granted above) so no elevation needed.
        foreach ($name in $homeJunctions.Keys) {
            $jLink   = "$agentHome\$name"
            $jTarget = $homeJunctions[$name] -replace '/', '\'
            $jItem   = Get-Item $jLink -ErrorAction SilentlyContinue
            if ($null -eq $jItem -or $jItem.LinkType -ne 'Junction') {
                $stage.OnChange()
                if ($null -ne $jItem) { Remove-Item -Force -Recurse $jLink }
                New-Item -ItemType Junction -Path $jLink -Target $jTarget | Out-Null
            }
        }

        # PowerShell profile — makes prat aliases (t, c, etc.) available in the agent's sessions.
        if ($profileContent) {
            $profileDir = Join-Path $agentHome "Documents\PowerShell"
            $null = New-Item -ItemType Directory -Path $profileDir -ErrorAction SilentlyContinue
            Install-TextToFile $stage (Join-Path $profileDir "Microsoft.PowerShell_profile.ps1") $profileContent
        }

        # gitconfig safe.directory entries
        $agentGitconfig = Join-Path $agentHome ".gitconfig"
        Install-TextToFile $stage $agentGitconfig (Get-AgentGitconfigContent $safeDirectories) -SudoOnWrite

        # SSH authorized_keys — enables loopback SSH access from the managing user.
        # Done entirely elevated: after first run the file is owned by agentUser with no ACE for andrew,
        # so non-elevated reads/writes would fail on re-runs.
        if ($sshPublicKeyPath) {
            $sshDir         = "$agentHome\.ssh"
            $authKeys       = "$sshDir\authorized_keys"
            $desiredContent = Get-Content $sshPublicKeyPath -Raw
            New-Item -ItemType Directory -Path $sshDir -ErrorAction SilentlyContinue | Out-Null
            Invoke-Gsudo {
                if (Test-Path $using:authKeys) {
                    # File has owner=agentUser, ACL=agentUser+SYSTEM only — no ACE for Administrators.
                    # Take ownership first (SeTakeOwnershipPrivilege), then grant admin read/write.
                    & takeown /f $using:authKeys | Out-Null
                    & icacls $using:authKeys /grant "Administrators:(F)" | Out-Null
                }
                $existing = Get-Content $using:authKeys -Raw -ErrorAction SilentlyContinue
                if ($existing -ne $using:desiredContent) {
                    Set-Content $using:authKeys $using:desiredContent -Encoding UTF8
                }
                # Restore owner and apply final ACLs
                & icacls $using:authKeys /setowner $using:agentUser | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "icacls /setowner failed for $using:authKeys (exit $LASTEXITCODE)" }
                & icacls $using:authKeys /inheritance:r /grant:r "$($using:agentUser):(F)" /grant:r "NT AUTHORITY\SYSTEM:(F)" | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "icacls ACL failed for $using:authKeys (exit $LASTEXITCODE)" }
            }
        }

        $stage.SetStepComplete("sandboxHomeSetup/$($agentUser):1.0")
    }
}
