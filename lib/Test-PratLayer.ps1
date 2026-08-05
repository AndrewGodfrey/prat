# .SYNOPSIS
# Default `test` dispatcher: runs Pester plus any sub-targets in other frameworks that overlap the
# focus (see Get-PratTestTargetsUnder), merging results. With no sub-targets (the common case), this
# is exactly a plain Pester run — Get-TestDispatch always resolves to "no targets, run Pester".

param($project, [hashtable]$CommandParameters = @{})

function Invoke-PesterWithSummary {
    param([switch]$NoCoverage, $PathToTest, $RepoRoot, $OutputDir,
          [switch]$IncludeIntegrationTests, [switch]$Integration, [switch]$UseAlternateCollector, [switch]$PassThru)
    & "$PSScriptRoot/Invoke-PesterWithSummary.ps1" @PSBoundParameters
}

$repoRoot = if ($CommandParameters.ContainsKey('RepoRoot')) {
    $CommandParameters['RepoRoot']
} else {
    $project.root
}
$repoRoot   = $repoRoot -replace '\\', '/'
$outputDir  = if ($CommandParameters['OutputDir']) { $CommandParameters['OutputDir'] } else { Get-ProjectTestOutputDir $project }
$pathToTest = &"$HOME/prat/lib/Resolve-TestFocus" $CommandParameters['Focus'] $repoRoot

# Mirrors Pester's own default discovery (Run.TestExtension = '.Tests.ps1', recursive) — keep the
# two in step. Sub-target roots are deliberately not excluded: Pester collects those too when given
# an ancestor path.
function focusHasPesterTests($path) {
    $null -ne (Get-ChildItem $path -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue |
                Select-Object -First 1)
}

$subTargets = @(Get-PratTestTargetsUnder $repoRoot)
# Only worth the scan (3ms for a small subtree, ~130ms for a whole repo) when there is a sub-target
# that could run instead; Get-TestDispatch ignores the answer otherwise.
$hasPesterTests = ($subTargets.Count -eq 0) -or (focusHasPesterTests $pathToTest)
$dispatch   = Get-TestDispatch $pathToTest $subTargets $hasPesterTests

if ($subTargets.Count -eq 0) {
    # No sub-targets — same plain Pester dispatch as before subproject aggregation existed.
    Invoke-PesterWithSummary `
        -NoCoverage:$CommandParameters['NoCoverage'] `
        -PathToTest $pathToTest `
        -RepoRoot $repoRoot `
        -OutputDir $outputDir `
        -IncludeIntegrationTests:$CommandParameters['IncludeIntegrationTests'] `
        -Integration:$CommandParameters['Integration'] `
        -UseAlternateCollector:$CommandParameters['UseAlternateCollector'] `
        -PassThru:$CommandParameters['PassThru']
} else {
    function withPassThru([hashtable]$cp) { $h = $cp.Clone(); $h['PassThru'] = $true; $h }

    $startTime = [DateTimeOffset]::UtcNow
    $results = [System.Collections.Generic.List[hashtable]]::new()

    if ($dispatch.RunPester) {
        $results.Add((Invoke-PesterWithSummary `
            -NoCoverage:$CommandParameters['NoCoverage'] `
            -PathToTest $pathToTest `
            -RepoRoot $repoRoot `
            -OutputDir $outputDir `
            -IncludeIntegrationTests:$CommandParameters['IncludeIntegrationTests'] `
            -Integration:$CommandParameters['Integration'] `
            -UseAlternateCollector:$CommandParameters['UseAlternateCollector'] `
            -PassThru))
    }
    foreach ($target in $dispatch.Targets) {
        $results.Add((& $target.test $target -CommandParameters:(withPassThru $CommandParameters)))
    }

    Merge-TestSummary $results.ToArray() ([DateTimeOffset]::UtcNow - $startTime) -PassThru:$CommandParameters['PassThru']
}
