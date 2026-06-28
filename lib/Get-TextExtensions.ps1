# .SYNOPSIS
# Returns the regex alternation string of text file extensions scanned by prat tools
# (Find-LayerViolations, Find-SensitiveData). Use as: $_ -match "\.($exts)$"
return 'ps1|md|txt|json|yaml|yml|ini|cfg|sh|bat|cmd|py'
