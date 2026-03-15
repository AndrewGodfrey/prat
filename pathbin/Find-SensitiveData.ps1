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
    [string] $Path = (Get-Location).Path
)

function Find-SensitiveDataInContent {
    param (
        [string] $Content,
        [string] $RelPath,
        [string] $HomeDir
    )

    $findings = [System.Collections.Generic.List[string]]::new()

    if ($Content -match [regex]::Escape($HomeDir)) {
        $findings.Add("hardcoded home path: $RelPath")
    }
    if ($Content -match '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}') {
        $findings.Add("email address: $RelPath")
    }
    if ($Content -match '\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b') {
        $findings.Add("IP address: $RelPath")
    }

    return $findings
}

# Only run main logic when invoked directly (not dot-sourced for testing)
if ($MyInvocation.InvocationName -ne '.') {
    $textExtensions = 'ps1|md|txt|json|yaml|yml|ini|cfg|sh|bat|cmd'

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

        $homeDir = (Get-Item $home).FullName  # normalize to real path, no trailing slash
        $allFindings = [System.Collections.Generic.List[string]]::new()

        foreach ($rel in $files) {
            $content = Get-Content $rel -Raw -ErrorAction SilentlyContinue
            if ($null -eq $content) { continue }
            foreach ($f in (Find-SensitiveDataInContent -Content $content -RelPath $rel -HomeDir $homeDir)) {
                $allFindings.Add($f)
            }
        }

        if ($allFindings.Count -eq 0) {
            Write-Host "Clean: no sensitive data found in $Path"
            exit 0
        } else {
            foreach ($f in $allFindings) {
                Write-Host "FOUND: $f"
            }
            exit 1
        }
    } finally {
        Pop-Location
    }
}
