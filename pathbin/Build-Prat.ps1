# Prat doesn't have a 'build' step per se, but for prat development,
# it helps to manually unload modules.
# 
# Caveat: This doesn't remove classes, like LineArray and InstallationTracker. For iterating on those, the only way I know is to start a new
#         PS session.

function remove($module) {
    Write-Host -ForegroundColor Green "Removing: $module"
    Remove-Module $module -ErrorAction SilentlyContinue
}
"Installers", "TextFileEditor", "PratBase" | ForEach-Object {remove $_}
