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
#     - nuget (and many others) adds itself to PATH in the registry, but not in the currently-running environment. This breaks scripts.
#       We can 'spackle' the main this by adding to $env:path ourselves.
#     - Some packages make huge breaking changes from one major version to another. For those, auto-updating logic may need to focus on minor version #.
#     - Later, I might re-encounter the need for multiple side-by-side versions (of a package which supports that). In such cases you need
#       some way of picking which one to invoke. One way is to know its installation path, which isn't provided and doesn't follow any rigid convention.
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
function fixupPath($newPath) {
    if (($env:path -split ';') -notcontains $newPath) {
        if (!$env:path.EndsWith(";")) { $env:path += ";" }
        $env:path += $newPath
    }
}

function installPratWingetPackage([string] $wingetPackageId, [switch] $MachineScope) {
    # Consider: --disable-interactivity --accept-package-agreements

    # I prefer user scope, but some packages don't support it.
    if ($MachineScope) { 
        Invoke-Gsudo {winget install --scope machine --silent --exact --id $using:wingetPackageId}
    } else {
        winget install --scope user --silent --exact --id $wingetPackageId
    }

    $errorName = ""
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
}

function internal_installPratPackage($stage, [string] $packageId) {
    # Dependencies
    $deps = $pratPackageDependencies[$packageId]
    if ($deps -eq $null) { throw "Unrecognized Prat package id: $packageId" }
    foreach ($dep in $deps) { internal_installPratPackage $stage $dep }

    # The package itself
    if (!($stage.GetIsStepComplete("pkg\$packageId"))) { 
        $stage.SetSubstage($packageId)
        $stage.OnChange()

        switch ($packageId) {
            "sudo" { 
                installPratWingetPackage "gerardog.gsudo"
                fixupPath ($env:localappdata + "\Microsoft\WinGet\Packages\gerardog.gsudo_Microsoft.Winget.Source_8wekyb3d8bbwe\x64")
                installPratScriptAlias $stage 'sudo' 'gsudo'
            }
            "pester" {
                # I would prefer to install in user scope, but for Pester on Windows, that seems unsupported, due to the
                # [pre-installed old version on Windows](https://pester.dev/docs/introduction/installation)
                # I'm pinning Pester to major version 5, because 4->5 was a breaking change, so 5->6 likely will be too.
                sudo Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion "5.0" -MaximumVersion "5.999"
            }
            "nugetPackageProvider" {
                sudo Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            }
            "pwsh" {
                # If I want the latest version, I have to use machine scope. As of May 2024, the last version that supported user scope was 7.2.6.0,
                # and the latest version was 7.4.2.0. https://github.com/microsoft/winget-cli/issues/4318
                installPratWingetPackage "Microsoft.PowerShell" -MachineScope
                fixupPath "$env:programfiles\PowerShell\7"
            }
            default { throw "Internal error: $packageId" }
        }

        $stage.SetStepComplete("pkg\$packageId")
    }
}

# .SYNOPSIS
# Install a package, and its dependencies, reporting to $installationTracker if it does anything
# For each package, skips it if some version is already installed.
function Install-PratPackage($installationTracker, [string] $packageId) {
    $stage = $installationTracker.StartStage("Install-PratPackage($packageId)")
    internal_installPratPackage $stage $packageId
    $installationTracker.EndStage($stage)
}

