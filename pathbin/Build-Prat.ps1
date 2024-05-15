# Prat doesn't have a 'build' step per se, but for prat development,
# it helps to manually unload modules.
# 
# Caveat: This doesn't remove classes, like LineArray and InstallationTracker. For iterating on those, the only way I know is to start a new
#         PS session.

Remove-Module Installers -ErrorAction SilentlyContinue
Remove-Module TextFileEditor -ErrorAction SilentlyContinue
Remove-Module PratBase -ErrorAction SilentlyContinue

