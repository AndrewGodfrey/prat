# Expose target repos' custom agents in an agent-role dir. Re-run each launch, so it self-heals
# across branch switches, config edits, and upstream file changes. (The role dir is made a git repo
# at deploy — Install-RoleDirGitRepo — which copilot needs to resolve .github/agents here.)
#
# $RepoAgents: @(@{ repo = <repo id>; from = <subpath under repo root> } ...) — any number of entries.
#
# Structure: <RoleDir>/subagents is a real directory exclusively owned by this function, holding a
# merged copy of every entry's agent files (recursively, preserving relative subdirectory structure).
# Copying (rather than linking) each file means multiple repos can be merged into one directory even
# though harnesses expect one flat set of agent files — and avoids needing a symlink privilege (dev
# mode/elevation) that directory junctions don't require. Sync is incremental (like `xcopy /d`): a file
# is (re)copied only when the source is newer than what's already at the destination.
# <RoleDir>/.claude/agents and <RoleDir>/.github/agents are each a junction to <RoleDir>/subagents, so
# both Claude Code and Copilot see the same merged agents.
#
# Reconciliation rules:
#   - subagents/ is fully owned: on each sync, any file under it no longer traceable to a current,
#     resolved $RepoAgents entry is deleted (self-heal). Don't hand-place files there.
#   - When two entries would place a file at the same relative path, the first entry wins (skip + warn).
#   - When nothing is desired (no entries resolve), subagents/ is removed entirely.
#   - The two harness links are junctions to subagents/, desired only while subagents/ exists. An
#     existing junction is removed/re-pointed as needed; a real (non-junction) dir at either path is
#     left untouched (skip + warn) — that's for genuinely hand-authored agents, unrelated to this sync.
#
# $ResolveRepoRoot: { param($repoId) -> <root path> or $null }. Unregistered repos are skipped + warned.
function Sync-RoleAgents {
    [CmdletBinding()]
    param(
        [object[]] $RepoAgents,
        [object[]] $RepoInstructions,
        [Parameter(Mandatory)] [string] $RoleDir,
        [Parameter(Mandatory)] [scriptblock] $ResolveRepoRoot
    )

    $subagentsDir = Join-Path $RoleDir 'subagents'
    $desired = resolveDesiredAgentFiles $RepoAgents $ResolveRepoRoot
    syncOwnedAgentFiles $subagentsDir $desired

    $subagentsTarget = $null
    if (Test-Path -LiteralPath $subagentsDir -PathType Container) {
        $subagentsTarget = (Get-Item -LiteralPath $subagentsDir).FullName.TrimEnd('\')
    }
    syncAgentJunctionLink (Join-Path $RoleDir '.claude\agents') $subagentsTarget
    syncAgentJunctionLink (Join-Path $RoleDir '.github\agents') $subagentsTarget

    # Instructions sync — same pattern as agents, but only when the parameter is explicitly passed.
    if ($PSBoundParameters.ContainsKey('RepoInstructions')) {
        $subinstructionsDir = Join-Path $RoleDir 'subinstructions'
        $desiredInstructions = resolveDesiredAgentFiles $RepoInstructions $ResolveRepoRoot
        syncOwnedAgentFiles $subinstructionsDir $desiredInstructions

        $subinstructionsTarget = $null
        if (Test-Path -LiteralPath $subinstructionsDir -PathType Container) {
            $subinstructionsTarget = (Get-Item -LiteralPath $subinstructionsDir).FullName.TrimEnd('\')
        }
        syncAgentJunctionLink (Join-Path $RoleDir '.github\instructions') $subinstructionsTarget
    }
}

# Builds the desired map: relative path (under each entry's source dir) -> absolute source file path.
# On a collision between entries, the first entry wins (skip + warn).
function resolveDesiredAgentFiles([object[]] $RepoAgents, [scriptblock] $ResolveRepoRoot) {
    $desired = @{}
    foreach ($entry in @($RepoAgents)) {
        if (-not $entry) { continue }
        $root = & $ResolveRepoRoot $entry.repo
        if (-not $root) {
            Write-Warning "Sync-RoleAgents: repo '$($entry.repo)' is not registered; skipping its agents."
            continue
        }
        $source = Join-Path $root $entry.from
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            Write-Warning "Sync-RoleAgents: source '$source' does not exist; skipping."
            continue
        }
        $sourceFull = (Get-Item -LiteralPath $source).FullName.TrimEnd('\')
        foreach ($file in Get-ChildItem -LiteralPath $sourceFull -File -Recurse -Force) {
            $relPath = $file.FullName.Substring($sourceFull.Length).TrimStart('\')
            if ($desired.ContainsKey($relPath)) {
                Write-Warning "Sync-RoleAgents: agent file '$relPath' is declared by more than one source; keeping the first."
                continue
            }
            $desired[$relPath] = $file.FullName
        }
    }
    return $desired
}

# Reconciles $SubagentsDir against $Desired (relative path -> absolute source path): copies in
# new/changed files (skipping ones already up to date, like `xcopy /d`), prunes anything no longer
# desired, and removes $SubagentsDir entirely when nothing is desired. A leftover junction from the
# prior (single-source, link-based) design is replaced with an owned directory.
function syncOwnedAgentFiles([string] $SubagentsDir, [hashtable] $Desired) {
    if ($Desired.Count -eq 0) {
        $existing = Get-Item -LiteralPath $SubagentsDir -Force -ErrorAction SilentlyContinue
        if ($existing -and $existing.LinkType -eq 'Junction') {
            [System.IO.Directory]::Delete($SubagentsDir)   # drop the link only; a leftover target is untouched
        } elseif ($existing) {
            Remove-Item -LiteralPath $SubagentsDir -Recurse -Force
        }
        return
    }

    $existing = Get-Item -LiteralPath $SubagentsDir -Force -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType -eq 'Junction') {
        [System.IO.Directory]::Delete($SubagentsDir)   # drop the link only; the old target's contents are untouched
        $existing = $null
    }
    if (-not $existing) {
        New-Item -ItemType Directory -Path $SubagentsDir -Force | Out-Null
    }
    $subagentsFull = (Get-Item -LiteralPath $SubagentsDir).FullName.TrimEnd('\')

    foreach ($relPath in $Desired.Keys) {
        $dest = Join-Path $subagentsFull $relPath
        $destParent = Split-Path $dest -Parent
        if (-not (Test-Path -LiteralPath $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }
        $destItem = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
        $srcItem  = Get-Item -LiteralPath $Desired[$relPath] -Force
        if (-not $destItem -or $srcItem.LastWriteTimeUtc -gt $destItem.LastWriteTimeUtc) {
            Copy-Item -LiteralPath $srcItem.FullName -Destination $dest -Force
        }
    }

    foreach ($file in Get-ChildItem -LiteralPath $subagentsFull -File -Recurse -Force) {
        $relPath = $file.FullName.Substring($subagentsFull.Length).TrimStart('\')
        if (-not $Desired.ContainsKey($relPath)) {
            Remove-Item -LiteralPath $file.FullName -Force
        }
    }

    # Deepest first, so a directory left empty by its last child's removal above is itself pruned.
    $dirs = @(Get-ChildItem -LiteralPath $subagentsFull -Directory -Recurse -Force) | Sort-Object { $_.FullName.Length } -Descending
    foreach ($dir in $dirs) {
        if (-not (Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $dir.FullName -Force
        }
    }
}

# Reconcile a single junction at $Link so it points at $Target (or, if $Target is $null, so it's
# absent). A real (non-junction) dir at $Link is left untouched (skip + warn).
function syncAgentJunctionLink([string] $Link, [string] $Target) {
    $existing = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue

    if ($existing -and $existing.LinkType -ne 'Junction') {
        Write-Warning "Sync-RoleAgents: '$Link' already exists as a non-junction item; leaving it in place."
        return
    }

    if (-not $Target) {
        if ($existing) { [System.IO.Directory]::Delete($Link) }
        return
    }

    if ($existing) {
        $current = @($existing.Target)[0]
        if ($current -and ([System.IO.Path]::GetFullPath($current).TrimEnd('\') -ieq $Target)) { return }
        [System.IO.Directory]::Delete($Link)
    }

    $parent = Split-Path $Link -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
}
