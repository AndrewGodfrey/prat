# Tools for installing particular nuget packages.
function installPackage([string] $packageId, [string] $version) {
    nuget install $packageId -OutputDirectory $home\de\packages -Verbosity quiet -NonInteractive


    # I've tried the "native Powershell" way:
    #  Install-Package -Name $packageId -ProviderName NuGet -Scope CurrentUser -RequiredVersion $version -SkipDependencies -Destination $home\de\packages -Force
    # But it couldn't find the package. Looking into it I see various pain points:
    # https://stackoverflow.com/questions/51406685/powershell-how-do-i-install-the-nuget-provider-for-powershell-on-a-unconnected
    # https://www.alitajran.com/unable-to-install-nuget-provider-for-powershell/

}

$packages = @{
    shelllink = @{
        id = "securifybv.ShellLink"
        version = "0.1.0"
        target = "securifybv.ShellLink.0.1.0\lib\netstandard2.0\securifybv.ShellLink.dll"
        dependencies = @('propertyStore')
    }
    propertyStore = @{
        id = "securifybv.PropertyStore"
        version = "0.1.0"
        target = "securifybv.PropertyStore.0.1.0\lib\netstandard2.0\securifybv.PropertyStore.dll"
    }
}

function installPackageAndDeps($stage, [string] $myPackageId, [string] $packagesRoot) {
    $p = $packages[$myPackageId]
    if ($p -eq $null) { throw "Unrecognized myPackageId: $myPackageId" }

    foreach ($dep in $p.dependencies) {
        installPackageAndDeps $stage $dep $packagesRoot
    }

    $packageId = $p.id
    $version = $p.version
    $installPath = $packagesRoot + "\" + $p.target

    $stage.SetSubstage("Install-NugetPackage($packageId) : package check")
    if (-not (Test-Path $installPath)) {
        $stage.OnChange()
        $stage.SetSubstage("Install-NugetPackage($packageId) : install")
        installPackage $packageId $version

        if (!(Test-Path $installPath)) {
            throw "Internal error: Expected install path wasn't created: $installPath"
        }
    }
}


# .SYNOPSIS
# Install a nuget package
#
# .PARAMETER installPath
# A folder/file that is used as a sanity check for whether the package is installed.
# (Don't use the root folder unless the uninstaller will reliably remove that. I haven't seen an 'official' uninstaller for nuget packages).
# 
# .NOTES
# Tip: When adding code for a new package, I might not know the installation path yet and want to install the package first to find out.
# Just do this:
# - Use something that doesn't exist, like "\foo". 
# - The 'Expected install path wasn't created' error will throw, after installing the package.
# - Now find the location and update the code.
function Install-NugetPackage($installationTracker, [string] $myPackageId, [string] $packagesRoot) {
    $stage = $installationTracker.StartStage("pkgNuget-$myPackageId")
    installPackageAndDeps $stage $myPackageId $packagesRoot
    $installationTracker.EndStage($stage)
}


function Add-NugetPackageType([string] $myPackageId, [string] $packagesRoot) {
    $p = $packages[$myPackageId]
    if ($p -eq $null) { throw "Unrecognized myPackageId: $myPackageId" }

    foreach ($dep in $p.dependencies) {
        Add-NugetPackageType $dep $packagesRoot
    }

    $installPath = $packagesRoot + "\" + $p.target
    if (!(Test-Path $installPath)) {
        throw "Internal error: Package doesn't seem to be installed: $myPackageId"
    }

    Add-Type -Path $installPath
    # [System.Reflection.Assembly]::LoadFrom($installPath)
}

