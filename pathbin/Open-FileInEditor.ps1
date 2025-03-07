# .SYNOPSIS
# Opens a file in your favorite editor.
#
# Alias: e
#
# .NOTES
# I'm trying vscode (previously was using SlickEdit).
#
# .EXAMPLE
# e log.txt
#
# .EXAMPLE
# e (wh Get-TextFileEncoding)
try {
    code @args
} catch {
    # We'll assume the error is that the editor isn't installed, and use notepad instead.
    Write-Host -ForegroundColor Red $Error[0]
    Write-Host -ForegroundColor Yellow "Falling back to notepad."
    notepad @args
}


