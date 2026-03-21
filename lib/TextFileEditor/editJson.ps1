# Functions for manipulating parts of a JSON file.
# By using lineArray, we can preserve the file's line-ending format.
#
# Requires well-formatted (pretty-printed) JSON. Each key-value pair and each array element
# must start on its own line.
#
# Path syntax (same conventions as Find-XmlSection):
#   "key"              - navigate into an object property
#   "[@key='value']"   - find an array element by a direct property value


# Parses a path step: either a plain key or "[@key='value']"
function getJsonMatchTerms($step) {
    if ($step -match "^\[@(.+)='(.*)'\]$") {
        return @{ attrName = $Matches[1]; attrValue = $Matches[2] }
    }
    return @{ key = $step }
}

# Tokenizes JSON content into a flat array of tokens.
# Each token: @{type; value; line}  (line is 0-based)
# Types: OpenObject, CloseObject, OpenArray, CloseArray, Comma, Colon, String, Value
function getJsonTokens([string] $content) {
    $tokens = [System.Collections.Generic.List[hashtable]]::new()
    $i = 0
    $n = $content.Length
    $line = 0

    while ($i -lt $n) {
        $c = $content[$i]
        if    ($c -eq "`n") { $line++; $i++; continue }
        elseif ($c -eq "`r" -or $c -eq ' ' -or $c -eq "`t") { $i++; continue }
        elseif ($c -eq '{')  { $tokens.Add(@{type='OpenObject';  line=$line}); $i++; continue }
        elseif ($c -eq '}')  { $tokens.Add(@{type='CloseObject'; line=$line}); $i++; continue }
        elseif ($c -eq '[')  { $tokens.Add(@{type='OpenArray';   line=$line}); $i++; continue }
        elseif ($c -eq ']')  { $tokens.Add(@{type='CloseArray';  line=$line}); $i++; continue }
        elseif ($c -eq ',')  { $tokens.Add(@{type='Comma';       line=$line}); $i++; continue }
        elseif ($c -eq ':')  { $tokens.Add(@{type='Colon';       line=$line}); $i++; continue }
        elseif ($c -eq '"') {
            $i++  # skip opening quote
            $sb = [System.Text.StringBuilder]::new()
            while ($i -lt $n -and $content[$i] -ne '"') {
                if ($content[$i] -eq '\' -and ($i + 1) -lt $n) {
                    $i++
                    switch ($content[$i]) {
                        '"'  { $sb.Append('"')  | Out-Null }
                        '\'  { $sb.Append('\')  | Out-Null }
                        'n'  { $sb.Append("`n") | Out-Null }
                        'r'  { $sb.Append("`r") | Out-Null }
                        't'  { $sb.Append("`t") | Out-Null }
                        'u'  {
                            if (($i + 4) -lt $n) {
                                $hex = $content.Substring($i + 1, 4)
                                $sb.Append([char][System.Convert]::ToInt32($hex, 16)) | Out-Null
                                $i += 4
                            }
                        }
                        default { $sb.Append($content[$i]) | Out-Null }
                    }
                } else {
                    $sb.Append($content[$i]) | Out-Null
                }
                $i++
            }
            $i++  # skip closing quote
            $tokens.Add(@{type='String'; value=$sb.ToString(); line=$line})
            continue
        }
        else {
            # Number, bool, null
            $start = $i
            while ($i -lt $n -and @('{','}','[',']',',','"',':',"`r","`n",' ',"`t") -notcontains $content[$i]) { $i++ }
            $tokens.Add(@{type='Value'; value=$content.Substring($start, $i - $start); line=$line})
            continue
        }
    }
    return $tokens
}

# Advance past one complete JSON value starting at $ti. Returns new $ti.
function skipJsonValue($tokens, [int] $ti) {
    $t = $tokens[$ti].type
    if ($t -eq 'OpenObject' -or $t -eq 'OpenArray') {
        $depth = 1; $ti++
        while ($ti -lt $tokens.Count -and $depth -gt 0) {
            $t2 = $tokens[$ti].type
            if ($t2 -eq 'OpenObject' -or $t2 -eq 'OpenArray')   { $depth++ }
            elseif ($t2 -eq 'CloseObject' -or $t2 -eq 'CloseArray') { $depth-- }
            $ti++
        }
        return $ti
    }
    return $ti + 1
}

# Returns the last line (0-based) of the value starting at $ti.
function getJsonValueEndLine($tokens, [int] $ti) {
    $t = $tokens[$ti].type
    if ($t -eq 'OpenObject' -or $t -eq 'OpenArray') {
        $depth = 1; $ti++
        while ($ti -lt $tokens.Count -and $depth -gt 0) {
            $t2 = $tokens[$ti].type
            if ($t2 -eq 'OpenObject' -or $t2 -eq 'OpenArray')   { $depth++ }
            elseif ($t2 -eq 'CloseObject' -or $t2 -eq 'CloseArray') { $depth-- }
            if ($depth -gt 0) { $ti++ }
        }
        return $tokens[$ti].line
    }
    return $tokens[$ti].line
}

# Returns true if the object starting at $startTi has a direct property $propName with string value $propValue.
function testJsonElementHasProperty($tokens, [int] $startTi, [string] $propName, [string] $propValue) {
    if ($tokens[$startTi].type -ne 'OpenObject') { return $false }
    $ti = $startTi + 1
    $depth = 0
    while ($ti -lt $tokens.Count) {
        $tok = $tokens[$ti]
        if ($tok.type -eq 'OpenObject' -or $tok.type -eq 'OpenArray') { $depth++ }
        elseif ($tok.type -eq 'CloseObject' -or $tok.type -eq 'CloseArray') {
            if ($depth -eq 0) { break }
            $depth--
        } elseif ($tok.type -eq 'String' -and $depth -eq 0 -and $tok.value -eq $propName) {
            if (($ti + 2) -lt $tokens.Count -and
                $tokens[$ti + 1].type -eq 'Colon' -and
                $tokens[$ti + 2].type -eq 'String' -and
                $tokens[$ti + 2].value -eq $propValue) {
                return $true
            }
        }
        $ti++
    }
    return $false
}

# Searches JSON content for a section specified by a path array.
# Returns @{idxFirst; idxLast} (0-based line numbers, both inclusive), or $null if not found.
# $filename is used only in error messages.
#
# Path steps:
#   "key"            - navigate into an object property (idxFirst = key's line)
#   "[@key='value']" - find array element with matching direct property (idxFirst = element's first line)
function Find-JsonSection($jsonContent, $pathArray, $filename) {
    $tokens = @(getJsonTokens $jsonContent)
    if ($tokens.Count -eq 0) { return $null }

    $ti = 0        # current token index
    $idxFirst = -1

    foreach ($step in $pathArray) {
        $terms = getJsonMatchTerms $step

        if ($null -ne $terms.key) {
            # Key navigation: scan inside current object for this key
            if ($tokens[$ti].type -ne 'OpenObject') {
                throw "Expected object at step '$step' in '$filename'"
            }
            $ti++  # enter the object

            $found = $false
            $depth = 0
            while ($ti -lt $tokens.Count) {
                $tok = $tokens[$ti]
                if ($tok.type -eq 'OpenObject' -or $tok.type -eq 'OpenArray') { $depth++ }
                elseif ($tok.type -eq 'CloseObject' -or $tok.type -eq 'CloseArray') {
                    if ($depth -eq 0) { break }
                    $depth--
                } elseif ($tok.type -eq 'String' -and $depth -eq 0 -and $tok.value -eq $terms.key) {
                    if (($ti + 1) -lt $tokens.Count -and $tokens[$ti + 1].type -eq 'Colon') {
                        $idxFirst = $tok.line
                        $ti += 2  # skip key and colon; now at value's first token
                        $found = $true
                        break
                    }
                }
                $ti++
            }
            if (-not $found) { return $null }

        } else {
            # Array element navigation: [@key='value']
            if ($tokens[$ti].type -ne 'OpenArray') {
                throw "Expected array at step '$step' in '$filename'"
            }
            $ti++  # enter the array

            $found = $false
            while ($ti -lt $tokens.Count) {
                if ($tokens[$ti].type -eq 'CloseArray') { break }
                if ($tokens[$ti].type -eq 'Comma') { $ti++; continue }

                if (testJsonElementHasProperty $tokens $ti $terms.attrName $terms.attrValue) {
                    $idxFirst = $tokens[$ti].line
                    $found = $true
                    break
                }
                $ti = skipJsonValue $tokens $ti
            }
            if (-not $found) { return $null }
        }
    }

    $idxLast = getJsonValueEndLine $tokens $ti
    return @{ idxFirst = $idxFirst; idxLast = $idxLast }
}

# Replaces or adds a JSON section specified by $pathArray with $newSection.
# Returns the updated JSON content.
# $filename is used only in error messages.
function Update-JsonSection($jsonContent, $pathArray, $newSection, $filename) {
    $range = Find-JsonSection $jsonContent $pathArray $filename
    if ($null -ne $range) {
        # Preserve trailing comma: if the original's last line ended with ',', the replacement must too.
        $origLastLine = ((ConvertTo-UnixLineEndings $jsonContent) -split "`n")[$range.idxLast]
        if ($origLastLine.TrimEnd().EndsWith(',')) {
            $newLines = (ConvertTo-UnixLineEndings $newSection) -split "`n"
            if (-not $newLines[-1].TrimEnd().EndsWith(',')) {
                $newLines[-1] = $newLines[-1].TrimEnd() + ','
                $newSection = $newLines -join "`n"
            }
        }
        return Format-ReplaceLines $jsonContent $range $newSection
    }

    # Not found: insert into parent
    if ($pathArray.Length -lt 2) {
        throw "Can't find '$($pathArray[0])' section in '$filename'"
    }

    $parentPath = $pathArray[0..($pathArray.Length - 2)]
    $parentRange = Find-JsonSection $jsonContent $parentPath $filename
    if ($null -eq $parentRange) {
        throw "Can't find '$($parentPath[-1])' section in '$filename'"
    }

    $lines = (ConvertTo-UnixLineEndings $jsonContent) -split "`n"

    # Single-line container (e.g. "list": [] or "defaults": {}): expand it to multi-line.
    if ($parentRange.idxFirst -eq $parentRange.idxLast) {
        $keyLine = $lines[$parentRange.idxFirst]
        $indent  = [regex]::Match($keyLine, '^\s*').Value
        $trailingComma = if ($keyLine.TrimEnd().EndsWith(',')) { ',' } else { '' }
        # Find the opening [ or { delimiter in the value position
        if ($keyLine -match '^(.*?)([\[\{])') {
            $keyPart   = $Matches[1]
            $openDelim = $Matches[2]
            $closeDelim = if ($openDelim -eq '[') { ']' } else { '}' }
            $expanded = "$keyPart$openDelim`n$newSection`n$indent$closeDelim$trailingComma"
            return Format-ReplaceLines $jsonContent @{idxFirst=$parentRange.idxFirst; idxLast=$parentRange.idxLast} $expanded
        }
    }

    # Multi-line container: add comma to the last entry before the closing delimiter if needed.
    $closingLine = $parentRange.idxLast
    $prevLine = $closingLine - 1
    while ($prevLine -gt $parentRange.idxFirst -and [string]::IsNullOrWhiteSpace($lines[$prevLine])) {
        $prevLine--
    }
    $prevContent = $lines[$prevLine].TrimEnd()
    $needsComma = $prevContent -ne '[' -and $prevContent -ne '{' -and -not $prevContent.EndsWith(',')
    if ($needsComma) {
        $jsonContent = Format-ReplaceLines $jsonContent @{idxFirst=$prevLine; idxLast=$prevLine} ($lines[$prevLine] + ',')
    }

    return Add-Lines $jsonContent $parentRange.idxLast $newSection
}
