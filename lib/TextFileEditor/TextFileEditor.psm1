# Tools for in-memory editing of a text file, in a line-oriented way.
# NOT suitable for very large text files (over 1MB, say). Reasons:
#   - It's designed for in-memory editing, but even more significant:
#   - Its simple approach to incremental editing will have O(n^2) effects on memory allocation patterns.
#
# Data structure:
# 
# 'range': @{idxFirst=<int>, idxLast=<int>}, e.g. as returned by Find-XmlSection. Line numbers are 0-based. (i.e. for user output, add 1).
#    

# Load a text file as a string.
function Import-TextFile($file) {

    $contents = (Get-Content -Raw $file)

    # Weird, "Get-Content -Raw" always appends an extra newline - I see this whether or not the file ends in a newline.
    $contents = $contents -replace '\r?\n$', ''
    return $contents
}

function Format-IndentLine(
    $line,
    $indentLevel)
{
    return " "*$indentLevel + $line
}

class LineArray {
    hidden [string] $nl # Newline format
    hidden $lines

    [string] GetNl() { return $this.nl }

    LineArray([string] $data) {
        # Choose one line ending - just using simple priority, no statistics.
        if ($data -match "`r`n") {
            $this.nl = "`r`n"
        } elseif ($data -match "`r") {
            $this.nl = "`r"
        } else {
            $this.nl = "`n"
        }

        $this.lines = ($data -replace "`r`n|`r|`n", "`n").Split("`n")
    }

    [int] GetLineCount() {
        if ($this.lines.Count -gt 1) { return $this.lines.Count }
        if ($this.lines.Count -le 0) { return 0 } # Impossible I think?
        if ($this.lines[0] -eq "") { return 0 }
        return 1
    }

    [bool] IsEmpty() {
        return $this.GetLineCount() -eq 0
    }

    [string] ToString() {
        return [System.String]::Join($this.nl, $this.lines)
    }

    [Void] IndentEachLine([int] $indentLevel) {
        if ($indentLevel -lt 0) { throw "NYI: Unindent" }
        $this.lines = $this.lines | ForEach-Object { Format-IndentLine $_ $indentLevel }
    }

    # Given:
    # $range: A target range. This range can be empty, in which case $range.idxFirst says where to insert the text, and $range.idxLast = $range.idxFirst - 1.
    # $laNew: New lines. This can be empty, in which case we'll just delete the specified lines.
    #
    # Replaces the target lines with the new lines. Ignores $laNew.nl.
    [Void] ReplaceLines($range, [LineArray] $laNew) {
        $updatedLines = @()
        if ($range.idxFirst -gt 0) {
            $updatedLines += $this.lines[0..($range.idxFirst - 1)]
        }
        if (!($laNew.IsEmpty())) {
            $updatedLines += $laNew.lines
        }
        if ($range.idxLast -lt ($this.lines.Length - 1)) {
            $updatedLines += $this.lines[($range.idxLast + 1)..($this.lines.Length - 1)]
        }
        $this.lines = $updatedLines
    }

    # Inserts the given LineArray's contents at the given line number
    [Void] InsertLines($idxLine, [LineArray] $laNew) {
        $itemRange = @{ idxFirst = $idxLine; idxLast = $idxLine - 1 }
        $this.ReplaceLines($itemRange, $laNew)
    }

    # Removes the given lines
    [Void] RemoveLines($range) {
        $laNew = [LineArray]::new("")
        $this.ReplaceLines($range, $laNew)
    }

    [LineArray] GetLines($range) {
        $laNew  = [LineArray]::new($this.nl)

        $laNew.lines = $this.lines[$range.idxFirst..$range.idxLast]
        return $laNew
    }
}

# Given:
# $data: An in-memory text file
# $range: A range (documented at top of file)
# $newText: Some replacement text
#
# Returns $data with the given lines removed and $newText inserted where they were.
function Format-ReplaceLines($data, $range, $newText) {
    $lineArray = [LineArray]::new($data)
    $laNew = [LineArray]::new($newText)
    $lineArray.ReplaceLines($range, $laNew)
    return $lineArray.ToString()
}


# Given:
# $data: An in-memory text file
# $range: A range (documented at top of file)
#
# Returns just the given lines, as a single string
function Read-Lines($data, $range) {
    $lineArray = [LineArray]::new($data)
    $laNew = $lineArray.GetLines($range)
    return $laNew.ToString()
}

# Returns $data with $newText inserted at the given (0-based) line number
function Add-Lines($data, $idxLine, $newText) {
    if ($idxLine -lt 0) { throw "Invalid line number: $idxLine" }

    $lineArray = [LineArray]::new($data)
    $laNew = [LineArray]::new($newText)
    $range = @{ idxFirst = $idxLine; idxLast = $idxLine - 1}
    $lineArray.ReplaceLines($range, $laNew)
    return $lineArray.ToString()
}

. $PSScriptRoot\editXml.ps1

. $PSScriptRoot\editCode.ps1

. $PSScriptRoot\editPowershellScript.ps1


