#
# Module manifest for module 'Installers'
#
# Generated by: Andrew Godfrey
#
# Generated on: 4/11/2024
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'Installers.psm1'

# Version number of this module.
ModuleVersion = '1.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '3966bc8c-5dab-4dca-94de-a6692153489c'

# Author of this module
Author = 'Andrew Godfrey'

# Copyright statement for this module
Copyright = 'Copyright (c) 2024 Andrew Godfrey'

# Description of the functionality provided by this module
# Description = "'Installers' in Prat, are functions which can 'install' various resources for the current user, or _very quickly_ determine that no change is needed."

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
	'Format-ReplacePlaceholdersInTemplateString', 'New-Subfolder', 'New-FolderAndParents',
	'Start-Installation',
	'Install-File', 'Install-Folder', 'Install-SetOfFiles', 'Install-DeleteFiles', 'Install-TextToFile', 'Install-BinaryDataToFile', 'Install-SmbShare', 'Install-ZipFileFromFolder',
	'Install-RegistryKey', 'Install-RegistryDwordValue', 'Install-RegistryStringValue', 'Install-RegistryBinaryValue',
	'Install-PratPackage',
	'Install-WingetPackage', 'Install-PackageDnspy', 'Install-PackageNuget', 'Install-PackageWget', 'Install-PackageWindbg', 'Install-PackageWinmerge',
	'Install-NugetPackage', 'Add-NugetPackageType',
	'Set-InstalledItemVersion', 'Get-InstalledItemVersion', 'Test-InstalledItemVersion', 'Remove-InstalledItem',
	'Install-WindowsStartMenuLocalOnly', 'Install-WindowsSecondaryClockUTC', 'Install-WindowsFileAssociation', 'Install-WindowsAppVerbAssociation',
	'New-WindowsConsoleShortcut', 'Install-WindowsConsoleShortcut',
	'Install-CustomBrowserHomePage', 'Install-PsProfile'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/AndrewGodfrey/prat/blob/main/LICENSE'

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

