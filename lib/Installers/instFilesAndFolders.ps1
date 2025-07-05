function writeUpdateDetailIf([string] $message, [bool] $doIt) {
    if ($doIt) { Write-Host $message -F Yellow }
}

# Install one file, creating the containing folder if needed.
function Install-File($stage, $srcDir, $destDir, $srcFilename, $destFilename, [switch] $ShowUpdateDetails) {
    if ($null -eq $destFilename) {
        $destFilename = $srcFilename
    }
    $copyFile = $false

    if ((Test-Path -PathType Container $destDir) -ne $True) {
        $stage.OnChange()
        writeUpdateDetailIf "mkdir $destDir" $ShowUpdateDetails
        mkdir $destDir | Out-Null
        $copyFile = $true
    }
    elseif ((Test-Path -PathType Leaf $destDir\$destFilename) -ne $True) {
        $stage.OnChange()
        writeUpdateDetailIf "Doesn't exist: $destDir\$destFilename" $ShowUpdateDetails
        $copyFile = $true
    } else {
        fc.exe /a $srcDir\$srcFilename $destDir\$destFilename | Out-Null
        if ($? -eq $false) {
            $stage.OnChange()
            $copyFile = $true
            writeUpdateDetailIf "Not identical: $destDir\$destFilename" $ShowUpdateDetails
        }
    }

    if ($copyFile) {
        writeUpdateDetailIf "copy $srcDir\$srcFilename -Destination $destDir\$destFilename" $ShowUpdateDetails
        copy $srcDir\$srcFilename -Destination $destDir\$destFilename
    }

}

# Install one folder
function Install-Folder($stage, $destDir) {
    if ((Test-Path -PathType Container $destDir) -ne $True) {
        $stage.OnChange()
        mkdir $destDir | Out-Null
        if (-not $?) {
            throw ("Failed to create '$destDir'")
        }
        if (Get-CurrentUserIsElevated) {
            icacls $destDir /setowner $env:username /q | Out-Null
            if (-not $?) {
                throw ("Failed to set ownership on '$destDir'")
            }
        }
    }
}

function isFileReadOnly($path) {
    return [bool] (Get-ItemProperty -Path $path -Name IsReadOnly).IsReadOnly
}

# Install a directory full of files
function Install-SetOfFiles($stage, $srcDir, $destDir, [switch] $SetReadOnly) {
    Install-Folder $stage $destDir

    # Now install/update file
    foreach ($file in Get-ChildItem $srcDir) {
        $filename = $file.Name
        $copyThisFile = $false
        $destFileExists = (Test-Path -PathType Leaf $destDir\$filename)

        if (-not $destFileExists) {
            $copyThisFile = $true
        } else {
            fc.exe /a $srcDir\$filename $destDir\$filename | Out-Null
            if ($? -eq $false) {
                $copyThisFile = $true
            } else {
                if ($SetReadOnly -and -not (isFileReadOnly $destDir\$filename)) {
                    $copyThisFile = $true
                }
            }
        }

        if ($copyThisFile) {
            $stage.OnChange()
            if ($SetReadOnly -and $destFileExists) {
                # Powershell doesn't allow updates if the read-only flag is set
                Set-ItemProperty -Path $destDir\$filename -Name IsReadOnly -Value $false
            }
            copy $srcDir\$filename -Destination $destDir\$filename
            if ($SetReadOnly) {
                Set-ItemProperty -Path $destDir\$filename -Name IsReadOnly -Value $true
            }
        }
    }
}


# Delete a set of files from a directory
#
# Useful for migration/cleanup.
#
# If the directory doesn't exist, silently does nothing.
function Install-DeleteFiles($stage, $destDir, $listOfFilenames) {
    if ((Test-Path -PathType Container $destDir)) {
        foreach ($filename in $listOfFilenames) {
            if ((Test-Path -PathType Leaf $destDir\$filename)) {
                $stage.OnChange()
                Remove-Item $destDir\$filename
            }
        }
    }
}

# Install a file from an in-memory text string
function Install-TextToFile($stage, $file, $newText, [switch] $ShowUpdateDetails, [switch] $PreserveAcls=$false, [switch] $BackupFile=$false, [switch] $SudoOnWrite=$false) {
    $needUpdate = $False
    $acl = $null

    if (Test-Path -PathType Leaf $file) {
        $currentText = Import-TextFile $file

        if ($currentText -ne $newText) {
            writeUpdateDetailIf "Not identical: $file" $ShowUpdateDetails
            $needUpdate = $True
        }
    } else {
        writeUpdateDetailIf "Doesn't exist: $file" $ShowUpdateDetails
        $needUpdate = $True
        $BackupFile = $False
    }

    if ($needUpdate) {
        if ($PreserveAcls -and (Test-Path -PathType Leaf $file)) {
            $acl = Get-Acl $file
#           [string] $s = $acl | format-list | out-string
#           Write-Warning $s
        }
        if ($BackupFile) {
            if ($SudoOnWrite) {
                Invoke-Gsudo { 
                    $file = $using:file
                    copy $file ($file + ".backup")
                }
            } else {
                copy $file ($file + ".backup")
            }
        }

        $stage.OnChange()
        writeUpdateDetailIf "Updating (Install-TextToFile): $file" $ShowUpdateDetails
        if ($SudoOnWrite) {
            $newText | Invoke-Gsudo { Out-File -Encoding ASCII $using:file } 
            if ($acl) { $acl | Invoke-Gsudo { Set-Acl $using:file } }
        } else {
            $newText | Out-File -Encoding ASCII $file   # Seems equivalent: Set-Content $newText -LiteralPath $file
            if ($acl) { $acl | Set-Acl $file }
        }
    }
}

function areByteArraysEqual([byte[]] $a1, [byte[]] $a2) {
    return @(Compare-Object $a1 $a2 -SyncWindow 0).Length -eq 0
}

# Install a binary file from an in-memory array of bytes
function Install-BinaryDataToFile($stage, $file, [byte[]] $newData, [switch] $BackupFile=$false, [switch] $ShowUpdateDetails) {
    $needUpdate = $False

    if (Test-Path -PathType Leaf $file) {
        [byte[]] $currentData = [System.IO.File]::ReadAllBytes($file)

        if (!(areByteArraysEqual $currentData $newData)) {
            writeUpdateDetailIf "Not identical: $file" $ShowUpdateDetails
            $needUpdate = $True
        }
    } else {
        writeUpdateDetailIf "Doesn't exist: $file" $ShowUpdateDetails
        $needUpdate = $True
        $BackupFile = $False
    }

    if ($needUpdate) {
        if ($BackupFile) {
            copy $file ($file + ".backup")
        }

        $stage.OnChange()
        writeUpdateDetailIf "Updating (Install-BinaryDataToFile): $file" $ShowUpdateDetails

        [System.IO.File]::WriteAllBytes($file, $newData)
    }
}

# Install a SMB share
function Install-SmbShare($stage, $shareName, $targetFolder, $credential) {
    $cimInstance = Get-SmbShare | ? {$_.Name -eq $shareName}

    [bool] $needUpdate = $false
    [bool] $needCreate = $false

    if ($null -eq $cimInstance) {
        $needCreate = $true
        $stage.OnChange()
    } else {
        if ($cimInstance.Path -ne $targetFolder) {
            $needUpdate = $true
            $stage.OnChange()
        }
    }

    if ($needUpdate) {
        Remove-SmbShare $shareName
    }
    if ($needCreate) {
        # TODO: This operation requires sudo
        New-SmbShare -Name $shareName -Path $targetFolder -ReadAccess $credential
    }

}

function getManifestFromFolder($srcDir) {
    $lines = (Get-ChildItem -Recurse $srcDir\* | 
        %{ Get-FileHash -Algorithm SHA256 $_.FullName }) | 
        %{ ($_.Hash) + "`n    " + ($_.Path)+"`n"}

    return [System.String]::Join("", $lines)
}

# Install a .zip file (with a text manifest file) from a tree of source files
function Install-ZipFileFromFolder($stage, $srcDir, $destPathname, $manifestFilename, [switch] $ShowUpdateDetails) {
    if (-not $srcDir.EndsWith('\')) {
        $srcDir = $srcDir + '\'
    }
    $newManifest = getManifestFromFolder($srcDir)

    $updateManifest = $False

    if (Test-Path -PathType Leaf $manifestFilename) {
        $currentManifest = Import-TextFile $manifestFilename

        if ($currentManifest -ne $newManifest) {
            writeUpdateDetailIf "Manifest not identical: $manifestFilename" $ShowUpdateDetails
            $updateManifest = $True
        }
    } else {
        writeUpdateDetailIf "Manifest doesn't exist: $manifestFilename" $ShowUpdateDetails
        $updateManifest = $True
    }

    if ($updateManifest -or -not (Test-Path -PathType Leaf $destPathname)) {
        $stage.OnChange()
        if (-not $updateManifest) { writeUpdateDetailIf "Recreating zip, though manifest was unchanged" $ShowUpdateDetails }

        writeUpdateDetailIf "Updating zip file: $destPathname" $ShowUpdateDetails
        Compress-Archive -Path "$srcDir*" -DestinationPath $destPathname -Force
    }

    if ($updateManifest) {
        writeUpdateDetailIf "Updating manifest: $manifestFilename" $ShowUpdateDetails
        $newManifest | Out-File -Encoding ASCII $manifestFilename
    }
}


# Apply the given set of substitutions to the given template string, return the resulting string.
# Placeholders look like [THIS]. (Square brackets, all caps).
#
# Throws if there are any placeholders left
function Format-ReplacePlaceholdersInTemplateString([string] $template, $substitutions) {
    $result = $template

    $substitutions.Keys | % { 
        $placeholder = "\[" + $_.ToUpper() + "\]"
        $value = $substitutions.Item($_)
        $result = $result -CReplace $placeholder, $value
    }

    # Check for remaining placeholders
    if ($result -cmatch "\[([A-Z]+)\]") {
        $placeholderName = $matches[1].ToLower()
        throw "Missing value for placeholder '$placeholderName'"
    }

    return $result
}


# Install a soft link to a file.
# Here 'dest' is where the link is created, and it points back to 'src', i.e. 'src' is the target of the link.
#
# Note: In Windows, a soft link is known as a 'symbolic link' in Windows. And apparently Windows means something else by 'soft link' - a 'junction' - but that's its business.
function Install-SoftLinkToFile($stage, $srcDir, $destDir, $srcFilename, $destFilename) {
    if ($null -eq $destFilename) {
        $destFilename = $srcFilename
    }

    if ((Test-Path -PathType Container $destDir) -ne $True) {
        throw "Containing folder not found: $destDir"
    }

    if ((Test-Path $destDir\$destFilename) -eq $True) {
        $item = Get-Item $destDir\$destFilename
        if ($item.GetType().Name -ne "FileInfo") { throw "Unexpected item type: $($item.GetType().Name) for file: '$destDir\$destFilename'"}
        if ($item.LinkType -ne "SymbolicLink")  { 
            $stage.OnChange()
            Remove-Item $destDir\$destFilename
        } else {
            $sameTarget = (Resolve-Path $srcDir\$srcFilename).Path -eq (Resolve-Path $item.LinkTarget).Path
            if ($sameTarget) { return }
        }
    }

    $stage.OnChange()
    Write-Host -ForegroundColor Green "New-Item -ItemType SymbolicLink -Path $destDir\$destFilename -Value $srcDir\$srcFilename"
    sudo {New-Item -ItemType SymbolicLink -Path $destDir\$destFilename -Value $srcDir\$srcFilename}
}


