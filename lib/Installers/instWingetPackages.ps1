# Tools for installing particular winget packages.
# Winget packages aren't entirely regular, so this is 'spackle' to make them behave.


function isWingetPackageInstalled([string] $packageId) {
    $outputStrings = winget list --exact -q $packageId
    return [String]::Join("", $outputStrings).Contains($packageId)
}

function installWingetPackage([string] $packageId, [string] $version = """") {
    $versionParam = @()
    if ($version -ne "") {
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
function Install-WingetPackage($stage, [string] $packageId, [string] $installPath, [string] $version = "") {
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

function internal_installWinmerge($stage) {
    $installPath = "$env:localappdata\Programs\WinMerge"

    Install-WingetPackage $stage "WinMerge.WinMerge" $installPath

    # Winmerge doesn't add itself to the path, so instead make a stub script:
    $genbin = (Resolve-Path "$PSScriptRoot/../..").Path + "/auto/pathbin"
    Install-Folder $stage $genbin

    $stubScript = '. ' + $installPath + '\WinMergeU.exe $Args'
    Install-TextToFile $stage "$genbin\winmerge.ps1" $stubScript
}
