# Defines 'Update-PatchSlickOpenWkspace', which does a specific patch to SlickEdit's 'workspace_open' function.
#
# Preserving line-endings (e.g. by using LineArray) is particularly helpful for SlickEdit source code, 
# because SlickEdit uses Unix line-endings even on Windows.

function Find-WorkspaceOpenCommand($lineArray)
{
    [int] $idxFirst = Find-MatchingLine $lineArray $null "^_command int workspace_open,"
    if ($idxFirst -eq -1) { return $null; }

    $line = $lineArray.lines[$idxFirst]
    $targetIndentLevel = Get-IndentLevel $line

    [int] $idxLast = Find-CorrespondingIndent $lineArray $targetIndentLevel @{idxFirst = $idxFirst+2; idxLast=$lineArray.lines.Count-1}
    if ($idxLast -eq -1) { return $null; }

    return @{idxFirst = $idxFirst; idxLast = $idxLast}
}

function Find-OpenDialogStatement($lineArray, $range)
{
    # We rely on there being another statement after this one.

    [int] $idxFirst = Find-MatchingLine $lineArray $null "^\s*WorkspaceFilename=_OpenDialog\("
    if ($idxFirst -eq -1) { return $null; }

    $line = $lineArray.lines[$idxFirst]
    $targetIndentLevel = Get-IndentLevel $line

    [int] $nextStatement = Find-CorrespondingIndent $lineArray $targetIndentLevel @{idxFirst = $idxFirst+1; idxLast=$range.idxLast}
    if ($nextStatement -eq -1) { return $null; }
    
    return @{idxFirst = $idxFirst; idxLast = $nextStatement - 1}
}

# Patch the behavior of Open Workspace. I want it to start in the folder I keep project files in, and to only list *.vpw files, and
# (at least as of v25) those aren't configurable.
# Returns the new file contents, or $null if nothing to do
#
# .PARAM defaultProjectFolder
#    This can't have spaces in it, and there are probably other limitations because we don't have code for escaping Slick-C special
#    characters. An example that works, is: 'C:\SlickProjects'
function Update-PatchSlickOpenWkspace($file, $defaultProjectFolder)
{
    $script = Import-TextFile $file
    $linearray = [LineArray]::new($script)

    $range = Find-WorkspaceOpenCommand $linearray
    if ($range -eq $null) {
        Write-Warning "Skipping broken patch for: $file. (Couldn't find command)"
        return $null
    }

    $range = Find-OpenDialogStatement $linearray $range
    if ($range -eq $null) {
        Write-Warning "Skipping broken patch for: $file. (Couldn't find OpenDialog statement)"
        return $null
    }

    $linesChanged = Format-ReplaceMatchingLines $linearray $range "'.*', *// Initial wildcards" "'*.vpw',     // Initial wildcards"
    if ($linesChanged -ne 1) {
        Write-Warning "Skipping broken patch for: $file. (trouble with initial wildcards)"
        return $null
    }

    $linesChanged = Format-ReplaceMatchingLines $linearray $range "'.*', *// Initial directory" "'$defaultProjectFolder',      // Initial directory"
    if ($linesChanged -ne 1) {
        Write-Warning "Skipping broken patch for: $file. (trouble with initial directory)"
        return $null
    }

    return $linearray.ToString()
}

