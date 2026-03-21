param($project, [hashtable]$CommandParameters = @{})

$repoRoot = if ($CommandParameters.ContainsKey('RepoRoot')) {
    $CommandParameters['RepoRoot']
} else {
    $project.root
}
$pathToTest = &"$HOME/prat/lib/Resolve-TestFocus" $CommandParameters['Focus'] $repoRoot
Invoke-PesterWithCodeCoverage `
    -NoCoverage:$CommandParameters['NoCoverage'] `
    -PathToTest $pathToTest `
    -RepoRoot $repoRoot `
    -Debugging:$CommandParameters['Debugging'] `
    -OutputDir $CommandParameters['OutputDir'] `
    -IncludeIntegrationTests:$CommandParameters['IncludeIntegrationTests'] `
    -Integration:$CommandParameters['Integration']
