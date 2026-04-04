# Stale-module detection: all hash file I/O lives here.
#
# Write side: each module's .psm1 calls pratWriteModuleHash at load time.
# Read side:  scriptProfile snapshots hashes at session start;
#             interactiveProfile checks for staleness in the prompt.

$script:_pratModuleHashDir = "$HOME/prat/auto/moduleHashes"

function pratWriteModuleHash($moduleName, $sourceRoot) {
    if (-not (Test-Path $script:_pratModuleHashDir)) {
        New-Item -Type Directory $script:_pratModuleHashDir -Force | Out-Null
    }
    $combinedHash = (Get-ChildItem $sourceRoot -Filter *.ps* -File |
        Sort-Object Name |
        ForEach-Object { (Get-FileHash $_.FullName -Algorithm SHA256).Hash }) -join ':'
    $finalHash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::HashData(
            [System.Text.Encoding]::UTF8.GetBytes($combinedHash)
        )
    ).Replace('-','')
    Set-Content "$script:_pratModuleHashDir/$moduleName.hash" $finalHash -NoNewline
}

function pratGetModuleHashSnapshot {
    $snapshot = @{}
    if (Test-Path $script:_pratModuleHashDir) {
        foreach ($f in Get-ChildItem $script:_pratModuleHashDir -Filter *.hash -File) {
            $snapshot[$f.BaseName] = (Get-Content $f.FullName -Raw)
        }
    }
    return $snapshot
}

function pratTestModulesStale($snapshotAtStart) {
    if (-not (Test-Path $script:_pratModuleHashDir)) { return $false }
    if ($null -eq $snapshotAtStart) { return $false }
    foreach ($f in Get-ChildItem $script:_pratModuleHashDir -Filter *.hash -File) {
        $currentHash = Get-Content $f.FullName -Raw
        $startHash = $snapshotAtStart[$f.BaseName]
        if ($null -ne $startHash -and $startHash -ne $currentHash) {
            return $true
        }
    }
    return $false
}
