[CmdletBinding()]
param($file)

if (!(Test-Path $file)) {
    throw "Not found: $file"
}

if ($file.EndsWith(".ps1")) {
    $testFile = $file -replace "\.ps1$", ".Tests.ps1"
    if (Test-Path $testFile) {
        throw "Test file already exists: $testFile"
    }

    $functions = Get-Content $file | 
        Where-Object { $_ -match "function\s" } |
        ForEach-Object { $_ -replace '^\s*function\s+([^\s\(]+).*$', '$1' }

    if ($functions.Count -eq 0) {
        throw "No functions found in $file"
    }

    # TODO: Detect scripts aren't dot-sourceable. Ones which define functions will get past
    #       the check above. They can be made dot-sourceable by adding:
    #           if ($MyInvocation.InvocationName -ne ".") {

    Write-Debug "Functions found: $($functions -join ", ")"

    $testContent = @"
BeforeAll {
    . `$PSCommandPath.Replace('.Tests.ps1','.ps1')
}


"@

    $first = $true
    foreach ($function in $functions) {
        if ($first) { $first = $false } else { $testContent += "`n" }
        $testContent += 'Describe "' + $function + '" {' + "`n"
        $testContent += @"
    It "" {
    }
}

"@
    }

    New-Item -Path $testFile -ItemType File -Value $testContent | Out-Null
    Write-Host "Created: $testFile"
    return
}

throw "Unrecognized file type: $file"

