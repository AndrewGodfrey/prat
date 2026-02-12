
# Restrict the Windows start menu to search the local machine. Otherwise, it's unusably slow.
function Install-WindowsStartMenuLocalOnly($stage) {
    $rkSearch = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    Install-RegistryKey $stage $rkSearch
    Install-RegistryDwordValue $stage $rkSearch "BingSearchEnabled" 0
    Install-RegistryDwordValue $stage $rkSearch "CortanaConsent" 0
}

# Add a secondary clock showing UTC time zone. Will *overwrite* additional clock 1 if that's already in use for another time zone.
function Install-WindowsSecondaryClockUTC($stage) {
    Install-RegistryKey $stage "HKCU:\Control Panel\TimeDate"
    Install-RegistryKey $stage "HKCU:\Control Panel\TimeDate\AdditionalClocks"
    $clockKey = "HKCU:\Control Panel\TimeDate\AdditionalClocks\1"
    Install-RegistryKey $stage $clockKey
    Install-RegistryDwordValue $stage $clockKey "Enable" 1
    Install-RegistryStringValue $stage $clockKey "DisplayName" "UTC"
    Install-RegistryStringValue $stage $clockKey "TzRegKeyName" "UTC"
}

# Given an appname, decides whether to use HKCU: or HKLM: for its registration.
# Favors HKCU if both exist
function findSoftwareClassPath($className) {
    $pathcu = "hkcu:\Software\Classes\$className"
    $pathlm = "hklm:\Software\Classes\$className"

    if (Test-Path $pathcu) { return $pathcu }
    if (Test-Path $pathlm) { return $pathlm }
    return $pathcu
}

function queryDefaultStringValue([string] $regPath) {
    if (-not (Test-Path $regPath)) { return $null }

    $key = Get-Item -Path $regPath
    $property = $key.GetValue($null) # Get default value

    if (($null -eq $property) -or (-not ("String", "ExpandString" -Contains $key.GetValueKind($null)))) { return $null }
    return $property
}

function getAssocName([string] $extension) {
    return queryDefaultStringValue (findSoftwareClassPath $extension)
}

function setAssocName([string] $extension, [string] $assocName) {
    cmd /c assoc $extension=$assocName | Out-Null
}

function getFtypeCommand([string] $assocName) {
    $classPath = findSoftwareClassPath $assocName
    return queryDefaultStringValue "$classPath\Shell\Open\Command"
}

function setFtype([string] $assocName, [string] $command) {
    cmd /c "ftype $assocName=$command" | Out-Null
}

# Set or create a Windows Shell file assocation. Reports its actions & inactions to $stage.
#
# $extension should INCLUDE the leading ".".
# If there is already an 'ftype' for this file extension, $assocNameIfNeeded is ignored.
#
# As Windows has grown more complex in this space over the years, this 
# implementation has become brittle and incomplete.
function Install-WindowsFileAssociation($stage, [string] $extension, [string] $command, [string] $assocNameIfNeeded) {
    # Check it hasn't been hijacked via OpenWithProgids. Visual Studio does this with .cs files (and probably many others).
    # TODO: Test to see if this affects HKCU only. If so, we can restrict this to that, and avoid having to think about how to elevate to delete the HKLM: one.
    $classPath = findSoftwareClassPath $assocName
    $openWithProgids = "$classPath\OpenWithProgids"

    if (Test-Path $openWithProgids) {
        $stage.OnChange()

        # TODO: See if I can remove this - can't Remove-Item delete these? e.g. with -Force?
        $valueNames = (Get-Item $openWithProgids).GetValueNames()
        if ($valueNames.Length -ne 0) {
            $valueNames | % { Remove-ItemProperty -Path $openWithProgids -Name $_}
        }

        Remove-Item -Path $openWithProgids
    }

    # Decide on assoc name
    $previousAssocName = getAssocName $extension
    $assocName = $previousAssocName
    if ($null -eq $assocName) {
        $assocName = $assocNameIfNeeded
    }

    # Install ftype
    $actualFtCommand = getFtypeCommand $assocName

    if ($command -ne $actualFtCommand) {
        $stage.OnChange()
        setFtype $assocName $command

        # Verify
        $resultFtCommand = getFtypeCommand $assocName
        if ($resultFtCommand -ne $command) {
            throw "Internal error updating '$extension' ($assocName): [$resultFtCommand], expected [$command]"
        }
    }

    # Install assoc
    if ($null -eq $previousAssocName) {
        $stage.OnChange()
        setAssocName $extension $assocName
    }
}

# Install an app-specific association for a verb like 'Edit', for the current user.
#
# AutoHotkey puts its stuff in HKLM, which is read-only for non-admins.
# But if I override it in HKCU, that works. For Software\Classes this probably works for all apps, but 
# I've only tested this with AutoHotKey's 'Edit' verb so far.
function Install-WindowsAppVerbAssociation($stage, $appName, $verb, $action) {
    $commandKey = "hkcu:\Software\Classes\$appName\Shell\$verb\Command"
    Install-RegistryKey $stage $commandKey
    Install-RegistryStringValue $stage $commandKey $null $action
}

function isWin11 {
    $osVersion = [System.Environment]::OSVersion.Version
    return ($osVersion.Major -eq 10 -and $osVersion.Build -ge 22000) -or ($osVersion.Major -gt 10)
}

# Clean up the Windows 10/11 taskbar by hiding/disabling default items.
# Settings that don't apply to the current OS version are harmlessly ignored.
# Settings locked by Group Policy will emit a warning and continue.
function Install-WindowsTaskbarCleanup($stage) {
    $rkAdvanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $rkSearch = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $rkFeeds = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"

    Install-RegistryKey $stage $rkAdvanced
    Install-RegistryKey $stage $rkSearch
    Install-RegistryKey $stage $rkFeeds

    # --- Common to Windows 10 and 11 ---
    # Hide Search box (0=hidden, 1=icon only, 2=search box)
    Install-RegistryDwordValue $stage $rkSearch "SearchboxTaskbarMode" 0
    # Disable Task View button (0=hidden, 1=shown)
    Install-RegistryDwordValue $stage $rkAdvanced "ShowTaskViewButton" 0

    # --- Windows 10 only ---
    # Hide Cortana button (0=hidden, 1=shown)
    Install-RegistryDwordValue $stage $rkAdvanced "ShowCortanaButton" 0
    # Hide People button (0=hidden, 1=shown)
    Install-RegistryDwordValue $stage $rkAdvanced "PeopleBand" 0

    # --- Windows 11 only ---
    if (isWin11) {
        # Hide Widgets button (0=hidden, 1=shown)
        try {
            Install-RegistryDwordValue $stage $rkAdvanced "TaskbarDa" 0
        } catch [System.UnauthorizedAccessException] {
            $stage.EnsureManualStep("taskbar\widgets", "Right-click taskbar → Taskbar settings → Toggle OFF 'Widgets'")
        }
    }

    # Hide Copilot button (0=hidden, 1=shown)
    Install-RegistryDwordValue $stage $rkAdvanced "ShowCopilotButton" 0
    # Hide Chat/Teams button (0=hidden, 1=shown)
    Install-RegistryDwordValue $stage $rkAdvanced "TaskbarMn" 0

    # Unpin specific apps from taskbar
    $pinnedFolder = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    $appsToUnpin = @(
        "Microsoft Store",
        "Copilot"
    )
    foreach ($app in $appsToUnpin) {
        $shortcut = Join-Path $pinnedFolder "$app.lnk"
        if (Test-Path $shortcut) {
            $stage.OnChange()
            Remove-Item $shortcut -Force
        }
    }
}


