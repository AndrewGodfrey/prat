# Functions for manipulating parts of a source-code file, held in a lineArray (see TextFileEditor.psm1).
# By using lineArray, we can preserve the file's line-ending format. e.g. Slick-C files use Unix line-endings.
function Get-IndentLevel([string] $line)
{
    $dummy = $line -match "^(\s)*"
    return $Matches[0].Length
}

# Search the given range (or the entire $lineArray) for a pattern
# Returns an integer. -1 if not found.
function Find-MatchingLine(
    $lineArray,
    $range,
    $pattern)
{
    if ($null -eq $range) { $range = @{ idxFirst = 0; idxLast = $lineArray.lines.Count - 1} }

    [int] $idx = 0
    for ($idx=$range.idxFirst; $idx -le $range.idxLast; $idx++) {
        if ($lineArray.lines[$idx] -match $pattern) {
            return $idx
        }
    }

    return -1
}

# Find the next non-blank line which matches the given indent level
# Returns an integer. -1 if not found.
function Find-CorrespondingIndent(
    $lineArray,
    $targetIndentLevel,
    $range  # Range to search. Should begin on the line AFTER the one whose indent level you want to match.
    )
{
    [int] $idx = 0
    for ($idx=$range.idxFirst;$idx -le $range.idxLast; $idx++) {
        $line = $lineArray.lines[$idx]
        if ($line -match '^\s*$') { continue; }
        $currentIndent = Get-IndentLevel $line
        if ($currentIndent -eq $targetIndentLevel) {
            return $idx
        }
        if ($currentIndent -lt $targetIndentLevel) {
            Write-Warning "Unexpected indentation at line $idx"
        }
    }

    return -1
}

# Get (or guess) the indent level for the line after the first line in the range
function Get-SubIndent(
    $lineArray,
    $range)
{
    $indent = Get-IndentLevel $lineArray.lines[$range.idxFirst]
    if ($range.idxLast - $range.idxFirst -gt 1) {
        $siLineNumber = $range.idxFirst + 1

        $subIndent = Get-IndentLevel $lineArray.lines[$siLineNumber]
        if ($subIndent -le $indent) { Write-Warning "Inconsistent indentation on line ${$siLineNumber + 1}" }
    } else {
        $subIndent = $indent + 4
    }
    return $subIndent
}

# Search the given range (or the entire $lineArray) for a pattern, replace the line
# Returns the number of lines changed, or 0 if not found.
function Format-ReplaceMatchingLines(
    $lineArray,
    $range,
    $pattern,
    $replacement)
{
    if ($null -eq $range) { $range = @{ idxFirst = 0; idxLast = $lineArray.lines.Count - 1} }

    [int] $replacementCount = 0
    [int] $idx = 0
    for ($idx=$range.idxFirst; $idx -le $range.idxLast; $idx++) {
        if ($lineArray.lines[$idx] -match $pattern) {
            $replacementCount++
            $lineArray.lines[$idx] = $lineArray.lines[$idx] -replace $pattern, $replacement
        }
    }

    return $replacementCount
}

