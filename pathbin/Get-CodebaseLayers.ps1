# .SYNOPSIS
# Get an array of dev-environment descriptions.
# This base one just describes Prat itself, but this is an extension mechanism
# for layering on other environments for a specific person or organization, so that
# they can override default prat behavior - such as the profile script (i.e. pwsh startup script),
# or shortcuts.

return @(
    @{
        Name = 'prat'
        Path = Split-Path -Parent $PSScriptRoot
    }
)