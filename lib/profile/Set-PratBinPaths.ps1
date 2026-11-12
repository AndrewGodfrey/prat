using module ..\PratBase\PratBase.psd1

# SYNOPSIS
#   Set Prat's binpaths in $env:Path — idempotent. Removes inherited real-path equivalents of
#   junction paths before adding them, so the junction-island version takes precedence.
#   Cache up to four input PATH/binpath configurations for a week, evicting the oldest on overflow.

function addJunctionPath($path, [hashtable]$resolvedPaths = @{}) {
    $entries = @(($env:Path -split ';') | Where-Object { $_ -ne '' })
    foreach ($entry in (@($path) + $entries)) {
        if (-not $resolvedPaths.ContainsKey($entry)) {
            $resolvedPaths[$entry] = Resolve-JunctionInPath $entry
        }
    }
    $realTarget = $resolvedPaths[$path]
    $entries = @($entries | Where-Object {
        $resolvedPaths[$_] -ine $realTarget
    })
    $env:Path = ($entries + $path) -join ';'
}

function Set-PratBinPaths {
    param([string]$CacheFile = "$home\prat\auto\profile\binPathsCache.json")

    $inputPath = $env:Path
    $paths = @()
    if (Test-Path $home\prat\auto\profile\Get-OverrideBinPaths.ps1) {
        $paths += @((&$home\prat\auto\profile\Get-OverrideBinPaths.ps1) -split ';' | Where-Object { $_ -ne '' })
    }
    $paths += (Resolve-Path "$PSScriptRoot\..\..\pathbin").Path
    $paths += "$home\prat\auto\pathbin"
    $configuredPaths = $paths -join ';'
    $now = [datetime]::UtcNow
    $entries = @()
    if (Test-Path -LiteralPath $CacheFile) {
        # The cache is only an optimization, and concurrent shell startups can catch it mid-replace or truncated.
        # Treat any read or parse failure as a miss.
        try {
            $cache = Get-Content -LiteralPath $CacheFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            $cache = $null
        }
        if ($cache.Version -eq 2) {
            $entries = @($cache.Entries | Where-Object { [datetime]$_.CreatedUtc -gt $now.AddDays(-7) })
        }
        $match = $entries | Where-Object {
            ($_.InputPath -ceq $inputPath) -and ($_.ConfiguredPaths -ceq $configuredPaths)
        } | Select-Object -First 1
        if ($null -ne $match) {
            $env:Path = $match.OutputPath
            return
        }
    }

    $resolvedPaths = @{}
    foreach ($path in $paths) {
        addJunctionPath $path $resolvedPaths
    }
    $entries += [ordered]@{
        InputPath = $inputPath
        ConfiguredPaths = $configuredPaths
        CreatedUtc = $now.ToString('o')
        OutputPath = $env:Path
    }
    $cache = [ordered]@{
        Version = 2
        Entries = @($entries | Select-Object -Last 4)
    }
    $CacheFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CacheFile)
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($CacheFile))
    $temporaryFile = "$CacheFile.$([guid]::NewGuid()).tmp"
    # $env:Path is already set, so a failed cache write (e.g. another shell holding the file) only costs a future miss.
    try {
        $cache | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temporaryFile -Encoding utf8NoBOM -ErrorAction Stop
        [IO.File]::Move($temporaryFile, $CacheFile, $true)
    } catch {
    } finally {
        Remove-Item -LiteralPath $temporaryFile -ErrorAction Ignore
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $global:__prat_binPathsSet) {
        Set-PratBinPaths
        $global:__prat_binPathsSet = $true
    }
}
