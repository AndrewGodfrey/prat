# Tools for installing particular winget packages.
# Winget packages aren't entirely regular, so this is 'spackle' to make them behave.


function isWingetPackageInstalled([string] $packageId) {
    $outputStrings = winget list --exact -q $packageId
    return [String]::Join("", $outputStrings).Contains($packageId)
}

function installWingetPackage([string] $packageId, [string] $version = $null) {
    $versionParam = @()
    if ($null -ne $version) {
        $versionParam = @("--version", $version)
    }
    winget install --silent --exact --id $packageId @versionParam
}

# .SYNOPSIS
# Install a winget package
#
# .PARAMETER installPath
# A folder/file that is used as a sanity check for whether the package is installed.
#
# .PARAMETER version
# Optional - specific version number to install. ONLY USED if the package isn't already installed.
# Doesn't upgrade or downgrade.
# 
# .NOTES
#
# Tip: When adding code for a new package, I might not know the installation path yet and want to install the package first to find out.
# Just do this:
# - Use something that doesn't exist, like "\foo". 
# - The 'verify' step will fail, after installing the package.
# - Now find the location, update the code, and rerun.
function Install-WingetPackage($stage, [string] $packageId, [string] $installPath, [string] $version = $null) {
    $stage.SetSubstage("Install-WingetPackage($packageId) : package check")

    if ($installPath -eq "") { throw "Install path required" }

    #    if (-not (isPackageInstalled $packageId)) {   # This is very slow, so instead:
    if (-not (Test-Path $installPath)) {
        $stage.OnChange()
        $stage.SetSubstage("Install-WingetPackage($packageId) : install")
        installWingetPackage $packageId $version

        # Verify
        if (!(Test-Path $installPath)) {
            throw "Internal error: Expected install path wasn't created: $installPath"
        }

        if (-not (isWingetPackageInstalled $packageId)) {
            throw "Internal error: Package installation succeeded but 'isWingetPackageInstalled' returns false";
        }
    }
}

function Install-PackageDnspy($installationTracker) {
    $stage = $installationTracker.StartStage("pkgDnspy")

    Install-WingetPackage $stage "dnSpyEx.dnSpy" "$env:localappdata\Microsoft\WinGet\Packages\dnSpyEx.dnSpy_Microsoft.Winget.Source_8wekyb3d8bbwe"

    # This package does update PATH, BUT: for some reason that doesn't take effect until a machine reboot.
    # Could hack around that if desired, but I don't use this often anyway.

    $installationTracker.EndStage($stage)
}


function Install-PackageNuget($installationTracker) {
    $stage = $installationTracker.StartStage("pkgNuget")

    $dest = "$env:localappdata\Microsoft\WinGet\Packages\Microsoft.NuGet_Microsoft.Winget.Source_8wekyb3d8bbwe"

    Install-WingetPackage $stage "Microsoft.NuGet" $dest

    # This package updates PATH but doesn't load it in current environment.
    $env:path += ";$dest"

    $installationTracker.EndStage($stage)
}


function Install-PackageWindbg($installationTracker) {
    $stage = $installationTracker.StartStage("windbg")

    Install-WingetPackage $stage "Microsoft.WinDbg" "$env:localappdata\Microsoft\WindowsApps\WinDbgX.exe"

    $installationTracker.EndStage($stage)
}

function Install-PackageWinmerge($installationTracker, $generatedBinDir) {
    $stage = $installationTracker.StartStage("winMerge")

    # Expected install path:
    $installPath = "$env:localappdata\Programs\WinMerge" 

    Install-WingetPackage $stage "WinMerge.WinMerge" $installPath

    # Winmerge doesn't add itself to the path, so instead make a stub script:
    $genbin = $generatedBinDir
    Install-Folder $stage $genbin

    $stubScript = '. ' + $installPath + '\WinMergeU.exe $Args'
    Install-TextToFile $stage "$genbin\winmerge.ps1" $stubScript

    $installationTracker.EndStage($stage)
}

# Install v1.x of AutoHotKey.
function Install-PackageAutoHotKeyV1($installationTracker) {
    $stage = $installationTracker.StartStage("AutoHotKey")

    $expectedInstallPath = "C:\Program Files\AutoHotKey"
    Install-WingetPackage $stage "AutoHotkey.AutoHotkey" $expectedInstallPath "1.1.37.02"

    $installationTracker.EndStage($stage)
}

