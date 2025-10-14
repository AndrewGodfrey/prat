# This is called by %userprofile%\Documents\[Windows]Powershell\profile.ps1

pratProfile_trace start "interactiveProfile_prat.ps1"

. $PSScriptRoot\scriptProfile.ps1

# The remaining, 'interactive' part of this profile, is for "user interface" elements that aren't useful in scripting/automation.
# Examples:
# - set aliases like 'b'
# - install tools like 'ditto'
# - set prompt

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

cd $env:userprofile


# For 'prompt' function: Call a hook script if the current location has changed
function pratDetectLocationChange {
    $location = (Get-Location).Path
    if (($null -eq $global:__prat_lastPromptLocation) -or ($global:__prat_lastPromptLocation -ne $location)) {
        &$PSScriptRoot\..\On-PromptLocationChanged $location $global:__prat_lastPromptLocation
        $global:__prat_lastPromptLocation = $location
    }
}

. $PSScriptRoot\slowCommandFunctions.ps1

function contextPath {
    if ($null -eq $env:__prat_contextPath) { return "" }
    if ("" -eq $env:__prat_contextPath) { return "" }
    return "[[ENV: " + $env:__prat_contextPath + "]] "
}

function getPsversionString {
    if ($psversiontable.PSEdition -eq 'Core') { return "" }
    return "[PS $($psversiontable.PSEdition) v$($psversiontable.PSVersion.Major)] "
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
            $historyInfo = Get-History -Count 1
            $duration = getLastCommandTime $historyInfo
            $testFocus = Get-TestFocus
            $testFocusNotifier = ""
            if ($testFocus -ne $null) {
                $testFocusNotifier = " [TestFocus: $testFocus]"
            }
            displayLastCommandTime $duration
            reportOnSlowCommands $duration $historyInfo $lastCommandErrorStatus

            pratDetectLocationChange
            $ver = getPsversionString
        } catch { Write-Warning ("Exception during prompt: " + $Error[0] + "`n" + (stack)) }

        # $global:__prat_currentLocation is maintained by On-PromptLocationChanged.ps1
        return $global:__prat_notifications + (contextPath) + $ver + $global:__prat_currentLocation + "$testFocusNotifier`n> "
    }
}

. $PSScriptRoot\Define-ShortcutFunctions.ps1
pratProfile_trace done "Define-ShortcutFunctions"

if (Test-Path alias:ls) { del alias:ls }

# Customize 'dir' output - better output format for 'length' column:
Update-FormatData -PrependPath $PSScriptRoot\FileSystem.format.ps1xml
pratProfile_trace done "Update-FormatData"

New-Alias -Name pb -Value Prebuild-Codebase -Scope Global
New-Alias -Name b -Value Build-Codebase -Scope Global
New-Alias -Name t -Value Test-Codebase -Scope Global
New-Alias -Name d -Value Deploy-Codebase -Scope Global
New-Alias -Name x -Value Start-CodebaseDevLoop -Scope Global
New-Alias -Name c -Value Set-LocationUsingShortcut -Scope Global
New-Alias -Name ow -Value Open-CodebaseWorkspace -Scope Global
New-Alias -Name gtfe -Value Get-TextFileEncoding -Scope Global
New-Alias -Name gll -Value GitLog-Local -Scope Global
New-Alias -Name glp -Value GitLog-Pretty -Scope Global
New-Alias -Name e -Value Open-FileInEditor -Scope Global
New-Alias -Name lsl -Value Get-LatestFiles -Scope Global
New-Alias -Name ude -Value Update-DevEnvironment -Scope Global
New-Alias -Name ch -Value Compare-Hash -Scope Global
New-Alias -Name aext -Value Analyze-FileExtensions -Scope Global
New-Alias -Name filever -Value Get-FileVersionInfo -Scope Global
New-Alias -Name hex -Value Format-NumberAsHex -Scope Global
New-Alias -Name ec -Value Enter-Codebase -Scope Global
New-Alias -Name pt -Value Push-UnitTestDirectory -Scope Global
New-Alias -Name on -Value Invoke-InlineCommandOnHost -Scope Global
New-Alias -Name stf -Value Set-TestFocus -Scope Global

pratProfile_trace end "interactiveProfile_prat.ps1"
