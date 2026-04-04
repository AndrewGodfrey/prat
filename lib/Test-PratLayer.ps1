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
$pathToTest = &"$HOME/prat/lib/Resolve-TestFocus" $CommandParameters['Focus'] $repoRoot
Invoke-PesterWithSummary `
    -NoCoverage:$CommandParameters['NoCoverage'] `
    -PathToTest $pathToTest `
    -RepoRoot $repoRoot `
    -OutputDir $CommandParameters['OutputDir'] `
    -IncludeIntegrationTests:$CommandParameters['IncludeIntegrationTests'] `
    -Integration:$CommandParameters['Integration'] `
    -UseAlternateCollector:$CommandParameters['UseAlternateCollector'] `
    -PassThru:$CommandParameters['PassThru']
