. $PSScriptRoot\instPwshAliases.ps1

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
#     - Which package should we use? (e.g. I need 'sudo'; I can abstract away "which implementation I picked").
#     - Which package manager should we use? (e.g. Claude provides npm, winget, and native installers. They vary in recency and isolation.)
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


function Get-DotnetSdkRequirement($globalJsonPath) {
    $globalJson = Get-Content $globalJsonPath | ConvertFrom-Json
    $parts      = $globalJson.sdk.version -split '\.'
    $major      = $parts[0]
    $minor      = $parts[1]
    $pattern    = switch ($globalJson.sdk.rollForward) {
        'latestFeature' { "$major.$minor.*" }
        'latestMinor'   { "$major.*" }
        'latestMajor'   { '*' }
        default         { throw "Unsupported rollForward value in $($globalJsonPath): '$($globalJson.sdk.rollForward)'" }
    }
    @{ Major = $major; Pattern = $pattern }
}

# This is the 'spackle' mentioned in the file comment: Some packages emit "Path environment variable modified; restart your shell to use the new value.".
# To avoid stopping the script at this point, we need to a) hope we can predict the new value, and b) add it to $env:path.
# 
# TODO: Could already-open windows apply the change via a check in prompt?
function fixupPath($stage, $newPath) {
    Install-UserPathEntry $stage $newPath -CurrentProcessOnly
}

function invokeWingetUserScope([string] $wingetPackageId) {
    winget install --scope user --silent --exact --id $wingetPackageId --accept-package-agreements
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
        if (isWingetPackageInstalledMachineScope $wingetPackageId) { return }
        invokeWingetUserScope $wingetPackageId
    }

    switch ($lastExitCode) {
        0 { return }
        -1978335189 { return } # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE 	No applicable update found
        -2147024891 { $errorName = "Access is denied" }
    }
    if ($errorName -ne "") { $errorName = " ($errorName)" }
    throw "winget failed. error code: $lastExitCode$errorName" # https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md
}

function internal_installDitto($stage) {
    # Installs Ditto (a clipboard manager). What I like about it:
    # - Ctrl-Shift-V to paste without formatting (to any app, not just ones that have this feature)
    # - Ctrl-` to bring up a searchable clipboard history

    installPratWingetPackage "Ditto.Ditto" -NoScope

    # http://ditto-cp.sourceforge.net/
    #
    # A version that I used for a long time and worked great, published in 2017: v3.21.223.0.
    # Latest version as of 3/27/2024: v3.24.246.0
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
            email = "bob@example.com"
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

function isClaudeRunning() {
    return [bool](Get-Process claude -ErrorAction SilentlyContinue)
}

$script:claudeGcsBucketUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

function getInstalledClaudeVersion() {
    $output = (claude --version 2>&1)
    if ($output -notmatch '^(\S+)') { return $null }
    return $matches[1]
}

function invokeClaudeInstaller($targetVersion) {
    $sb = [scriptblock]::Create((Invoke-RestMethod https://claude.ai/install.ps1))
    if ($targetVersion) { & $sb $targetVersion } else { & $sb }
}

function installClaude($stage, $targetVersion) {
    # Use the native installer, because:
    # - the winget installer lags behind the latest version
    # - the npm installer depends on the system-installed node.js, causing conflicts when working
    #   on code that requires an old version).

    if (isClaudeRunning) {
        $installed = getInstalledClaudeVersion
        $msg = "Claude is running"
        if ($installed -and $targetVersion) { $msg += " ($installed → $targetVersion)" }
        Write-Warning "$msg — close it to install the update."
        return
    }

    invokeClaudeInstaller $targetVersion

    $localBin = "$home/.local/bin"
    $destFile = "$localBin/claude.exe"

    if (-not (Test-Path $destFile)) {
        throw "Claude installation failed / unexpected location"
    }

    # The claude installer doesn't add ~/.local/bin to PATH; do it ourselves.
    Install-UserPathEntry $stage ($localBin -replace '/', '\')
}

function getClaudeInstaller() {
    return @{
        getLatestVersion = {
            try { (Invoke-RestMethod "$script:claudeGcsBucketUrl/latest").Trim() }
            catch { $null }
        }
        check   = { param($stage, $targetVersion) $targetVersion -and ((getInstalledClaudeVersion) -eq $targetVersion) }
        install = { param($stage, $targetVersion) installClaude $stage $targetVersion }
    }
}

$pratPackages = @{
    autohotkey = @{
        install = {
            Install-WingetPackage $stage "AutoHotkey.AutoHotkey" "$env:localAppData\programs\AutoHotKey"
        }
    }
    claude = getClaudeInstaller
    df = @{
        install = { Install-InteractiveAlias $stage 'df' 'Get-DiskFreeSpace' }
    }
    ditto = @{
        install = { internal_installDitto $stage }
    }
    dotnetSdk = @{
        dependencies = @("sudo")
        check = {
            $req    = Get-DotnetSdkRequirement $packageArgs[0]
            $sdkDir = "$env:programfiles/dotnet/sdk"
            (Test-Path $sdkDir) -and [bool](Get-ChildItem $sdkDir -Directory -ErrorAction SilentlyContinue | Where-Object Name -like $req.Pattern)
        }
        install = {
            $globalJsonFile = $packageArgs[0]
            $installScript  = "$env:TEMP/dotnet-install.ps1"
            $dotnetDir      = "$env:ProgramFiles/dotnet"
            $stage.SetSubstage("downloading dotnet-install.ps1")
            Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -OutFile $installScript
            $stage.SetSubstage("running dotnet-install.ps1")
            Invoke-Gsudo {
                & $using:installScript -JsonFile $using:globalJsonFile -InstallDir $using:dotnetDir
                $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
                if (($machinePath -split ';') -notcontains $using:dotnetDir) {
                    [System.Environment]::SetEnvironmentVariable("PATH", "$machinePath;$using:dotnetDir", "Machine")
                }
            }
            $stage.SetSubstage("updating PATH")
            # Refresh current (non-elevated) process PATH
            $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
            if (($env:PATH -split ';') -notcontains $dotnetDir) { $env:PATH = "$env:PATH;$dotnetDir" }
        }
    }
    dnspy = @{
        install = {
            Install-WingetPackage $stage "dnSpyEx.dnSpy" "$env:localappdata\Microsoft\WinGet\Packages\dnSpyEx.dnSpy_Microsoft.Winget.Source_8wekyb3d8bbwe"
            # This package does update PATH, BUT: for some reason that doesn't take effect until a machine reboot.
            # Could hack around that if desired, but I don't use this often anyway.
        }
    }
    forkGitClient = @{
        install = { installForkGitClient $stage }
    }
    gh = @{
        install = { installPratWingetPackage "GitHub.cli" -NoScope }
    }
    nuget = @{
        install = {
            $dest = "$env:localappdata\Microsoft\WinGet\Packages\Microsoft.NuGet_Microsoft.Winget.Source_8wekyb3d8bbwe"
            Install-WingetPackage $stage "Microsoft.NuGet" $dest
            # This package updates PATH but doesn't load it in current environment.
            if ($dest -notin ($env:path -split ';')) { $env:path += ";$dest" }
            # Apparently, the nuget winget package doesn't pre-configure "nuget.org" as a source anymore. So:
            if ((nuget sources List | ? {$_.Contains("nuget.org [Enabled]")}).Count -eq 0) {
                nuget sources Add -Name nuget.org -Source https://api.nuget.org/v3/index.json
            }
        }
    }
    pester = @{
        install = {
            # I'm pinning Pester to major version 5, because 4->5 was a breaking change, so 5->6 likely will be too.
            Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion "5.0" -MaximumVersion "5.999"
        }
        dependencies = @("sudo", "removeBuiltinPester")
    }
    powerToys = @{
        install = {
            installPratWingetPackage "Microsoft.PowerToys"
        }
    }
    pushoverNotification = @{
        install = { installPushoverNotification $stage $packageArgs }
    }
    pwsh = @{
        install = {
            # If I want the latest version, I have to use machine scope. As of May 2024, the last version that supported user scope was v7.2.6.0,
            # and the latest version was v7.4.2.0. https://github.com/microsoft/winget-cli/issues/4318
            installPratWingetPackage "Microsoft.PowerShell" -MachineScope
            fixupPath $stage "$env:programfiles\PowerShell\7"
        }
        dependencies = @("sudo")
    }
    python = @{
        installerVersion = "3.0"
        install = {
            # Pinned to 3.12: llama-cpp-python pre-built wheels require Python 3.10-3.12.
            # Uses embeddable zip — full Windows installer silently exits 0 without installing
            # in non-interactive sessions (no UAC prompt available).
            $version   = "3.12.8"
            $pythonDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
            $pythonExe = "$pythonDir\python.exe"

            if (-not (Test-Path $pythonExe)) {
                $zipFile = "$env:TEMP\python-$version-embed-amd64.zip"
                curl.exe -sL -o $zipFile "https://www.python.org/ftp/python/$version/python-$version-embed-amd64.zip"
                if ($LASTEXITCODE -ne 0) { throw "Python download failed (exit $LASTEXITCODE)" }
                New-Item -ItemType Directory -Force -Path $pythonDir | Out-Null
                Expand-Archive -Path $zipFile -DestinationPath $pythonDir -Force
                Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
                if (-not (Test-Path $pythonExe)) { throw "Python extract failed" }
                # Enable site-packages so pip and installed packages work
                $pthFile = "$pythonDir\python312._pth"
                (Get-Content $pthFile -Raw) -replace '#import site', 'import site' | Set-Content $pthFile
                # Install pip
                $getPip = "$env:TEMP\get-pip.py"
                curl.exe -sL -o $getPip "https://bootstrap.pypa.io/get-pip.py"
                if ($LASTEXITCODE -ne 0) { throw "get-pip.py download failed (exit $LASTEXITCODE)" }
                & $pythonExe $getPip --no-warn-script-location
                if ($LASTEXITCODE -ne 0) { throw "pip installation failed (exit $LASTEXITCODE)" }
                Remove-Item $getPip -Force -ErrorAction SilentlyContinue
            }
            # Remove Windows App Execution Alias stubs that shadow real Python
            Remove-Item "$env:LOCALAPPDATA\Microsoft\WindowsApps\python.exe"  -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:LOCALAPPDATA\Microsoft\WindowsApps\python3.exe" -Force -ErrorAction SilentlyContinue
            Install-UserPathEntry $stage $pythonDir
            Install-UserPathEntry $stage "$pythonDir\Scripts"
        }
    }
    removeBuiltinPester = @{
        install = {
            sudo {
                $ErrorActionPreference = "stop"

                # Source: https://pester.dev/docs/introduction/installation
                $module = "C:\Program Files\WindowsPowerShell\Modules\Pester"
                takeown.exe /F $module /A /R | Out-Null
                icacls.exe $module /reset | Out-Null
                icacls.exe $module /grant "*S-1-5-32-544:F" /inheritance:d /T | Out-Null
                Remove-Item -Path $module -Recurse -Force -Confirm:$false | Out-Null
            }
        }
        dependencies = @("sudo")
    }
    sudo = @{
        install = {
            installPratWingetPackage "gerardog.gsudo"
            fixupPath $stage ($env:localappdata + "\Microsoft\WinGet\Packages\gerardog.gsudo_Microsoft.Winget.Source_8wekyb3d8bbwe\x64")
            installPratScriptAlias $stage 'sudo' 'gsudo'
        }
    }
    sysinternals = @{
        install = { installPratWingetPackage "9P7KNL5RWT25"}
    }
    marktext = @{
        install = {
            installPratWingetPackage "MarkText.MarkText" -NoScope
        }
    }
    winget = @{
        check = { $null -ne (Get-Command winget -ErrorAction SilentlyContinue) }
        install = {
            # Add-AppxPackage only works in Windows PowerShell, not PS Core.
            $bundle = "$env:TEMP\AppInstaller.msixbundle"
            curl.exe -sL -o $bundle "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
            if ($LASTEXITCODE -ne 0) { throw "winget download failed (exit $LASTEXITCODE)" }
            powershell.exe -NonInteractive -Command "Add-AppxPackage -Path '$bundle'"
            if ($LASTEXITCODE -ne 0) { throw "Add-AppxPackage failed (exit $LASTEXITCODE)" }
            Remove-Item $bundle -Force -ErrorAction SilentlyContinue
            fixupPath $stage "$env:LOCALAPPDATA\Microsoft\WindowsApps"
        }
    }
    windbg = @{
        install = {
            Install-WingetPackage $stage "Microsoft.WinDbg" "$env:localappdata\Microsoft\WindowsApps\WinDbgX.exe"
        }
    }
    winmerge = @{
        install = { internal_installWinmerge $stage }
    }
    wget = @{
        install = {
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
            # On one machine but not the other, it also created a symlink here: C:\Users\xyz\AppData\Local\Microsoft\WinGet\Links\wget.exe
            # Dunno what that's about!
        }
    }
}

function internal_installPratPackage($stage, [string] $packageId, [array] $packageArgs, [array] $processingStack = @()) {
    $packageEntry = $pratPackages[$packageId]

    # Get dependencies
    if ($null -eq $packageEntry) {
        throw "Unrecognized Prat package id: $packageId" 
    }

    if ($packageId -in $processingStack) {
        throw "Circular dependency detected: $($processingStack -join ' -> ') -> $packageId"
    }

    $deps = $packageEntry.dependencies
    if ($null -eq $deps) {
        $deps = @()
    }

    # Install dependencies
    $newStack = $processingStack + @($packageId)
    foreach ($dep in $deps) { internal_installPratPackage $stage $dep @() $newStack }

    # The package itself
    $installerVersion = if ($packageEntry.installerVersion) { $packageEntry.installerVersion } else { "1.0" }
    $stepId           = "pkg\$($packageId):$installerVersion"

    $targetVersion = $null
    if ($packageEntry.getLatestVersion) { $targetVersion = &($packageEntry.getLatestVersion) }

    $isInstalled      = if ($packageEntry.check) { &($packageEntry.check) $stage $targetVersion } else { $stage.GetIsStepComplete($stepId) }

    if (-not $isInstalled) {
        $stage.SetSubstage($packageId)
        $stage.OnChange()

        $ErrorActionPreference = "stop"
        &($packageEntry.install) $stage $targetVersion

        if (-not $packageEntry.check) { $stage.SetStepComplete($stepId) }
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

