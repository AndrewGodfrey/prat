#Requires -PSEdition Core

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

# Install one user folder. If it's not under $home, also overwrite its permissions with those of $home\prat
function Install-Folder($stage, $destDir) {
    if ((Test-Path -PathType Container $destDir) -ne $True) {
        $stage.OnChange()
        mkdir $destDir | Out-Null
        if (-not $?) {
            throw ("Failed to create '$destDir'")
        }

        if (!(Test-PathIsUnder $destDir $home)) {
            $sourceACL = Get-Acl "$home\prat"
            $sourceACL.SetAccessRuleProtection($true, $false)
            Invoke-Gsudo { Set-Acl -Path $using:destDir -AclObject $using:sourceACL }
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
function Install-TextToFile($stage, $file, $newText, [switch] $ShowUpdateDetails, [switch] $PreserveAcls=$false, [switch] $BackupFile=$false, [switch] $SudoOnWrite=$false, [switch] $SetReadOnly=$false) {
    $needUpdate = $False
    $acl = $null
    $newText = ConvertTo-UnixLineEndings $newText

    if (Test-Path -PathType Leaf $file) {
        $currentText = Import-TextFile $file

        if ($currentText -ne $newText) {
            if ($ShowUpdateDetails) {
                writeUpdateDetailIf "Not identical: $file" $true
                writeUpdateDetailIf "Lengths: current=$($currentText.Length) new=$($newText.Length)" $true
                # Find first difference
                for ($i = 0; $i -lt [Math]::Min($currentText.Length, $newText.Length); $i++) {
                    if ($currentText[$i] -ne $newText[$i]) {
                        writeUpdateDetailIf "First diff at index $($i): current=[$(([int]$currentText[$i]))] new=[$(([int]$newText[$i]))]" $true
                        break
                    }
                }
            }
            $needUpdate = $True
        } elseif ($SetReadOnly -and -not (isFileReadOnly $file)) {
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
        if ($SetReadOnly -and (Test-Path -PathType Leaf $file)) {
            Set-ItemProperty -Path $file -Name IsReadOnly -Value $false
        }
        if ($SudoOnWrite) {
            $newText | Invoke-Gsudo { Out-File -Encoding utf8NoBOM $using:file }
            if ($acl) { $acl | Invoke-Gsudo { Set-Acl $using:file } }
        } else {
            $newText | Out-File -Encoding utf8NoBOM $file   # Seems equivalent: Set-Content $newText -LiteralPath $file
            if ($acl) { $acl | Set-Acl $file }
        }
        if ($SetReadOnly) {
            Set-ItemProperty -Path $file -Name IsReadOnly -Value $true
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
function Install-SmbShare($stage, $shareName, $targetFolder, $userCredential, [switch] $ShowUpdateDetails) {
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
        $ErrorActionPreference = "stop"
        writeUpdateDetailIf "Updating (Install-SmbShare): $shareName, $userCredential" $ShowUpdateDetails
        Invoke-Gsudo {
            New-SmbShare -Name $using:shareName -Path $using:targetFolder -ReadAccess $using:userCredential | Out-Null
        }        
    }
}

# Quietly test if a SMB share connection is present
function Test-SmbShareConnection([string] $sharePath) {
    $ErrorActionPreference = "stop"
    $exists = $false
    try { 
        $exists = Test-Path $sharePath
    } 
    catch 
    { 
        return $false 
    }
    return $exists
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
        $newManifest | Out-File -Encoding utf8NoBOM $manifestFilename
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


# Recursively merge the contents of $sourceDir into $destDir.
# Two-phase: first validate (no mutations), then execute.
# Files in $sourceDir that don't exist in $destDir are moved.
# Files that exist in both with identical content are silently removed from source.
# Files that exist in both with different content get the source copy saved as .local-conflict.
# Subdirectories are merged recursively.
function Merge-DirectoryInto([string] $sourceDir, [string] $destDir) {
    # Phase 1: Validate - check for blockers before mutating anything
    Assert-MergeIsSafe $sourceDir $destDir

    # Phase 2: Execute
    Invoke-MergeDirectoryInto $sourceDir $destDir
}

# Phase 1: Recursively check that the merge can proceed without issues.
# Throws if there are unresolvable conflicts (e.g. existing .local-conflict files,
# or type mismatches between source and dest).
function Assert-MergeIsSafe([string] $sourceDir, [string] $destDir) {
    $children = Get-ChildItem $sourceDir -Force
    foreach ($child in $children) {
        $destPath = Join-Path $destDir $child.Name
        if ($child.PSIsContainer) {
            if (Test-Path -PathType Container $destPath) {
                Assert-MergeIsSafe $child.FullName $destPath
            } elseif (Test-Path $destPath) {
                throw "Cannot merge directory '$($child.FullName)': a file exists at '$destPath'"
            }
        } else {
            if (Test-Path $destPath) {
                if (Test-Path -PathType Container $destPath) {
                    throw "Cannot merge file '$($child.FullName)': a directory exists at '$destPath'"
                }
                # Check if this would be a real conflict needing .local-conflict
                if ((Get-FileHash $child.FullName).Hash -ne (Get-FileHash $destPath).Hash) {
                    $conflictPath = Join-Path $destDir ($child.Name + ".local-conflict")
                    if (Test-Path $conflictPath) {
                        throw "Conflict file already exists: '$conflictPath'. Resolve existing conflicts before re-running."
                    }
                }
            }
        }
    }
}

# Phase 2: Perform the actual merge. Caller must run Assert-MergeIsSafe first.
function Invoke-MergeDirectoryInto([string] $sourceDir, [string] $destDir) {
    $children = Get-ChildItem $sourceDir -Force
    foreach ($child in $children) {
        $destPath = Join-Path $destDir $child.Name
        if ($child.PSIsContainer) {
            if (Test-Path -PathType Container $destPath) {
                Invoke-MergeDirectoryInto $child.FullName $destPath
                # Source subdirectory should now be empty
                Remove-Item $child.FullName
            } else {
                Move-Item $child.FullName $destPath
            }
        } else {
            if (-not (Test-Path $destPath)) {
                Move-Item $child.FullName $destPath
            } else {
                if ((Get-FileHash $child.FullName).Hash -eq (Get-FileHash $destPath).Hash) {
                    # Same content - just remove the source copy
                    Remove-Item $child.FullName -Force
                } else {
                    # Different content - keep both, rename the local copy
                    $conflictName = $child.Name + ".local-conflict"
                    $conflictPath = Join-Path $destDir $conflictName
                    Move-Item $child.FullName $conflictPath
                    Write-Warning "File conflict: '$($child.Name)' exists in both local and sync target. Local copy saved as '$conflictName' in '$destDir'"
                }
            }
        }
    }
}

# Install a directory junction.
# $targetDir is the real location of the data. $linkDir is the junction that points to it.
# If $linkDir already exists as a regular directory, fails unless -MigrateExisting is specified,
# in which case its contents are merged into $targetDir first.
# Junctions don't require elevation on Windows.
function Install-DirectoryJunction($stage, [string] $targetDir, [string] $linkDir, [switch] $MigrateExisting) {
    # Ensure the target directory exists
    if (-not (Test-Path -PathType Container $targetDir)) {
        if (Test-Path $targetDir) {
            throw "Expected directory at '$targetDir', found a file"
        }
        $stage.OnChange()
        mkdir $targetDir -Force | Out-Null
    }

    if (Test-Path $linkDir) {
        $item = Get-Item $linkDir -Force
        if ($item.LinkType -eq "Junction") {
            # Already a junction - check it points to the right place
            if ($item.Target -contains $targetDir) { return }
            # Wrong target - remove and recreate
            $stage.OnChange()
            $item.Delete()
        } elseif ($item.PSIsContainer) {
            if (-not $MigrateExisting) {
                throw "Directory already exists at '$linkDir'. Use -MigrateExisting to merge contents into target."
            }
            # Regular directory - move contents to target, then replace with junction
            $stage.OnChange()
            Merge-DirectoryInto $linkDir $targetDir
            Remove-Item $linkDir
        } else {
            throw "Expected directory or junction at '$linkDir', found file"
        }
    }

    # Ensure parent directory exists
    $parentDir = Split-Path $linkDir -Parent
    if (-not (Test-Path -PathType Container $parentDir)) {
        mkdir $parentDir -Force | Out-Null
    }

    $stage.OnChange()
    New-Item -ItemType Junction -Path $linkDir -Target $targetDir | Out-Null
}

# Install a soft link to a file.
# Here 'dest' is where the link is created, and it points back to 'src', i.e. 'src' is the target of the link.
#
# Note: In Windows, a soft link is known as a 'symbolic link'. And apparently Windows means something else by 'soft link' - a 'junction' - but that's its business.
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
    $linkPath = "$destDir\$destFilename"
    $linkValue = "$srcDir\$srcFilename"
    # Write-Host -ForegroundColor Green "New-Item -ItemType SymbolicLink -Path $linkPath -Value $linkValue"
    Invoke-Gsudo {
        New-Item -ItemType SymbolicLink -Path $using:linkPath -Value $using:linkValue | Out-Null
    }
}


