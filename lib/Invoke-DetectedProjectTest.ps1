# .SYNOPSIS
# The script Resolve-ProjectTestScript hands back for a project with no `test` of its own but a
# detected framework. Mirrors Test-PratLayer.ps1's 0/1/N shape one level down (frameworks in a
# project, not sub-targets in a repo): 1 detected runs it directly with -PassThru passed through;
# 2 force -PassThru on each and merge via Merge-TestSummary.

param($project, [hashtable]$CommandParameters = @{})

function Invoke-PytestWithSummary {
    param([string[]]$TestArgs, [string]$OutputDir, [string]$RepoRoot,
          [string]$WorkingDir, [switch]$NoCoverage, [switch]$PassThru)
    & "$PSScriptRoot/Invoke-PytestWithSummary.ps1" @PSBoundParameters
}

function Invoke-DotnetTestWithSummary {
    param([string[]]$TestArgs, [string]$OutputDir, [string]$RepoRoot, [string]$WorkingDir,
          [switch]$NoCoverage, [switch]$NoBuild, [string]$WorkspaceFile, [switch]$UseAlternateCollector, [switch]$PassThru)
    & "$PSScriptRoot/Invoke-DotnetTestWithSummary.ps1" @PSBoundParameters
}

$moduleRoot = $project.root -replace '\\', '/'

function runPytest([switch]$PassThru) {
    $testArgs = @()
    $focus    = $CommandParameters['Focus']
    if ($focus) {
        $expanded = (Expand-TildePath $focus) -replace '\\', '/'
        if ($expanded.StartsWith($moduleRoot + '/', 'InvariantCultureIgnoreCase')) {
            $testArgs += $expanded
        }
    }

    Invoke-PytestWithSummary `
        -RepoRoot   $moduleRoot `
        -WorkingDir $moduleRoot `
        -OutputDir  (Get-ProjectTestOutputDir $project) `
        -TestArgs   $testArgs `
        -NoCoverage:([bool]$CommandParameters['NoCoverage']) `
        -PassThru:$PassThru
}

function runDotnet([switch]$PassThru) {
    $testCsprojFiles = @(Get-ChildItem -LiteralPath $project.root -Recurse -Filter '*.Tests.csproj')
    if ($testCsprojFiles.Count -gt 1) {
        throw "Multiple *.Tests.csproj found under $($project.root) — register an explicit 'test' " +
              "script for this project instead of relying on auto-detection."
    }
    $testCsproj = $testCsprojFiles[0].FullName -replace '\\', '/'

    Invoke-DotnetTestWithSummary `
        -TestArgs      @($testCsproj) `
        -RepoRoot      $moduleRoot `
        -WorkingDir    $moduleRoot `
        -OutputDir     (Get-ProjectTestOutputDir $project) `
        -WorkspaceFile $project.workspaceFile `
        -NoCoverage:([bool]$CommandParameters['NoCoverage']) `
        -NoBuild:([bool]$CommandParameters['NoBuild']) `
        -UseAlternateCollector:([bool]$CommandParameters['UseAlternateCollector']) `
        -PassThru:$PassThru
}

$frameworks = @(Get-DetectedTestFrameworks $project.root)

if ($frameworks.Count -eq 0) {
    # Shouldn't happen — Resolve-ProjectTestScript only points here when a marker was found.
    # Only reachable if it's deleted between detection and invocation.
    throw "No pytest or dotnet test marker found under $($project.root)"
} elseif ($frameworks.Count -eq 1) {
    switch ($frameworks[0]) {
        'pytest' { runPytest -PassThru:([bool]$CommandParameters['PassThru']) }
        'dotnet' { runDotnet -PassThru:([bool]$CommandParameters['PassThru']) }
    }
} else {
    $startTime = [DateTimeOffset]::UtcNow
    $results = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($fw in $frameworks) {
        switch ($fw) {
            'pytest' { $results.Add((runPytest -PassThru)) }
            'dotnet' { $results.Add((runDotnet -PassThru)) }
        }
    }
    Merge-TestSummary $results.ToArray() ([DateTimeOffset]::UtcNow - $startTime) -PassThru:$CommandParameters['PassThru']
}
