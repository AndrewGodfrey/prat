# Tools for creating a Windows Shortcut (.lnk file) to a console application.
#
# Limitations:
#   - Only supports a limited set of properties that I find to be useful. (Look at calls to 'processProperty' for a list).
#     Many properties have implementation quirks, and the complexity of the .LNK format should be avoided as much as possible.
#   - Doesn't pay attention to "RelativePath". I see it set in the template file, but when testing with absolute target paths, Windows
#     seems to be ignoring RelativePath.


# Get the given property, or supply the default if not specified. In either case record that we've processed this property (for detecting unsupported inputs).
function processProperty([string] $propertyName, $defaultValue, $properties, $processed) {
    $processed[$propertyName] = $true
    $value = $properties[$propertyName]
    if ($null -ne $value) { return $value }
    return $defaultValue
}

# These are all the properties we'll set (overwriting what's in template.bin)
function applySupportedProperties($s, $properties, $deferredWork) {
    $processed = @{}

    $s.IconIndex = processProperty "iconIndex" 0 $properties $processed

    $s.StringData.IconLocation         = processProperty "iconFile" '%SystemRoot%\System32\shell32.dll' $properties $processed
    $s.StringData.WorkingDir           = processProperty "workingDirectory" $home $properties $processed
    $s.StringData.CommandLineArguments = processProperty "arguments" "" $properties $processed
    $s.StringData.NameString           = processProperty "description" "" $properties $processed

    if ((processProperty "runAsAdmin" $false $properties $processed)) {
        # Wouldn't you know it - this is impossible to change from ShellLink.
        # If you try, you get the error:  'LinkFlags' is a ReadOnly property.
        # This happens even if you try to access the base class, I guess because the Flags property is virtual.
        
        # So instead, we defer this work until after we convert the link to a byte array. Fun!
        $deferredWork["runAsAdmin"] = $true
    }

    # This leaves cruft because the template file doesn't use EnvironmentVariableDataBlock for the target.
    # But Windows Shell does seem to pick up the change.
    $s.ExtraData.EnvironmentVariableDataBlock = [ShellLink.Structures.EnvironmentVariableDataBlock]::new(
        (processProperty "targetPath" "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" $properties $processed)
    )

    $cdb = $s.ExtraData.ConsoleDataBlock

    # ShellLink.Shortcut just exposes FontSize as a UInt32, and has a comment on it that's wrong.
    # Correct documentation: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-shllink/e6b432b4-5a49-4826-9c25-e28695e8dd0c
    # The font height (called "Size" in the UI) is actually in the high 16 bits, and the low 16 should be 0 (for vector fonts).
    $fontHeight = [uint16] (processProperty "fontSize" 14 $properties $processed)
    $cdb.FontSize = ([uint32] $fontHeight) -shl 16

    $cdb.AutoPosition =
        processProperty "autoPosition" $false $properties $processed

    $windowOrigin = processProperty "windowOrigin" @(5, 55) $properties $processed
    $cdb.WindowOriginX = $windowOrigin[0]
    $cdb.WindowOriginY = $windowOrigin[1]

    $windowSize = processProperty "windowSize" @(200, 38) $properties $processed
    $cdb.WindowSizeX = $windowSize[0]
    $cdb.WindowSizeY = $windowSize[1]

    $bgColor = processProperty "bgColor" ([byte[]] @(12, 12, 12)) $properties $processed
    $cdb.ColorTable[4] = $bgColor[0]
    $cdb.ColorTable[5] = $bgColor[1]
    $cdb.ColorTable[6] = $bgColor[2]
    [uint16] $flags = $cdb.FillAttributes
    $flags = $flags -band 0xff0f
    $flags = $flags -bor 0x10
    $cdb.FillAttributes = $flags

    foreach ($key in $properties.Keys) {
        if ($processed[$key] -ne $true) {
            throw "Unrecognized property name: $key"
        }
    }
}

# Creates a Windows shortcut to a console application
function New-WindowsConsoleShortcut($properties, $nugetPackageInstallationFolder) {
    # Documentation: [Shortcut.CS](https://github.com/securifybv/ShellLink/blob/master/Shortcut.cs)
    Add-NugetPackageType "shelllink" $nugetPackageInstallationFolder
    $s = [ShellLink.Shortcut]::ReadFromFile("$PSScriptRoot\windowsConsoleShortcut\template.bin")

    $deferredWork = @{}
    applySupportedProperties $s $properties $deferredWork

    $result = $s.GetBytes()
    if ($deferredWork["runAsAdmin"]) {
        $result[0x15] = $result[0x15] -bor 0x20
    }
    return $result
}


function Install-WindowsConsoleShortcut($stage, $filename, $properties, $nugetPackageInstallationFolder) {
    $newData = New-WindowsConsoleShortcut $properties $nugetPackageInstallationFolder
    Install-BinaryDataToFile $stage $filename $newData -BackupFile
}

