# Functions for manipulating parts of an XML file.
# By using lineArray, we can preserve the file's line-ending format. e.g. Slick-C files use Unix line-endings.


# Weird little function. Check that on the given line, all we see before the given position, is whitespace and an opening '<'
function expectedXmlLineStart([string] $xmlContent, $line, $pos) {
    # $xmlContent is a single string; convert to lines
    $lines = $xmlContent -split '\r\n|\r|\n'

    $line = $lines[$line-1]
    if ($pos -le 1) { return $true }

    $pos--  # Switch from 1-based to 0-based
    $pos--  # Go back a character
    if ($line[$pos] -ne '<') { return $false }

    while ($pos -gt 0) {
        $pos--
        if (-not (" `t".Contains($line[$pos]))) { return $false }
    }
    return $true
}

# Parses a match string, either an exact string match, or a limited matching syntax "<element>[@<attribute>='<value>']"
function getMatchTerms($matchString) {
    if (-not ($matchString -match "^([^\[]+)(\[@(.+)='(.*)'\])?$")) { throw "Unrecognized match string: '$matchString'" }
    return @{
        elementName = $matches[1]
        attrName = $matches[3]
        attrValue = $matches[4]
    }
}

# Searches the given XML content for an XML section with the given name.
# If not found, returns $null.
# $filename is used ONLY for error messages.
#
# If found, verifies:
# 1. There is only one such section.
# 2. The start of the section is on its own line - no other data besides whitespace.
# 3. The end of the section is on its own line.
#
# If any of these conditions are not met, then it fails.
# Otherwise, returns a hashtable giving the start and end line numbers. (0-based).
#
# $pathArray is not an XPath - not supported. Instead it's an array of strings.
#   Each such string is either an exact string match, or a limited matching syntax "<element>[@<attribute>='<value>']"
function Find-XmlSection($xmlContent, $pathArray, $filename) {
    # First use Select-Xml to check there's just one match.
    $xpath = "//" + [System.String]::Join("/", $pathArray)
    $selectResult = @() + (Select-Xml -Content $xmlContent -XPath $xpath)
    if ($selectResult.Length -eq 0) {
        return $null
    }
    if ($selectResult.Length -ne 1) {
        throw "Too many matches for '$xpath' in '$filename'"
    }

    # But I don't see a way to get line numbers out of Select-Xml. So now, use XmlReader to find line numbers
    $stringReader = $null
    $xmlReader = $null
    try {
        $stringReader = [System.IO.StringReader]::new($xmlContent)
        $xmlReader = [system.Xml.XmlReader]::Create($stringReader)
        foreach ($matchString in $pathArray) {
            $terms = getMatchTerms $matchString

            if (-not $xmlReader.ReadToDescendant($terms.elementName)) { throw "Internal error ('$matchString')" }
            if ($null -ne $terms.attrName) {
                while ($xmlReader.GetAttribute($terms.attrName) -ne $terms.attrValue) {
                    if (-not $xmlReader.ReadToNextSibling($terms.elementName)) { throw "Internal error ('$matchString')" }
                }
            }
        }
        $result = @{}
        $result.idxFirst = $xmlReader.LineNumber - 1

        if (-not (expectedXmlLineStart $xmlContent $xmlReader.LineNumber $xmlReader.LinePosition)) {
            throw "Error: Start node isn't on its own line ($filename : $($result.idxFirst + 1))"
        }

        $xmlReader.Skip();
        if ($xmlReader.NodeType -ne "Whitespace") {
            throw "Internal error ('" +$xmlReader.NodeType+"')"
        }
        $result.idxLast = $xmlReader.LineNumber - 1

        $xmlReader.Skip();
        if ($xmlReader.LineNumber -eq ($result.idxLast + 1)) {
            throw "Error: End node isn't on its own line ($filename : $($result.idxLast + 1))"
        }
    } finally {
        if ($null -ne $xmlReader) { $xmlReader.Dispose() }
        if ($null -ne $stringReader) { $stringReader.Dispose() }
    }

    return $result
}



# Replaces or adds the given new XML section to an in-memory XML document.
# Returns the new XML document
# $filename is used ONLY for error messages.
function Update-XmlSection($xmlContent, $pathArray, $newSection, $filename) {
    if ($pathArray.Length -lt 2) { throw "Internal error: pathArray too short - need a parent for the 'create' case" }

    # TODO: Verify that $newSection has an equivalent replacement section. Otherwise, this operation won't be idempotent,
    #       we rely on the existing section to know where to put the replacement.

    $range = Find-XmlSection $xmlContent $pathArray $filename
    if ($null -ne $range) {
        # Replace
        return Format-ReplaceLines $xmlContent $range $newSection
    } else {
        # Create
        $parentIndex = $pathArray.Length-2
        $parentSectionRange = Find-XmlSection $xmlContent $pathArray[0..$parentIndex] $filename
        if ($null -eq $parentSectionRange) {
            throw "Can't find $($pathArray[$parentIndex]) section in $filename"
        }
        $targetLineNumber = $parentSectionRange.idxLast
        
        return Add-Lines $xmlContent $targetLineNumber $newSection
    }
}

