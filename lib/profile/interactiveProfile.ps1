# This is called by %userprofile%\Documents\[Windows]Powershell\profile.ps1

. $PSScriptRoot\scriptProfile.ps1

# The remaining, 'interactive' part of this profile, is for "user interface" elements that aren't useful in scripting/automation.
# Examples:
# - set aliases like 'b'
# - install tools like 'ditto'
# - set prompt

pratProfile_trace "interactiveProfile.ps1 starting"

New-Alias stack "$PSScriptRoot\..\Get-StackTraceForLastException.ps1" -Description "Get the PS stack trace of the last exception"

function pratSetWindowTitle($extraContext) {
    if ($extraContext -eq $null) {
        $ec = ""
    } else {
        $ec = ": $extraContext"
    }

    if (Get-CurrentUserIsElevated) {
        # This is a handy warning, because I do NOT recommend running this way often, because many things go wrong. Examples:
        # - any windows app you launch, launches elevated
        # - ... which can lead to 2 instances of an app running that wants to be single-instance (e.g. SlickEdit; e.g. Microsoft Word)
        # - if you create a file (either from the console or from an app you launched from it), the file owner will be 'Administrators' instead of you.
        # - e.g. if you "git clone" a repo from this state, you'll get a git security, warning about the owner not being you.

        $elev = "Administrator: "
    } else {
        $elev = ""
    }
    pratProfile_trace "start: GetHostName"
    $hostname = [System.Net.Dns]::GetHostName()
    pratProfile_trace "end: GetHostName"

    $host.ui.rawui.WindowTitle = "$elev$hostname$ec"
}

pratProfile_trace "start: Set window title"
pratSetWindowTitle
pratProfile_trace "end: Set window title"

cd $env:userprofile


# For 'prompt' function: Call a hook script if the current location has changed
function pratDetectLocationChange {
    $location = (Get-Location).Path
    if (($global:__prat_lastPromptLocation -eq $null) -or ($global:__prat_lastPromptLocation -ne $location)) {
        &$PSScriptRoot\..\On-PromptLocationChanged $location $global:__prat_lastPromptLocation
        $global:__prat_lastPromptLocation = $location
    }
}

. $PSScriptRoot\slowCommandFunctions.ps1

function prompt {
    $lastCommandErrorStatus = $?
    try
    {
        displayLastCommandTime
        reportOnSlowCommands $lastCommandErrorStatus

        pratDetectLocationChange
    } catch { Write-Warning ("Exception during prompt: " + $Error[0] + "`n" + (stack)) }

    # $global:__prat_currentLocation is maintained by On-PromptLocationChanged.ps1
    return $global:__prat_notifications + $global:__prat_currentLocation + "`n> "
}

. $PSScriptRoot\Define-ShortcutFunctions.ps1
if (Test-Path alias:ls) { del alias:ls }


# Customize 'dir' output - better output format for 'length' column:
Update-FormatData -PrependPath $PSScriptRoot\FileSystem.format.ps1xml

pratProfile_trace "Done: Update-FormatData"

New-Alias -Name b -Value Build-Codebase -Scope Global
New-Alias -Name t -Value Test-Codebase -Scope Global
New-Alias -Name d -Value Deploy-Codebase -Scope Global
New-Alias -Name x -Value Start-CodebaseDevLoop -Scope Global

pratProfile_trace "interactiveProfile.ps1 ending"

