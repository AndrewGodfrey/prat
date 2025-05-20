function hasTests() {
    return (Get-ChildItem -r *.tests.ps1).Count -ne 0
}

function runTests($name) {
    $line = "=" * $name.Length
    Write-Host -ForegroundColor Cyan "`n`n$line`n$name`n$line`n"
    Start-CodebaseDevLoop
}

foreach ($a in (Get-ChildItem -Directory)) { 
    Push-Location $a.FullName
    try {
        if (hasTests) {
            runTests $a.Name
        }
    }
    finally {
        Pop-Location 
    }
}
