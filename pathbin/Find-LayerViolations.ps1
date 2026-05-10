# .SYNOPSIS
# Scan a repo for layer boundary violations — identifiers or paths from private layers.
#
# .DESCRIPTION
# Checks tracked files for patterns that shouldn't appear in a given repo layer. Run before
# finalizing a branch in a public repo like prat or prefs to catch accidental references to
# higher-layer (private) repos, functions, or projects.
#
# Exits with code 1 if any findings are reported.
#
# .PARAMETER Path
# Root of the repo (or a single file) to scan. Defaults to current directory.
#
# .PARAMETER Config
# Hashtable with a 'bannedPatterns' array. Each entry: @{ pattern = '...'; description = '...' }
# Pattern is matched as a literal string (case-insensitive). Defaults to $defaultPratConfig.

param (
    [string]    $Path = (Get-Location).Path,
    [hashtable] $Config
)

$defaultPratConfig = & "$PSScriptRoot/../lib/Get-LayerViolationsConfig_prat.ps1"

if (-not $Config) { $Config = $defaultPratConfig }

function Find-LayerViolationsInContent {
    param (
        [string]    $Content,
        [string]    $RelPath,
        [hashtable] $Config
    )

    $findings = [System.Collections.Generic.List[string]]::new()
    $lines = $Content -split '\r?\n'

    foreach ($rule in $Config.bannedPatterns) {
        $matchedLines = [System.Collections.Generic.List[int]]::new()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match [regex]::Escape($rule.pattern)) {
                $matchedLines.Add($i + 1)
            }
        }
        if ($matchedLines.Count -gt 0) {
            $lineList = $matchedLines -join ', '
            $findings.Add("$($rule.description) (line $lineList): $RelPath")
        }
    }

    return $findings
}

function Get-LayerViolationFindings {
    param(
        [string]    $Path,
        [hashtable] $Config = $defaultPratConfig
    )

    $allFindings = [System.Collections.Generic.List[string]]::new()

    if (Test-Path $Path -PathType Leaf) {
        $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
        if ($null -ne $content) {
            $rel = Split-Path $Path -Leaf
            foreach ($f in (Find-LayerViolationsInContent -Content $content -RelPath $rel -Config $Config)) {
                $allFindings.Add($f)
            }
        }
        return $allFindings
    }

    Push-Location $Path
    try {
        $gitFiles = git ls-files 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitFiles) {
            $files = $gitFiles | Where-Object { $_ -match '\.(ps1|md)$' }
        } else {
            Write-Warning "Not a git repo or git ls-files failed — scanning all .ps1/.md files"
            $files = Get-ChildItem -Recurse |
                Where-Object { $_.Name -match '\.(ps1|md)$' } |
                ForEach-Object { $_.FullName.Substring($Path.Length + 1) -replace '\\', '/' }
        }

        foreach ($rel in $files) {
            $content = Get-Content $rel -Raw -ErrorAction SilentlyContinue
            if ($null -eq $content) { continue }
            foreach ($f in (Find-LayerViolationsInContent -Content $content -RelPath $rel -Config $Config)) {
                $allFindings.Add($f)
            }
        }
    } finally {
        Pop-Location
    }

    return $allFindings
}

if ($MyInvocation.InvocationName -ne '.') {
    $allFindings = Get-LayerViolationFindings -Path $Path -Config $Config

    if ($allFindings.Count -eq 0) {
        Write-Host "Clean: no layer violations found in $Path"
        exit 0
    } else {
        foreach ($f in $allFindings) {
            Write-Host "VIOLATION: $f"
        }
        exit 1
    }
}
