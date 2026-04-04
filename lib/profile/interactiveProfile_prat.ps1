# This is called by %userprofile%\Documents\[Windows]Powershell\profile.ps1

pratProfile_trace start "interactiveProfile_prat.ps1"

. $PSScriptRoot\scriptProfile.ps1

# The remaining, 'interactive' part of this profile, is for "user interface" elements that aren't useful in scripting/automation.
# Examples:
# - set aliases like 'b'
# - install tools like 'ditto'
# - set prompt

$interactiveAliasFile = "$_pratroot\auto\profile\interactiveAliases.ps1"
if (Test-Path $interactiveAliasFile) { Import-PratAliases $interactiveAliasFile }
pratProfile_trace done "Installed interactive aliases"

New-Alias stack "$PSScriptRoot\..\Get-StackTraceForLastException.ps1" -Description "Get the PS stack trace of the last exception"

function pratSetWindowTitle($extraContext) {
    $contextPath = ""
    if ($null -eq $extraContext) {
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
    pratProfile_trace start "GetHostName"
    $hostname = [System.Net.Dns]::GetHostName()
    pratProfile_trace end "GetHostName"

    $host.ui.rawui.WindowTitle = "$elev$hostname$ec"
}

pratProfile_trace start "Set window title"
pratSetWindowTitle
pratProfile_trace end "Set window title"

# For 'prompt' function: Call a hook script if the current location has changed
function pratDetectLocationChange {
    $location = (Get-Location).Path
    if (($null -eq $global:__prat_lastPromptLocation) -or ($global:__prat_lastPromptLocation -ne $location)) {
        &$PSScriptRoot\..\On-PromptLocationChanged $location $global:__prat_lastPromptLocation
        $global:__prat_lastPromptLocation = $location
    }
}

. $PSScriptRoot\slowCommandFunctions.ps1

function pratCheckStaleModules {
    if (pratTestModulesStale $global:__prat_moduleHashesAtStart) {
        $global:__prat_notifications = "[stale modules - run 'rs' to refresh] "
    } else {
        # Clear if previously set. Note: clears the whole string — would need
        # revisiting if other notification types are added.
        if ($global:__prat_notifications -like "*stale modules*") {
            $global:__prat_notifications = ""
        }
    }
}

function contextPath {
    if ($null -eq $env:__prat_contextPath) { return "" }
    if ("" -eq $env:__prat_contextPath) { return "" }
    return "[[ENV: " + $env:__prat_contextPath + "]] "
}

function getPsversionString {
    if ($psversiontable.PSEdition -eq 'Core') { return "" }
    return "[PS $($psversiontable.PSEdition) v$($psversiontable.PSVersion.Major)] "
}

function getUserString {
    if ($env:USERNAME.EndsWith("_agent")) { return "🔐 " }
    return ""
}

# Custom Powershell prompt.
#
# But, avoid customizing it in the vscode terminal. When you debug Pester tests in vscode,
# it somehow manages to call the prompt (most of the time).
# Which means breakpoints in things the prompt uses, get hit when debugging unit tests.
if ($env:TERM_PROGRAM -ne "vscode") { 
    function prompt {
        $lastCommandErrorStatus = $?
        try
        {
            # This mostly works around an output glitch in Windows Terminal, where the progress info isn't cleared before the prompt is written.
            Write-Progress -Completed

            $historyInfo = Get-History -Count 1
            $duration = getLastCommandTime $historyInfo
            displayLastCommandTime $duration
            reportOnSlowCommands $duration $historyInfo $lastCommandErrorStatus

            pratDetectLocationChange
            pratCheckStaleModules
            $ver = getPsversionString
            $user = getUserString
        } catch { Write-Warning ("Exception during prompt: " + $Error[0] + "`n" + (stack)) }

        # $global:__prat_currentLocation is maintained by On-PromptLocationChanged.ps1
        return $global:__prat_notifications + $user + (contextPath) + $ver + $global:__prat_currentLocation + "`n> "
    }
}

<#
.SYNOPSIS
    Simulates restarting the shell by replacing it with a fresh one.
.DESCRIPTION
    Effectively: Exits the current shell and opens a new one in its place, so profile changes and updated
    modules take effect without closing the terminal window. The working directory and window
    are preserved; unsaved in-memory state (variables, loaded modules) is not.

    In reality: On the first invocation for a given shell, simply starts a new 'inner one', inside a loop which
    will exit the outer shell, if the user exits the inner one.

    Then, subsequent invocations do actually "exit the current shell and open a new one".
#>
function global:Restart-Shell {
    # Exit-199 protocol: depth-1 shells signal their parent (the loop controller) to restart them.
    # The loop controller records its PID so nested shells spawned by things like Enter-Codebase
    # (which inherit depth=1 but have no loop controller above them) can detect the mismatch at
    # startup and reset their depth, becoming independent loop controllers if rs is invoked.
    if ($env:__prat_shellDepth -eq '1') {
        exit 199
    }
    $env:__prat_shellDepth = '1'
    $env:__prat_loopControllerPid = $pid
    do {
        pwsh -NoLogo
    } while ($LASTEXITCODE -eq 199)
    exit
}

. $PSScriptRoot\Define-ShortcutFunctions.ps1
pratProfile_trace done "Define-ShortcutFunctions"

if (Test-Path alias:ls) { del alias:ls }

# Customize 'dir' output - better output format for 'length' column:
Update-FormatData -PrependPath $PSScriptRoot\FileSystem.format.ps1xml
pratProfile_trace done "Update-FormatData"

pratProfile_trace end "interactiveProfile_prat.ps1"
