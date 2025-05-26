[CmdletBinding()]
param($file)

if (!(Test-Path $file)) {
    throw "Not found: $file"
}

function GetTestContent($functions) {
    @"
BeforeAll {
    . `$PSCommandPath.Replace('.Tests.ps1','.ps1')
}


"@
    $first = $true
    foreach ($function in $functions) {
        if ($first) { $first = $false } else { "`n" }
        'Describe "' + $function + '" {' + "`n"
        @"
    It "" {
    }
}

"@
    }
}

function GetPathbinTestContent($command) {
    @"
Describe "$command" {
    It "" {
        $command 
    }
}

"@
}

function GetScriptTestContent($command) {
    @"
BeforeAll {
    `$scriptToTest = `$PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe "$command" {
    It "" {
        &`$scriptToTest
    }
}

"@
}

function IsPathbinFile($file) {
    return (Resolve-Path $file) -match '\\prat\\pathbin\\[^\\/]+$'
}

function GetTestFile($file) {
    if (IsPathbinFile $file) {
        $file = Join-Path (Split-Path $file) "tests" (Split-Path -Leaf $file)
    }
    return $file -replace "\.ps1$", ".Tests.ps1"
}

if ($file.EndsWith(".ps1")) {
    $testFile = GetTestFile $file
    if (Test-Path $testFile) {
        throw "Test file already exists: $testFile"
    }
    if (IsPathbinFile $file) {
        $command = Split-Path -LeafBase $file
        $testContent = GetPathbinTestContent $command
    } else {
        $functions = Get-Content $file | 
            Where-Object { $_ -match "function\s" } |
            ForEach-Object { $_ -replace '^\s*function\s+([^\s\(]+).*$', '$1' }

        # TODO: Detect scripts that aren't dot-sourceable. They can be made dot-sourceable by adding:
        #           if ($MyInvocation.InvocationName -ne ".") {

        if ($functions.Count -eq 0) {
            $command = Split-Path -LeafBase $file
            $testContent = GetScriptTestContent $command
        } else {
            $testContent = GetTestContent $functions
        }
    }

    $testContent = $testContent -join ''
    New-Item -Path $testFile -ItemType File -Value $testContent | Out-Null
    Write-Host "Created: $testFile"
    return
}

throw "Unrecognized file type: $file"