# Test helper functions for writing readable test fixtures.

# Strips leading whitespace detected from the first non-empty line, then trims trailing whitespace.
# Useful in tests to write expected strings with indentation matching the surrounding code,
# without that padding becoming part of the test data.
function testText([string] $text) {
    $lines = ($text -replace "`r`n|`r", "`n") -split "`n"
    $firstNonEmpty = $lines | Where-Object { $_ -match '\S' } | Select-Object -First 1
    $columns = if ($null -ne $firstNonEmpty) { $firstNonEmpty.Length - $firstNonEmpty.TrimStart().Length } else { 0 }
    return testTextAt $columns $text
}

# Like testText, but strips an explicit number of leading columns instead of auto-detecting.
function testTextAt([int] $columns, [string] $text) {
    $lines = ($text -replace "`r`n|`r", "`n") -split "`n"
    $result = ($lines | ForEach-Object {
        if ($_.Length -ge $columns) { $_.Substring($columns) } else { $_.TrimStart() }
    }) -join "`n"
    return $result.TrimEnd()
}
