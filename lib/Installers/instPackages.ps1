using module ..\PratBase\PratBase.psd1
using module ..\TextFileEditor\TextFileEditor.psd1


# There are so many package managers. Let's make another one!
#
# Requirements:
#   1. Non-interactive: For some reason, many packages (and package managers!) think it's appropriate to ask the 'user' a question.
#      All of these need to be suppressed.
#   2. Speed: Incremental development requires that "nothing to do" cases are very quick. Speed is also desirable given the 'cattle not pets' philosophy
#      - for packages this means: avoid depending on uninstallers; prefer to reset and rebuild.
#   3. Reliability and availability: The typical approach is to apply 'latest' and if it breaks anything, to discover and resolve that manually.
#      IMO this needs to be automated, keeping the target system working (pinning to the last-known-good version) until resolved.
#   4. Recency: Pinning indefinitely to a known-good version, works in the short term but eventually fails, for many reasons.
#      So the system should resist long-term pinning. (If a dependency has gone in a bad direction permanently, then it's time for a fork).
#   5. Abstraction: Keep in one place the 'boring' package-specific information, e.g.:
#     - Which package manager should we use?
#     - Does it need additional parameters to make it automatic? (Things like accepting licenses, acknowledging an upgrade)
#     - nuget (and many others) adds itself to PATH in the registry, but not in the currently-running environment. (Some other packages also
#       update the currently-running environment, but many don't). This breaks scripts; we can work around this here.
#     - Some packages make huge breaking changes from one major version to another. For those, auto-updating logic may need to focus on minor version #.
#     - Later, I might re-encounter the need for multiple side-by-side versions (of a package which supports that). In such cases you need
#       some way of picking which one to invoke. One way is to know its installation path, which isn't provided and doesn't follow any rigid convention.
#   6. Known, validated package install location.
#      winget on its own, lacks this. It assumes the installer knows how to 'hook up' the package to my environment. Problems with that:
#      - The "obvious" deal-breaker: They don't know how to integrate themselves with Prat, so that they get installed on every dev-environment machine.
#      - Just noting: Some packages update PATH in the registry, but not in the current environment. Some don't update PATH at all (or maybe try and silently fail).
#
# Thoughts:
#   - I'm aware that Powershell already has a "package manager manager" in Install-Package. Based on past experience, I expect this code to use 
#     winget directly, and nuget directly, and occasionally Install-Package. If Install-Package were to improve to meet all the requirements,
#     I wouldn't complain! But that seems like a tall order - much more work than I have to do here (because I can ignore packages I don't use).
#
#   - Local caching of packages is highly desirable, but NYI. I had a look at winget's support for caching, and it seems unduly complicated. I expect to need caching
#     eventually. Here are some reasons it's so desirable:
#     - Another 'availability' risk is that a version you depend on could be removed from the repository, or the repository could go down for a while.
#     - A local cache helps with speed, and reducing internet bandwidth load/congestion/costs. Especially so, considering the 'cattle not pets' philosophy,
#       and the desire to automate testing of the 'new machine' scenario. (e.g. How many times can I download the Git package before someone complains?)
#     - A local cache might also give an opportunity to simplify - if we only add a package to the cache after it has passed (some version of) our tests.
#       I'm not sure.


# This is the 'spackle' mentioned in the file comment: Some packages emit "Path environment variable modified; restart your shell to use the new value.".
# To avoid stopping the script at this point, we need to a) hope we can predict the new value, and b) add it to $env:path.
# 
# TODO: Could we reliably update it from the registry?
# TODO: Could already-open windows apply the change via a check in prompt?
function fixupPath($newPath) {
    if (($env:path -split ';') -notcontains $newPath) {
        if (!$env:path.EndsWith(";")) { $env:path += ";" }
        $env:path += $newPath
    }
}

function installPratWingetPackage([string] $wingetPackageId, [switch] $MachineScope, [switch] $NoScope) {
    if ($NoScope -and $MachineScope) { throw "Can't specify both -NoScope and -MachineScope" }
    $errorName = ""

    if ($NoScope) {
        # This was added specifically for package "Ditto.Ditto". 
        #   It doesn't support "--scope machine": If you sudo, then it runs elevated; if you don't sudo, then it fails with "access denied". 
        #   And it doesn't support "--scope user" - it fails with APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER in that case.
        winget install --silent --exact --id $wingetPackageId --accept-package-agreements --accept-source-agreements
    } elseif ($MachineScope) {
        # I prefer user scope, but some packages don't support it.
        Invoke-Gsudo {winget install --scope machine --silent --exact --id $using:wingetPackageId --accept-package-agreements}
    } else {
        winget install --scope user --silent --exact --id $wingetPackageId --accept-package-agreements
    }

    switch ($lastExitCode) {
        0 { return }
        -1978335189 { return } # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE 	No applicable update found
        -2147024891 { $errorName = "Access is denied" }
    }
    if ($errorName -ne "") { $errorName = " ($errorName)" }
    throw "winget failed. error code: $lastExitCode$errorName" # https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md
}

function installOrGetInstalledAliasesFile($stage) {
    $autoProfilePath = (Resolve-Path "$PSScriptRoot\..\..").Path + "\auto\profile"
    $filename = "scriptAliases.ps1"
    $installedAliasesFile = "$autoProfilePath\$filename"

    if (!(Test-Path $installedAliasesFile)) {
        Install-File $stage $PSScriptRoot $autoProfilePath $filename
    }

    return $installedAliasesFile
}

# Packages that set up aliases can be annoying. Perhaps that's why I observe that gerardog.gsudo thinks it does so and yet I can't find any evidence of it.
#
# Anyway, I do want to specifically opt in to aliases for use in scripts, and do it reliably. i.e. both add it in the current execution environment ('spackle')
# and add it somewhere that's included in PowerShell profile. (This still leaves a gap - in other already-open windows - and I'll just try to avoid that case.)
function installPratScriptAlias($stage, [string] $Name, [string] $Value) {
    $installedAliasesFile = installOrGetInstalledAliasesFile $stage

    $lineArray = [LineArray]::new((Import-TextFile $installedAliasesFile))
    Add-HashTableItemInPowershellScript $lineArray 'installedAliases' $Name (ConvertTo-Expression $Value)
    Install-TextToFile $stage $installedAliasesFile $lineArray.ToString()

    # Add/update it in the current execution environment.
    New-Alias -Name $Name -Value $Value -Scope Global -Force
}

$pratPackageDependencies = @{
    "pester" = @("sudo", "nugetPackageProvider")
    "nugetPackageProvider" = @("sudo")
    "sudo" = @()
    "pwsh" = @("sudo")
    "wget" = @()
    "python" = @()
    "ditto" = @()
    "df" = @()
    "sysinternals" = @()
    "pushoverNotification" = @()
    "forkGitClient" = @()
}

function internal_installDitto($stage) {
    # Installs Ditto (a clipboard manager). What I like about it:
    # - Ctrl-Shift-V to paste without formatting (to any app, not just ones that have this feature)
    # - Ctrl-` to bring up a searchable clipboard history

    installPratWingetPackage "Ditto.Ditto" -NoScope

    # http://ditto-cp.sourceforge.net/
    #
    # A version that I used for a long time and worked great, published in 2017: 3.21.223.0.
    # Latest version as of 3/27/2024: 3.24.246.0
    # Release notes: https://ditto-cp.sourceforge.io/

    # Bind Ctrl-Shift-V to text-only paste
    Install-RegistryDwordValue $stage 'HKCU:\Software\Ditto' TextOnlyPaste 0x356

    # Disable startup notification "Ditto is running minimized"
    Install-RegistryDwordValue $stage 'HKCU:\Software\Ditto' ShowStartupMessage 0

    # "Pasted entries expire after X days". Provides *some* protection if you happen to copy a password - but you should still:
    # 1) try to avoid it - e.g. use drag-and-drop from your password manager where that's supported (not all websites/apps support this)
    # 2) promptly delete the password from ditto when you're done with it
    Install-RegistryDwordValue $stage 'HKCU:\Software\Ditto' ExpiredEntries 2

    if ($stage.DidUpdate()) {
        if (Get-Process ditto -ErrorAction SilentlyContinue) {
            # Restart Ditto to ensure it picks up any registry changes we made.
            # 
            # Sometimes I find it's running, sometimes not.
            Restart-Process "ditto.exe"
        }
    }
}

# installPushoverNotification: Given some Pushover tokens, installs a 'Send-UserNotification' script that 
#   uses those tokens to notify the user.
#
# $packageArgs[0]: Points to a file that contains a user token and some app tokens (from your Pushover account), in a hashtable. 
#   Sample contents:
<# 
        # My user and api keys for https://pushover.net/ 
        @{
            user = "1fdz9"
            apps = @{
                Testing =      "qr0ng"
                prat =         "tw8ir"
                misc =         "o5n1v"
            }
        }
#>
function installPushoverNotification($stage, [array] $packageArgs) {
    [string] $tokenFile = $packageArgs[0]
    if ($tokenFile -eq "") { throw 'Missing parameter: $tokenFile' }
    if (!(Test-Path $tokenFile)) { throw "Not found: $tokenFile" }

    $autoBinPath = (Resolve-Path "$PSScriptRoot/../..").Path + "/auto/pathbin"
    Install-Folder $stage $autoBinPath

    $template = Import-TextFile "$PSScriptRoot/Send-UserNotification.template.PushOver.ps1"
    $newText = Format-ReplacePlaceholdersInTemplateString $template @{tokenfile = $tokenFile}
    Install-TextToFile $stage "$autoBinPath/Send-UserNotification.ps1" $newText
}

# Install the "Fork" git client: https://fork.dev/
# 
# Keyboard shortcut: Ctrl-P is a very handy, non-discoverable shortcut, to [Quick-Launch view](https://fork.dev/blog/posts/quick-launch/)
#
#
# $packageArgs[0]: Points to a file that contains fork activation information, in a hashtable. Or null/empty, to skip activation.
#   Sample contents:
<#
        # My activation information for https://fork.dev/
        @{
            email = "bob@null.com"
            key = "21A014C1-7137A92D-0A8F4857"
        }
#>
# NOTE: Fork autoupdates, so for this package we only ever need to think about initial installation.
function installForkGitClient($stage) {
    [string] $tokenFile = & (Resolve-PratLibFile "lib/inst/Get-PratTokens.ps1") "forkActivation"
    if (($tokenFile -ne "") -and (!(Test-Path $tokenFile))) { throw "Not found: $tokenFile" }

    if (Get-CurrentUserIsElevated) { 
        # Running elevated gave me this error: "Installer hash does not match; this cannot be overridden when running as admin".
        throw "Can't install Fork when elevated" 
    }
    $destDir = $env:localappdata + "\Fork"

    installPratWingetPackage "Fork.Fork"   # TODO: Test. I'd been using the default scope before, which I think means machine scope, and yet Fork was installing itself in a per-user location. Also is "--accept-source-agreements" different from "--accept-package-agreements"?
    if (-not (Test-Path $destDir)) {
        throw "Fork installation failed / unexpected location"
    }

    $stage.EnsureManualStep("fork\firstrun", "Run Fork (to trigger its 'first-run setup'). Give it my name and email. Leave it running for the next steps.")
    $stage.EnsureManualStep("fork\dark", "Appearance > Dark")
    $stage.EnsureManualStep("fork\gitIntegration", "File > Preferences > Git > Git Instance: Choose C:\Program Files\Git\bin\git.exe")
    $stage.EnsureManualStep("fork\pin", "Pin Fork to taskbar")
    if (($tokenFile -ne "")) {
        $stage.EnsureManualStep("fork\close", "Close Fork so that we can activate it")

        [hashtable] $tokens = . $tokenFile
        &$destDir\current\Fork.exe activate $tokens.email $tokens.key
    }
}

$pratPackages = @{
    sudo = @{
        install = { 
            param($stage)
            if ($null -eq $stage) { throw "Missing parameter: stage" }
            installPratWingetPackage "gerardog.gsudo"
            fixupPath ($env:localappdata + "\Microsoft\WinGet\Packages\gerardog.gsudo_Microsoft.Winget.Source_8wekyb3d8bbwe\x64")
            installPratScriptAlias $stage 'sudo' 'gsudo'
        }
    }
}

function internal_installPratPackage($stage, [string] $packageId, [array] $packageArgs) {
    # Dependencies
    $deps = $pratPackageDependencies[$packageId]
    if ($null -eq $deps) { throw "Unrecognized Prat package id: $packageId" }
    foreach ($dep in $deps) { internal_installPratPackage $stage $dep }

    # The package itself
    if (!($stage.GetIsStepComplete("pkg\$packageId"))) { 
        $stage.SetSubstage($packageId)
        $stage.OnChange()

        if ($pratPackages.ContainsKey($packageId)) {
            &($pratPackages[$packageId].install) $stage
            $stage.SetStepComplete("pkg\$packageId")
            return
        }
        switch ($packageId) {
            "pester" {
                # I would prefer to install in user scope, but for Pester on Windows, that seems unsupported, due to the
                # [pre-installed old version on Windows](https://pester.dev/docs/introduction/installation)
                # I'm pinning Pester to major version 5, because 4->5 was a breaking change, so 5->6 likely will be too.
                sudo Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion "5.0" -MaximumVersion "5.999"
            }
            "nugetPackageProvider" {
                sudo Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            }
            "python" {
                installPratWingetPackage "Python.PythonInstallManager"

                # This is a rare case where I don't need to fix up PATH, not even in the current instance.
                # The reason is that PythonInstallManager overwrites the existing link at $env:LocalAppData\Microsoft\WindowsApps\python.exe, 
                # which is *already* in the path (Windows 10 does that).
            }
            "pwsh" {
                # If I want the latest version, I have to use machine scope. As of May 2024, the last version that supported user scope was 7.2.6.0,
                # and the latest version was 7.4.2.0. https://github.com/microsoft/winget-cli/issues/4318
                installPratWingetPackage "Microsoft.PowerShell" -MachineScope
                fixupPath "$env:programfiles\PowerShell\7"
            }
            "wget" {
                # Windows Powershell (I'm not sure about Powershell) by default aliases 'wget' to Invoke-WebRequest. This sucks because:
                # 1. the very common use case, "wget <url>", behaves differently.
                # 2. it's EXTREMELY slow. See discussion here: https://stackoverflow.com/questions/28682642/powershell-why-is-using-invoke-webrequest-much-slower-than-a-browser-download
                #
                # I used to instead have a basic 'wget.ps1' that wrapped curl. But curl - at least the Windows version - doesn't know how to
                # resume a download after an error - it restarts at the beginning of a file. For many-gigabyte files, that never works.
                # See discussion here: https://stackoverflow.com/questions/19728930/how-to-resume-interrupted-download-automatically-in-curl
                # So, install wget instead.

                # wget documentation: https://www.gnu.org/software/wget/manual/

                installPratWingetPackage "JernejSimoncic.Wget"

                # The winget package updates PATH
                #
                # On one machine but not the other, it also created a symlink here: C:\Users\Andrew\AppData\Local\Microsoft\WinGet\Links\wget.exe
                # Dunno what that's about!
            }
            "ditto" { internal_installDitto $stage }
            "df" { installPratScriptAlias $stage 'df' 'Get-DiskFreeSpace' }
            "sysinternals" { installPratWingetPackage "9P7KNL5RWT25"}
            "pushoverNotification" { installPushoverNotification $stage $packageArgs }
            "forkGitClient" { installForkGitClient $stage }
            default { throw "Internal error: $packageId" }
        }

        $stage.SetStepComplete("pkg\$packageId")
    }
}

# .SYNOPSIS
# Install a package, and its dependencies, reporting to $installationTracker if it does anything
# For each package, skips it if some version is already installed.
#
# $packageArgs: Optional arguments to be passed to the package. Is NOT passed to dependent packages.
function Install-PratPackage($installationTracker, [string] $packageId, $packageArgs) {
    $stage = $installationTracker.StartStage("Install-PratPackage($packageId)")
    internal_installPratPackage $stage $packageId $packageArgs
    $installationTracker.EndStage($stage)
}

