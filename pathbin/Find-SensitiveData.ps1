# .SYNOPSIS
# Scan a repo for sensitive data that shouldn't be in a public repo.
#
# .DESCRIPTION
# Checks tracked files (via git ls-files) for patterns indicating sensitive data:
# hardcoded home paths, email addresses, IP addresses.
#
# Exits with code 1 if any findings are reported. Use before finalizing a feature
# branch or committing to a public repo like prat or prefs.
#
# .PARAMETER Path
# Root of the git repo to scan. Defaults to current directory.

param (
    [string] $Path = (Get-Location).Path,
    [int]    $MaxFoundLines = 3
)

function safeIpAddress($ipString) {
    if ($ipString -in @("127.0.0.1", "1.1.1.1")) { return $true }
    if ($ipString.StartsWith("192.168.") -or $ipString.StartsWith("10.")) { return $true }
    [int] $first = [int] ($ipString -split '\.')[0]
    if ($first -lt 10) { return $true }
    return $false
}

function Find-SensitiveDataInContent {
    param (
        [string] $Content,
        [string] $RelPath,
        [string] $HomeDir,
        [int]    $MaxFoundLines = 3
    )

    $findings = [System.Collections.Generic.List[string]]::new()
    $lines = $Content -split '\r?\n'

    function fmtLines($nums) {
        $shown = @($nums | Select-Object -First $MaxFoundLines)
        $extra = $nums.Count - $shown.Count
        $suffix = if ($extra -gt 0) { " and $extra more" } else { "" }
        "(line $(($shown) -join ', ')$suffix)"
    }

    $homeNums = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match [regex]::Escape($HomeDir)) { $homeNums.Add($i + 1) }
    }
    if ($homeNums.Count -gt 0) { $findings.Add("hardcoded home path $(fmtLines $homeNums): $RelPath") }

    $emailPat = '([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'
    $emailNums = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $emailPat -and -not $Matches[1].EndsWith("@example.com")) {
            $emailNums.Add($i + 1)
        }
    }
    if ($emailNums.Count -gt 0) { $findings.Add("email address $(fmtLines $emailNums): $RelPath") }

    $ipPat = '\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b'
    $ipNums = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $ipPat -and -not (safeIpAddress $Matches[1])) {
            $ipNums.Add($i + 1)
        }
    }
    if ($ipNums.Count -gt 0) { $findings.Add("IP address $(fmtLines $ipNums): $RelPath") }

    $dePlansNums = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '[\\/]de[\\/]plans') { $dePlansNums.Add($i + 1) }
    }
    if ($dePlansNums.Count -gt 0) { $findings.Add("de/plans reference (private repo path) $(fmtLines $dePlansNums): $RelPath") }

    return $findings
}

function Get-SensitiveDataFindings {
    param(
        [string] $Path,
        [string] $HomeDir = (Get-Item $home).FullName,
        [int]    $MaxFoundLines = 3
    )

    $textExtensions = 'ps1|md|txt|json|yaml|yml|ini|cfg|sh|bat|cmd'
    $allFindings = [System.Collections.Generic.List[string]]::new()

    if (Test-Path $Path -PathType Leaf) {
        $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
        if ($null -ne $content) {
            $rel = Split-Path $Path -Leaf
            foreach ($f in (Find-SensitiveDataInContent -Content $content -RelPath $rel -HomeDir $HomeDir -MaxFoundLines $MaxFoundLines)) {
                $allFindings.Add($f)
            }
        }
    } else {
        Push-Location $Path
        try {
            $gitFiles = git ls-files 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitFiles) {
                $files = $gitFiles | Where-Object { $_ -match "\.($textExtensions)$" }
            } else {
                Write-Warning "Not a git repo or git ls-files failed — scanning all text files"
                $files = Get-ChildItem -Recurse |
                    Where-Object { $_.Name -match "\.($textExtensions)$" } |
                    ForEach-Object { $_.FullName.Substring($Path.Length + 1) }
            }

            foreach ($rel in $files) {
                $content = Get-Content $rel -Raw -ErrorAction SilentlyContinue
                if ($null -eq $content) { continue }
                foreach ($f in (Find-SensitiveDataInContent -Content $content -RelPath $rel -HomeDir $HomeDir -MaxFoundLines $MaxFoundLines)) {
                    $allFindings.Add($f)
                }
            }
        } finally {
            Pop-Location
        }
    }

    return $allFindings
}

# Only run main logic when invoked directly (not dot-sourced for testing)
if ($MyInvocation.InvocationName -ne '.') {
    $homeDir = (Get-Item $home).FullName  # normalize to real path, no trailing slash
    $allFindings = Get-SensitiveDataFindings -Path $Path -HomeDir $homeDir -MaxFoundLines $MaxFoundLines

    if ($allFindings.Count -eq 0) {
        Write-Host "Clean: no sensitive data found in $Path"
        exit 0
    } else {
        foreach ($f in $allFindings) {
            Write-Host "FOUND: $f"
        }
        exit 1
    }
}
