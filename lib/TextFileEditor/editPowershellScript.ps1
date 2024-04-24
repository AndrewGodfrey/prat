# Functions for replacing part of a Powershell script, held in a LineArray.
#
# These are NOT very user-friendly, because you have to carefully restrict your relevant PowerShell code to conform to what this
# code supports.


# Returns true if we don't expect the following line to be a continuation of what the current line started.
# Very simplistic - this is nothing close to a complete Powershell line parser.
function Test-IsSingleLinePowershellBlock([string] $line)
{
    if ($line -match "^\s*\w*\s*=\s*@\([^\)]*\)\s*(#.*)?$") { return $true; }   # Example:  a = @(1, 2)
    if ($line -match "^\s*\w*\s*=\s*@\{[^\}]*\}\s*(#.*)?$") { return $true; }   # Example:  a = @{a=1;b=2}  #test
    if ($line -match "^\s*\w*\s*=\s*""[^\""]*\""\s*(#.*)?$") { return $true; }  # Example:  a = "foo"

    # NYI: Here are some examples that are NOT supported currently, and I'm just avoiding them in any single-line code that's targeted by this script.
    #    a = @(1, 2);
    #    a = @("this(that)")
    #    a = @{ b = @{ c=1 } }
    
    return $false
}

# Search the given range (or the entire $lineArray) for the block starting pattern, and finds the matching end line 
# Returns a range.
function Find-MatchingPowershellBlock(
    $lineArray,
    $range,
    $pattern)
{
    if ($range -eq $null) { $range = @{ idxFirst = 0; idxLast = $lineArray.lines.Count - 1} }

    [int] $idxFirst = Find-MatchingLine $lineArray $range $pattern
    if ($idxFirst -eq -1) { return $null; }

    $line = $lineArray.lines[$idxFirst]
    if (Test-IsSingleLinePowershellBlock $line) { return @{idxFirst = $idxFirst; idxLast = $idxFirst} }

    $targetIndentLevel = Get-IndentLevel $line
    # NYI: Here-strings, which have to break indentation. For now, we end on the first line matching the starting indentation.

    [int] $idxLast = Find-CorrespondingIndent $lineArray $targetIndentLevel @{idxFirst = $idxFirst+1; idxLast=$range.idxLast}
    if ($idxLast -eq -1) { return $null; }

    return @{idxFirst = $idxFirst; idxLast = $idxLast}
}

# Given a Powershell script in $lineArray, having an initialization for $tableName formatted as expected (w.r.t. line breaks and indentation), 
# add, or update, an entry in the hash table. Can also remove an item (if $newValue is $null).
#
# NYI: Here are some cases that aren't supported:
#    - when there are multiple keys on the same line
#    - quotes around the key, e.g. 
#      "foo" = 1
#      These CAN be supported (I need it for keys that are machine names) but you have to specify the quotes as part of the 'key name'. This code would treat it as a different key from the unquoted version.
#    - other brace styles. This function relies on the closing brace to be at the same indent level as the starting line. e.g. this isn't supported:
#      foo = @(
#          1,
#          2)
function Add-HashTableItemInPowershellScript(
    $lineArray,
    [string]$tableName,
    [string]$newKey,
    $newValue) 
{
    # TODO: Add a required comment to this type of hashtable declaration, to make the reader aware of the limited syntax
    $tablePattern = '^\s*\$' + $tableName + ' *= *@{\s*$'
    $tableRange = Find-MatchingPowershellBlock $lineArray $null $tablePattern
    $subIndent = Get-SubIndent $lineArray $tableRange

    if ($tableRange -eq $null) {
        throw "Initialization not found for table '$tableName'"
    }

    # Create the new lines to insert
    if ($newValue -ne $null) {
        $laNewCode = [LineArray]::new("$newKey = $newValue")
        $laNewCode.IndentEachLine($subIndent)
    } else {
        $laNewCode = [LineArray]::new("")
    }

    $itemPattern = '^\s*' + $newKey + ' *= '
    $itemRange = Find-MatchingPowershellBlock $lineArray $tableRange $itemPattern
    if ($itemRange -eq $null) {
        # Insert case - need to find where to insert it
        # TODO: Keep items sorted. For now, insert at the end.
        $lineArray.InsertLines($tableRange.idxLast, $laNewCode)
    } else {
        $lineArray.ReplaceLines($itemRange, $laNewCode)
    }
}

# Given a Powershell script in $lineArray, having an initialization for $tableName formatted as expected (w.r.t. line breaks and indentation), 
# query the given key and return whether it is present.
#
# NYI: There are some unsupported cases; see Add-HashTableItemInPowershellScript for the list.
function Test-HashTableItemInPowershellScript(
    $lineArray,
    [string]$tableName,
    [string]$key) 
{
    # TODO: Add a required comment to this type of hashtable declaration, to make the reader aware of the limited syntax
    $tablePattern = '^\s*\$' + $tableName + ' *= *@{\s*$'
    $tableRange = Find-MatchingPowershellBlock $lineArray $null $tablePattern
    $subIndent = Get-SubIndent $lineArray $tableRange

    if ($tableRange -eq $null) {
        throw "Initialization not found for table '$tableName'"
    }

    $itemPattern = '^\s*' + $key + ' *= '
    $itemRange = Find-MatchingPowershellBlock $lineArray $tableRange $itemPattern
    return $itemRange -ne $null
}


# Given:
#  - a Powershell script in $lineArray, having an initialization for $tableName formatted as expected (w.r.t. line breaks and indentation)
#  - $tableName is a hash of arrays (of strings) 
# Add/nop (if $add is $true), or remove/nop (if $add is $false), an array entry. 
#
# NYI: Here are some cases that aren't supported:
#    - when there are multiple array items on the same line
#    - when there are multiple hash keys on the same line
#    - quotes around the key, e.g. 
#      "foo" = "a"
#      These CAN be supported (I need it for keys that are machine names) but you have to specify the quotes as part of the 'key name'. This code would treat it as a different key from the unquoted version.
#    - other brace styles. This function relies on the closing brace to be at the same indent level as the starting line. e.g. this isn't supported:
#      foo = @(
#          "a"
#          "b")
#    - String characters that need to be escaped, like " or $. We're just mashing double-quotes around them. If this is needed, consider using single quotes instead of double quotes.
#      A possible tool for addressing this is EscapeSingleQuotedStringContent, in System.Management.Automation.Language (requires Add-Type -AssemblyName System.Management.Automation).
#    - Commas aren't supported between array items. That is, they're MOSTLY ignored, but one case that would break is:
#          foo = @(
#              "a",
#              "b"
#          )
#      ... if you delete "b", because we'll leave the trailing comma on "a" and Powershell will complain. (Commas are optional in between items - but disallowed after the last item).
function Edit-HashOfArraysItemInPowershellScript (
    [bool] $add,
    $lineArray,
    [string]$tableName,
    [string]$key,
    [string]$valueToAddOrRemove) 
{
    # TODO: Add a required comment to this type of hashtable declaration, to make the reader aware of the limited syntax
    $tablePattern = '^\s*\$' + $tableName + ' *= *@{\s*$'
    $tableRange = Find-MatchingPowershellBlock $lineArray $null $tablePattern

    if ($tableRange -eq $null) {
        throw "Initialization not found for table '$tableName'"
    }

    $hashItemPattern = '^\s*' + $key + ' *= *@\(\s*$'
    $hashItemRange = Find-MatchingPowershellBlock $lineArray $tableRange $hashItemPattern
    if ($hashItemRange -eq $null) {
        if (-not $add) {
            # NOP: Hash item already removed
            return
        }

        # 'Insert key' case
        # TODO: Keep items sorted. For now, insert at the end.
        $idxInsertAt = $tableRange.idxLast

        $subIndent = Get-SubIndent $lineArray $tableRange
        $laNewCode = [LineArray]::new("$key = @(`n    ""$valueToAddOrRemove""`n)")
        $laNewCode.IndentEachLine($subIndent)

        $lineArray.InsertLines($idxInsertAt, $laNewCode)
        return
    }

    # The array is present, and needs to be added to / removed from
    $arrayItemPattern = '^\s*"' + $valueToAddOrRemove + '" *,?$'
    $arrayItemLineNumber = Find-MatchingLine $lineArray $hashItemRange $arrayItemPattern
    if ($arrayItemLineNumber -eq -1) {
        if (-not $add) {
            # NOP: Array item already removed
            return
        }

        # 'Insert array item' case
        # TODO: Keep items sorted. For now, insert at the end.
        $idxInsertAt = $hashItemRange.idxLast

        $subIndent = Get-SubIndent $lineArray $hashItemRange
        $laNewCode = [LineArray]::new("""$valueToAddOrRemove""")
        $laNewCode.IndentEachLine($subIndent)

        $lineArray.InsertLines($idxInsertAt, $laNewCode)
        return
    }

    if ($add) {
        # NOP: Array item already added
        return
    }

    $lineArray.RemoveLines(@{idxFirst=$arrayItemLineNumber; idxLast=$arrayItemLineNumber})
}


