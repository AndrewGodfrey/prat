# .SYNOPSIS
# Scan a repo's test files for common anti-patterns: state mutations without save/restore,
# and write operations targeting real user paths.
#
# .DESCRIPTION
# Checks *.Tests.ps1 files (via git ls-files) for:
#   - $env:VAR written without a corresponding read of that variable elsewhere in the file
#     (indicating the original value is not saved before mutation)
#   - Write cmdlets (Set-Content, Add-Content, Out-File, New-Item) targeting $home paths
#     (indicating tests that write to real user directories instead of TestDrive)
#
# Exits with code 1 if any findings are reported.
#
# .PARAMETER Path
# Root of the git repo to scan, or a single .Tests.ps1 file. Defaults to current directory.

param(
    [string] $Path = (Get-Location).Path,
    [int]    $MaxFoundLines = 3
)

$writeCmdlets = 'Set-Content|Add-Content|Out-File|New-Item'

function Find-TestAntiPatternsInContent {
    param([string] $Content, [string] $RelPath, [int] $MaxFoundLines = 3)

    $findings = [System.Collections.Generic.List[string]]::new()
    $lines = $Content -split '\r?\n'

    function fmtLines($nums) {
        $shown = @($nums | Select-Object -First $MaxFoundLines)
        $extra = $nums.Count - $shown.Count
        $suffix = if ($extra -gt 0) { " and $extra more" } else { "" }
        "(line $(($shown) -join ', ')$suffix)"
    }

    # Check 1: $env:VARNAME written without save or push/pop protection.
    #
    # Recognised protection:
    #   a) Direct save: = $env:VARNAME read elsewhere in the file
    #   b) Push/pop range: $VAR = push*Environment ... pop*Environment $VAR
    #      — each well-formed pair defines a protected line range; writes inside any range are covered.

    # Build protected line ranges from well-formed push/pop pairs.
    $protectedRanges = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $pushMatch = [regex]::Match($lines[$i], '\$(\w+)\s*=\s*push\w*Environment\b')
        if ($pushMatch.Success) {
            $pushVar = $pushMatch.Groups[1].Value
            $popPat = '\bpop\w*Environment\b.*\$' + [regex]::Escape($pushVar) + '\b'
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match $popPat) {
                    $protectedRanges.Add([PSCustomObject]@{ Start = $i + 1; End = $j + 1 })
                    break
                }
            }
        }
    }

    # Lines marked '# TestAntiPatternOK' are excluded. Build filteredContent for save-pattern
    # check and collect per-variable write line numbers from non-suppressed lines.
    $filteredContent = ($lines | Where-Object { $_ -notmatch '#\s*TestAntiPatternOK' }) -join "`n"

    $varWrites = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[int]]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '#\s*TestAntiPatternOK') { continue }
        $m = [regex]::Match($line, '\$env:([A-Za-z_][A-Za-z_0-9]*)\s*=')
        if ($m.Success) {
            $varName = $m.Groups[1].Value
            if (-not $varWrites.ContainsKey($varName)) {
                $varWrites[$varName] = [System.Collections.Generic.List[int]]::new()
            }
            $varWrites[$varName].Add($i + 1)
        }
    }

    foreach ($kvp in $varWrites.GetEnumerator()) {
        $varName = $kvp.Key
        $unprotectedLines = @($kvp.Value | Where-Object {
            $ln = $_
            -not ($protectedRanges | Where-Object { $ln -ge $_.Start -and $ln -le $_.End })
        })
        if ($unprotectedLines.Count -eq 0) { continue }
        $savePattern = '=\s*\$env:' + [regex]::Escape($varName) + '\b'
        if ($filteredContent -notmatch $savePattern) {
            $findings.Add("env var written without save pattern (`$env:$varName) $(fmtLines $unprotectedLines): $RelPath")
        }
    }

    # Check 2: Write cmdlet with $home as part of the path (same line)
    $homeWriteLines = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '#\s*TestAntiPatternOK') { continue }
        if ($line -match "(?i)($writeCmdlets)\b.*\`$home\b") { $homeWriteLines.Add($i + 1) }
    }
    if ($homeWriteLines.Count -gt 0) {
        $findings.Add("write cmdlet with `$home path $(fmtLines $homeWriteLines): $RelPath")
    }

    return $findings
}

function Get-TestAntiPatternFindings {
    param([string] $Path, [int] $MaxFoundLines = 3)

    $allFindings = [System.Collections.Generic.List[string]]::new()

    if (Test-Path $Path -PathType Leaf) {
        $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
        if ($null -ne $content) {
            $rel = Split-Path $Path -Leaf
            foreach ($f in (Find-TestAntiPatternsInContent -Content $content -RelPath $rel -MaxFoundLines $MaxFoundLines)) {
                $allFindings.Add($f)
            }
        }
    } else {
        Push-Location $Path
        try {
            $gitFiles = git ls-files 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitFiles) {
                $files = $gitFiles | Where-Object { $_ -match '\.Tests\.ps1$' }
            } else {
                Write-Warning "Not a git repo or git ls-files failed — scanning all *.Tests.ps1 files"
                $files = Get-ChildItem -Recurse -Filter "*.Tests.ps1" |
                    ForEach-Object { $_.FullName.Substring($Path.Length + 1) }
            }

            foreach ($rel in $files) {
                $content = Get-Content $rel -Raw -ErrorAction SilentlyContinue
                if ($null -eq $content) { continue }
                foreach ($f in (Find-TestAntiPatternsInContent -Content $content -RelPath $rel -MaxFoundLines $MaxFoundLines)) {
                    $allFindings.Add($f)
                }
            }
        } finally {
            Pop-Location
        }
    }

    return $allFindings
}

if ($MyInvocation.InvocationName -ne '.') {
    $allFindings = Get-TestAntiPatternFindings -Path $Path -MaxFoundLines $MaxFoundLines

    if ($allFindings.Count -eq 0) {
        Write-Host "Clean: no test anti-patterns found in $Path"
        exit 0
    } else {
        foreach ($f in $allFindings) {
            Write-Host "FOUND: $f"
        }
        exit 1
    }
}
