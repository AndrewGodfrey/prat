# Prat doesn't have a 'build' step per se, but for prat development,
# it helps to manually unload and reload modules.
#
# Caveat: This doesn't remove classes, like LineArray and InstallationTracker. For iterating on those:
#         - unit tests: That's solved by Invoke-PesterAsJob
#         - manual testing: The only way I know, is to move to a new PS session.

$modules = "Installers", "TextFileEditor", "PratBase"
Write-Progress 'Build-Prat' "Removing modules"
$modules | ForEach-Object {Remove-Module $_ -ErrorAction SilentlyContinue}

Write-Progress 'Build-Prat'  "Reimporting PratBase"
Import-Module "$PSScriptRoot/../lib/PratBase/PratBase.psd1"

# Remove-Module also clears aliases the module created (even -Scope Global ones), so restore them.
foreach ($aliasFile in @("scriptAliases.ps1", "interactiveAliases.ps1")) {
    $path = "$PSScriptRoot/../auto/profile/$aliasFile"
    if (Test-Path $path) { Import-PratAliases $path }
}

# OmitFromCoverageReport: a unit test would just restate it, and the extreme hackery of module unloading ... needs to be replaced.