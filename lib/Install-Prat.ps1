<#
  Installs Prat to $home\prat, and then runs its build/test/deploy loop once.
 
  See ..\README.md for installation instructions.
#>
param([switch] $PauseForManualTesting, [switch] $SkipDeployStep)

# winget is supposed to be included in Win10 now. And seems to have been removed from the Windows Store.
# But I found it not to be present even on a newly-downloaded ISO (downloaded on 20240419).
# 
# https://github.com/microsoft/winget-cli/issues/1793
# https://github.com/microsoft/winget-cli/discussions/1738#discussioncomment-5484927
if ((where.exe winget) -eq $null) { 
    Write-Warning @"
winget isn't installed. This is sadly 'by design' for new installs of Windows.
The 'official workaround' seems to be: 
    1. Open Microsoft store
    2. click '... > Downloads and Updates'. (Or if the Microsoft Store app has already updated, instead go to 'Library'
    3. Either click 'Get Updates' and wait for all the packages to update. Or you can specifically update "App Installer".
"@
    throw "winget isn't installed" 
}

if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    # Although on Windows we (sadly) do need to elevate to install some things (git, Pester), there are many things we do NOT want to do elevated.
    # For example
    # - "git clone" will set the directory owner to "Administrators" instead of the current user, triggering a git security warning.
    # - Any app we launch will launch as administrator, and any files that app creates for the user will similarly have the wrong owner.
    throw "Don't run as administrator"
}

$gitDir="c:\Program Files\git\bin" # Note: This is the install location for both Git.Git and Microsoft.Git. So, if one of those is already installed, we'll just use that. I've tried "--scope user", but Git.Git ignores it.
$git="$gitdir\git.exe"
if (!(Test-Path $git)) { winget install --id=Git.Git --exact --silent --accept-source-agreements }
if (!(Test-Path $git)) { throw "git installation failed" }
$env:path += ";$gitDir" # The git package adds itself to PATH in the registry, but not in the current execution environment.

$target = $home + "\prat"
$source = "https://github.com/AndrewGodfrey/prat.git"
if (!(Test-Path $target)) { git clone $source $target }
if ($lastExitCode -ne 0) { throw "'git clone prat' failed: $lastExitCode" }
if (!(Test-Path $target)) { throw "'git clone prat' failed" }

pushd $target
try {
    if ($PauseForManualTesting) { pause }
    # Now we can pass control to a "phase 2" script running out of the git repo.
    
    # Dot-source it, in hope of getting a semi-decent profile setup when the script finishes (or while I'm debugging it).
    . $home\prat\lib\Install-PratPhase2.ps1 -SkipDeployStep:$SkipDeployStep
} finally {
    popd
}

