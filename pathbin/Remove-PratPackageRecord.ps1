# .SYNOPSIS
# Remove a record from the prat installation database, forcing it to re-run on the next 'd'.
#
# .PARAMETER StepId
# The step ID to remove, e.g. 'localAgentSandbox/andrew_agent'.

param(
    [Parameter(Mandatory, Position=0)] [string] $StepId
)

Import-Module "$PSScriptRoot/../lib/Installers/Installers.psd1"
Remove-InstalledItem "$home\prat\auto\instDb" $StepId
