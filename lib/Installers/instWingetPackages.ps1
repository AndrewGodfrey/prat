# Tools for installing particular winget packages.
# Winget packages aren't entirely regular, so this is 'spackle' to make them behave.


function isPackageInstalled([string] $packageId) {
    $outputStrings = winget list --exact -q $packageId
    return [String]::Join("", $outputStrings).Contains($packageId)
}

function installPackage([string] $packageId) {
      winget install --silent --exact --id $packageId
}

# .SYNOPSIS
# Install a winget package
#
# .PARAMETER installPath
# A folder/file that is used as a sanity check for whether the package is installed.
# 
# .NOTES
#
# Tip: When adding code for a new package, I might not know the installation path yet and want to install the package first to find out.
# Just do this:
# - Use something that doesn't exist, like "\foo". 
# - The 'verify' step will fail, after installing the package.
# - Now find the location, update the code, and rerun.
function Install-WingetPackage($stage, [string] $packageId, [string] $installPath) {
    $stage.SetSubstage("Install-WingetPackage($packageId) : package check")

    if ($installPath -eq "") { throw "Install path required" }

    #    if (-not (isPackageInstalled $packageId)) {   # This is very slow, so instead:
    if (-not (Test-Path $installPath)) {
        $stage.OnChange()
        $stage.SetSubstage("Install-WingetPackage($packageId) : install")
        installPackage $packageId

        # Verify
        if (!(Test-Path $installPath)) {
            throw "Internal error: Expected install path wasn't created: $installPath"
        }

        if (-not (isPackageInstalled $packageId)) {
            throw "Internal error: Package installation succeeded but 'isPackageInstalled' returns false";
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


function Install-PackageWget($installationTracker) {
    $stage = $installationTracker.StartStage("wget")

    # PowerShell by default aliases 'wget' to Invoke-WebRequest. This sucks because:
    # 1. the very common use case, "wget <url>", behaves differently.
    # 2. it's EXTREMELY slow. See discussion here: https://stackoverflow.com/questions/28682642/powershell-why-is-using-invoke-webrequest-much-slower-than-a-browser-download
    #
    # I used to instead have a basic 'wget.ps1' that wrapped curl. But curl - at least the Windows version - doesn't know how to
    # resume a download after an error - it restarts at the beginning of a file. For many-gigabyte files, that never works.
    # See discussion here: https://stackoverflow.com/questions/19728930/how-to-resume-interrupted-download-automatically-in-curl
    # So, install wget instead.

    # wget documentation: https://www.gnu.org/software/wget/manual/

    # Expected install path:
    $installPath = "$env:localappdata\Microsoft\WinGet\Packages\JernejSimoncic.Wget_Microsoft.Winget.Source_8wekyb3d8bbwe" 

    Install-WingetPackage $stage "JernejSimoncic.Wget" $installPath
    # The winget package updates PATH

    # On one machine but not the other, it also created a symlink here: C:\Users\Andrew\AppData\Local\Microsoft\WinGet\Links\wget.exe
    # Dunno what that's about!

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

