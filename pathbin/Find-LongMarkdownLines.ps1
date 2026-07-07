# .SYNOPSIS
# Find markdown lines that exceed a maximum width, skipping lines that can't be wrapped.
#
# .DESCRIPTION
# Reports markdown lines longer than -MaxLength characters. Lines inside fenced code
# blocks (``` or ~~~) and table rows (starting with `|`) are exempt, since neither can
# be line-wrapped. Use to enforce the 120-char markdown wrap rule on files you edit.
#
# Emits one finding object per offending line with Path, Line, Length and Text. This is
# the common format consumed by line-oriented filters (e.g. a "changed lines only"
# filter keyed on Path + Line). When run as a script it prints `path:line: N chars`
# and exits 1 if any findings are reported.
#
# .PARAMETER Path
# Root of the repo (or a single file) to scan. Defaults to current directory.
#
# .PARAMETER MaxLength
# Maximum allowed line length in characters. Defaults to 120.

param (
    [string] $Path = (Get-Location).Path,
    [int]    $MaxLength = 120
)

function Find-LongLinesInContent {
    param (
        [string] $Content,
        [string] $RelPath,
        [int]    $MaxLength = 120
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $lines = $Content -split '\r?\n'

    $inFence   = $false
    $fenceChar = $null

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Fenced code block delimiters: 3+ backticks or 3+ tildes (optionally indented,
        # optionally followed by an info string). Toggle on a matching marker char.
        if ($line -match '^\s*(`{3,}|~{3,})') {
            $ch = $Matches[1].Substring(0, 1)
            if (-not $inFence) {
                $inFence = $true
                $fenceChar = $ch
            } elseif ($ch -eq $fenceChar) {
                $inFence = $false
                $fenceChar = $null
            }
            continue
        }

        # Inside a code fence — exempt (code/SQL is not wrappable).
        if ($inFence) { continue }

        # Table rows (optionally indented) — exempt; tables can't be wrapped.
        if ($line -match '^\s*\|') { continue }

        if ($line.Length -gt $MaxLength) {
            $findings.Add([PSCustomObject]@{
                Path   = $RelPath
                Line   = $i + 1
                Length = $line.Length
                Text   = $line
            })
        }
    }

    return $findings
}

function Get-LongMarkdownLineFindings {
    param (
        [string] $Path,
        [int]    $MaxLength = 120
    )

    $allFindings = [System.Collections.Generic.List[object]]::new()

    if (Test-Path $Path -PathType Leaf) {
        $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
        if ($null -ne $content) {
            foreach ($f in (Find-LongLinesInContent -Content $content -RelPath $Path -MaxLength $MaxLength)) {
                $allFindings.Add($f)
            }
        }
        return $allFindings
    }

    Push-Location $Path
    try {
        $gitFiles = git ls-files 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitFiles) {
            $files = $gitFiles | Where-Object { $_ -match '\.md$' }
        } else {
            Write-Warning "Not a git repo or git ls-files failed — scanning all .md files"
            $root = (Get-Location).Path
            $files = Get-ChildItem -Recurse -File |
                Where-Object { $_.Name -match '\.md$' } |
                ForEach-Object { $_.FullName.Substring($root.Length + 1) -replace '\\', '/' }
        }

        foreach ($rel in $files) {
            $content = Get-Content $rel -Raw -ErrorAction SilentlyContinue
            if ($null -eq $content) { continue }
            foreach ($f in (Find-LongLinesInContent -Content $content -RelPath $rel -MaxLength $MaxLength)) {
                $allFindings.Add($f)
            }
        }
    } finally {
        Pop-Location
    }

    return $allFindings
}

if ($MyInvocation.InvocationName -ne '.') {
    $allFindings = Get-LongMarkdownLineFindings -Path $Path -MaxLength $MaxLength

    if ($allFindings.Count -eq 0) {
        Write-Host "Clean: no markdown lines over $MaxLength chars in $Path"
        exit 0
    } else {
        foreach ($f in $allFindings) {
            Write-Host ("{0}:{1}: {2} chars (max {3})" -f $f.Path, $f.Line, $f.Length, $MaxLength)
        }
        exit 1
    }
}
