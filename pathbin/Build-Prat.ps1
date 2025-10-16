# Prat doesn't have a 'build' step per se, but for prat development,
# it helps to manually unload modules.
# 
# Caveat: This doesn't remove classes, like LineArray and InstallationTracker. For iterating on those:
#         - unit tests: That's solved by Invoke-PesterAsJob
#         - manual testing: The only way I know, is to move to a new PS session.

$modules = "Installers", "TextFileEditor", "PratBase"
Write-Host -ForegroundColor Green "Removing modules: $($modules -join ", ")"
$modules | ForEach-Object {Remove-Module $_ -ErrorAction SilentlyContinue}

# OmitFromCoverageReport: a unit test would just restate it