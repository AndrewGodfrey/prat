# Captures git state for a cwd and all related repos.
# Related repos are discovered via pathbin/Get-CodebaseLayers.ps1 if present in the git root.

function Get-GitCwdState($cwd) {
    $repoPaths = Get-WatchedRepoPaths $cwd
    if ($repoPaths.Count -eq 0) { return $null }

    $state = @{}
    foreach ($path in $repoPaths) {
        if ($null -ne (Invoke-GitOutput $path @('rev-parse', '--git-dir'))) {
            $state[$path] = Get-GitRepoState $path
        }
    }
    if ($state.Count -gt 0) { return $state }
}

function Get-WatchedRepoPaths($cwd) {
    $gitRoot = Invoke-GitOutput $cwd @('rev-parse', '--show-toplevel')
    if ($null -eq $gitRoot) { return @() }
    $gitRoot = ($gitRoot -replace '\\', '/').TrimEnd('/')

    $layersScript = "$gitRoot/pathbin/Get-CodebaseLayers.ps1"
    if (Test-Path $layersScript) {
        $layers = & $layersScript
        return @($layers | ForEach-Object { ($_.Path -replace '\\', '/').TrimEnd('/') })
    }
    return @($gitRoot)
}

function Get-GitRepoState($repoPath) {
    $branch    = Invoke-GitOutput $repoPath @('branch', '--show-current')
    $log       = Invoke-GitOutput $repoPath @('log', '--oneline', '-3')
    $statusRaw = Invoke-GitOutput $repoPath @('status', '--short')

    return @{
        branch            = $branch ?? ''
        log               = $log ?? ''
        status            = $statusRaw ?? ''
        uncommittedHashes = Get-UncommittedFileHashes $repoPath (Parse-StatusFiles $statusRaw)
    }
}

function Parse-StatusFiles($statusRaw) {
    if (-not $statusRaw) { return @() }
    @($statusRaw -split "`n" | Where-Object { $_.Length -ge 4 } | ForEach-Object {
        $path = $_.Substring(3).Trim()
        if ($path -match '^.+ -> (.+)$') { $matches[1] } else { $path }
    })
}

function Get-UncommittedFileHashes($repoPath, $files) {
    $hashes = @{}
    if ($files.Count -eq 0) { return $hashes }

    if ($files.Count -le 5) {
        foreach ($f in $files) {
            $fullPath = Join-Path $repoPath $f
            if (Test-Path $fullPath) {
                $hashes[$f] = (Get-FileHash $fullPath -Algorithm SHA256).Hash
            }
        }
    } else {
        $parts = foreach ($f in ($files | Sort-Object)) {
            $fullPath = Join-Path $repoPath $f
            if (Test-Path $fullPath) { "$f=" + (Get-FileHash $fullPath -Algorithm SHA256).Hash }
        }
        $combined  = ($parts | Where-Object { $_ }) -join "`n"
        $bytes     = [System.Text.Encoding]::UTF8.GetBytes($combined)
        $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
        $hashes['__all__'] = ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
    }
    return $hashes
}

function Get-SnapshotPath($snapshotDir, $sessionId, $cwd) {
    $bytes   = [System.Text.Encoding]::UTF8.GetBytes($cwd)
    $md5     = [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
    $cwdHash = ([System.BitConverter]::ToString($md5) -replace '-', '').ToLower().Substring(0, 8)
    return "$snapshotDir/${sessionId}_${cwdHash}.json"
}

function Invoke-GitOutput($repoPath, [string[]]$gitArgs) {
    $output = & git -C $repoPath @gitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($output -join "`n").Trim()
}
