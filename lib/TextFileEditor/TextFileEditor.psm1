# Tools for in-memory editing of a text file, in a line-oriented way.
# NOT suitable for very large text files (over 1MB, say). Reasons:
#   - It's designed for in-memory editing, but even more significant:
#   - Its simple approach to incremental editing will have O(n^2) effects on memory allocation patterns.
#
# Data structure:
# 
# 'range': @{idxFirst=<int>, idxLast=<int>}, e.g. as returned by Find-XmlSection. Line numbers are 0-based. (i.e. for user output, add 1).
#    

function ConvertTo-UnixLineEndings([string] $text) {
    return $text -replace "`r`n|`r|`n", "`n"
}

# Load a text file as a string, with line endings unified to LF and any single trailing newline
# stripped.
function Import-TextFile($file) {
    $contents = (Get-Content -Raw $file)
    # IIRC the following '-replace' was originally added to work around a "Get-Content -Raw" bug,
    # it would add a trailing newline even if the file didn't have one. In pwsh 7.6 and powershell 5.1,
    # I don't see that behavior any more. So this is probably fixable (though some callers may need
    # changes to do it without breaking something).
    $contents = $contents -replace '\r?\n$', ''

    return (ConvertTo-UnixLineEndings $contents)
}

function Format-IndentLine(
    $line,
    $indentLevel)
{
    return " "*$indentLevel + $line
}

class LineArray {
    hidden [string] $nl # Newline format
    hidden [bool] $hadTrailingNewline
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

        $unixData = ConvertTo-UnixLineEndings $data
        $this.hadTrailingNewline = $unixData.EndsWith("`n")
        if ($this.hadTrailingNewline) {
            $unixData = $unixData.Substring(0, $unixData.Length - 1)
        }
        $this.lines = $unixData.Split("`n")
    }

    [int] GetLineCount() {
        if ($this.lines.Count -gt 1) { return $this.lines.Count }
        if ($this.lines.Count -le 0) { return 0 } # Impossible I think?
        if ($this.lines[0] -eq "" -and -not $this.hadTrailingNewline) { return 0 }
        return 1
    }

    [bool] IsEmpty() {
        return $this.GetLineCount() -eq 0
    }

    [string] ToString() {
        $result = [System.String]::Join($this.nl, $this.lines)
        if ($this.hadTrailingNewline) { $result += $this.nl }
        return $result
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
        if ($this.lines.Count -eq 0) {
            # Deleted the file's entire content - there's no longer a "last line" to have a trailing
            # terminator, so a fully-emptied LineArray must render back out as "", not a lone "`n".
            $this.hadTrailingNewline = $false
        }
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
        # $this.nl (e.g. "`n") is passed above only to seed the same newline style - not real data -
        # so undo any trailing-newline detection that construction spuriously picked up from it.
        $laNew.hadTrailingNewline = $false

        if ($range.idxFirst -le $range.idxLast) {
            $laNew.lines = $this.lines[$range.idxFirst..$range.idxLast]
        } else {
            $laNew.lines = @()
        }
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

. $PSScriptRoot\editJson.ps1

. $PSScriptRoot\editCode.ps1

. $PSScriptRoot\editPowershellScript.ps1

try { & { . "$PSScriptRoot/../moduleHashes.ps1"; pratWriteModuleHash 'TextFileEditor' $PSScriptRoot } } catch {}


