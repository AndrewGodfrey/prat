# .SYNOPSIS
# Open-FileInEditor (alias: e)
# For opening in your favorite editor.
#
# I'm trying vscode (previously was using SlickEdit).
try {
    code @args
} catch {
    # We'll assume the error is that the editor isn't installed, and use notepad instead.
    Write-Host -ForegroundColor Red $Error[0]
    Write-Host -ForegroundColor Yellow "Falling back to notepad."
    notepad @args
}


