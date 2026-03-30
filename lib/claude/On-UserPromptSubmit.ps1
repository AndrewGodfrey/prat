# On-UserPromptSubmit.ps1
# UserPromptSubmit hook: emits git state diff as additionalContext if git state changed since last turn.
#
# Output: additionalContext JSON on stdout when git state changed; nothing otherwise.

. "$PSScriptRoot/../Get-GitCwdState.ps1"

function main($hookData) {
    Invoke-UserPromptSubmitCompanion $hookData
    Emit-GitStateDiff $hookData
}

function Invoke-UserPromptSubmitCompanion($hookData, $companionPath = "$home/prefs/lib/claude/On-UserPromptSubmit.ps1") {
    if (-not (Test-Path $companionPath)) { return }
    ($hookData | ConvertTo-Json -Compress) | pwsh -File $companionPath | Out-Null
}

function Emit-GitStateDiff($hookData, $snapshotDir = "$home/prat/auto/context/gitStateSnapshot") {
    $sessionId = $hookData.session_id
    $cwd       = $hookData.cwd
    if (-not $sessionId -or -not $cwd) { return }

    $snapFile = Get-SnapshotPath $snapshotDir $sessionId $cwd
    if (-not (Test-Path $snapFile)) { return }

    $oldState = Get-Content $snapFile -Raw | ConvertFrom-Json -AsHashtable
    $newState = Get-GitCwdState $cwd
    if ($null -eq $newState) { return }

    # Update snapshot before comparing so next prompt sees fresh baseline
    $null = New-Item -ItemType Directory -Path $snapshotDir -Force
    $newState | ConvertTo-Json -Depth 5 | Set-Content $snapFile -Encoding UTF8

    $showRepoNames = $newState.Keys.Count -gt 1
    $diffs = [ordered]@{}
    foreach ($repoPath in $newState.Keys) {
        if (-not $oldState.ContainsKey($repoPath)) { continue }
        $diff = Get-RepoDiff $oldState[$repoPath] $newState[$repoPath]
        if ($null -ne $diff) { $diffs[$repoPath] = $diff }
    }
    if ($diffs.Count -eq 0) { return }

    Format-GitStateMessage $diffs $showRepoNames
}

function Get-RepoDiff($old, $new) {
    $diff = @{}

    if ($old.branch -ne $new.branch) {
        $diff['branchOld'] = $old.branch
        $diff['branchNew'] = $new.branch
    }
    if ($old.log -ne $new.log -or $diff.ContainsKey('branchOld')) {
        $diff['logNew'] = $new.log
    }
    if ($old.status -ne $new.status) {
        $statusDelta = Get-StatusDelta $old.status $new.status
        if ($statusDelta.Count -gt 0) { $diff['statusDelta'] = $statusDelta }
    }
    $oldH = if ($old.uncommittedHashes) { $old.uncommittedHashes } else { @{} }
    $newH = if ($new.uncommittedHashes) { $new.uncommittedHashes } else { @{} }
    if (-not (Compare-HashtablesEqual $oldH $newH) -and -not $diff.ContainsKey('statusDelta')) {
        if ($oldH.ContainsKey('__all__') -or $newH.ContainsKey('__all__')) {
            $diff['uncommittedChanged'] = $true
        } else {
            $diff['uncommittedChangedFiles'] = @($newH.Keys | Where-Object { -not $oldH.ContainsKey($_) -or $oldH[$_] -ne $newH[$_] })
        }
    }

    if ($diff.Count -gt 0) { return $diff }
}

# Returns the status lines that are new or changed since $oldStatus.
# Lines that disappeared (e.g. after a commit) are not included — those are reflected in the log.
function Get-StatusDelta($oldStatus, $newStatus) {
    $oldLines = @{}
    ($oldStatus -split "`n") | Where-Object { $_ } | ForEach-Object {
        $file = if ($_ -match '^R. (.+) -> (.+)$') { $matches[2] } else { $_.Substring(3) }
        $oldLines[$file] = $_
    }
    $delta = @()
    ($newStatus -split "`n") | Where-Object { $_ } | ForEach-Object {
        $file = if ($_ -match '^R. (.+) -> (.+)$') { $matches[2] } else { $_.Substring(3) }
        if (-not $oldLines.ContainsKey($file) -or $oldLines[$file] -ne $_) { $delta += $_ }
    }
    return $delta
}

function Compare-HashtablesEqual($a, $b) {
    if ($a.Count -ne $b.Count) { return $false }
    foreach ($key in $a.Keys) {
        if (-not $b.ContainsKey($key) -or $a[$key] -ne $b[$key]) { return $false }
    }
    return $true
}

function Format-StatusLine($line) {
    $xy   = $line.Substring(0, 2)
    $rest = $line.Substring(3)
    $label = switch ($xy) {
        '??' { 'untracked' }
        'M ' { 'staged' }
        ' M' { 'modified' }
        'MM' { 'staged+modified' }
        'A ' { 'added' }
        'AM' { 'added+modified' }
        'D ' { 'staged-deleted' }
        ' D' { 'deleted' }
        'R ' { 'renamed' }
        'RM' { 'renamed+modified' }
        'C ' { 'copied' }
        'UU' { 'conflict' }
        default { $xy.Trim() }
    }
    return "$label`: $rest"
}

function Format-GitStateMessage($diffs, [bool]$showRepoNames) {
    $lines = @('[git state changed since last turn]')

    foreach ($repoPath in $diffs.Keys) {
        $diff = $diffs[$repoPath]

        if ($showRepoNames) {
            $lines += ''
            $lines += "[$(Split-Path $repoPath -Leaf)]"
        }
        if ($diff.ContainsKey('branchOld')) {
            $lines += "Branch: $($diff['branchOld']) → $($diff['branchNew'])"
        }
        if ($diff.ContainsKey('logNew') -and $diff['logNew']) {
            $lines += 'Commits:'
            foreach ($line in ($diff['logNew'] -split "`n")) {
                if ($line) { $lines += "  $line" }
            }
        }
        if ($diff.ContainsKey('statusDelta') -and $diff['statusDelta'].Count -gt 0) {
            $lines += 'Status:'
            foreach ($line in $diff['statusDelta']) { $lines += "  $(Format-StatusLine $line)" }
        }
        if ($diff.ContainsKey('uncommittedChangedFiles')) {
            $files = $diff['uncommittedChangedFiles']
            if ($files.Count -le 5) {
                $lines += 'Content changed:'
                foreach ($file in $files) { $lines += "  $file" }
            } else {
                $lines += "Content changed: $($files.Count) files"
            }
        } elseif ($diff['uncommittedChanged']) {
            $lines += 'Uncommitted file content changed'
        }
    }

    return $lines -join "`n"
}

if ($MyInvocation.InvocationName -ne '.') {
    $hookData = ([Console]::In.ReadToEnd()) | ConvertFrom-Json
    $output = main $hookData
    if ($output) { Write-Output $output }
}
