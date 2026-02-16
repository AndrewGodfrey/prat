using module ..\PratBase\PratBase.psd1
using module ..\TextFileEditor\TextFileEditor.psd1


function installOrGetInstalledAliasesFile($stage, [string] $filename) {
    $autoProfilePath = (Resolve-Path "$PSScriptRoot\..\..").Path + "\auto\profile"
    $installedAliasesFile = "$autoProfilePath\$filename"

    if (!(Test-Path $installedAliasesFile)) {
        Install-File $stage $PSScriptRoot $autoProfilePath $filename
    }

    return $installedAliasesFile
}

function installPratAlias($stage, [string] $filename, [string] $variableName, [string] $Name, [string] $Value) {
    $installedAliasesFile = installOrGetInstalledAliasesFile $stage $filename

    $lineArray = [LineArray]::new((Import-TextFile $installedAliasesFile))
    Add-HashTableItemInPowershellScript $lineArray $variableName $Name (ConvertTo-Expression $Value)
    Install-TextToFile $stage $installedAliasesFile $lineArray.ToString()

    # Add/update it in the current execution environment.
    New-Alias -Name $Name -Value $Value -Scope Global -Force
}

# Packages that set up aliases can be annoying. e.g. gerardog.gsudo thinks it does so and yet I can't find any evidence of it. (Maybe it just adds a cmd.exe alias)
#
# Anyway, I do want to specifically opt in to aliases for use in scripts, and do it reliably. i.e. both add it in the current execution environment ('spackle')
# and add it somewhere that's included in PowerShell profile. (This still leaves a gap - in other already-open windows - and I'll just try to avoid that case.)
function installPratScriptAlias($stage, [string] $Name, [string] $Value) {
    installPratAlias $stage 'scriptAliases.ps1' 'installedAliases' $Name $Value
}

function Install-InteractiveAlias($stage, [string] $Name, [string] $Value) {
    installPratAlias $stage 'interactiveAliases.ps1' 'installedAliases' $Name $Value
}
