# Prat's powershell profile file is 'interactiveProfile.ps1'.
# But it can be overridden by installing a particular file. This allows a customized profile to:
# - do some things (e.g. add to $env:path) before starting Prat's profile
# - do some things after running Prat's profile, that depend on things it loads (e.g. PratBase.psd1)
# - replace Prat's profile entirely (e.g. it installs something the user doesn't want, and doesn't yet provide enough fine-grained control).

$overrideProfile = "$PSScriptRoot\..\..\auto\profile\overrideProfile.ps1"
if (Test-Path $overrideProfile) {
    . $overrideProfile
} else {
    . $PSScriptRoot\interactiveProfile.ps1
}

