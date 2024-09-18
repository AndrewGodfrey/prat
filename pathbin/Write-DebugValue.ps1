# Dumps a variable to Write-Debug, but avoids formatting work if Write-Debug output is disabled.
param($variable, [string] $name)

function Format-IndentEachLine(
    $text,
    $indentLevel,
    [switch] $SkipFirstLine=$false)
{
    if ($indentLevel -lt 0) { throw "Not implemented: Unindent" }
    if ($text -eq "") { return "" }

    $indent = " "*$indentLevel

    $firstLineIndent = ""
    if (!$SkipFirstLine) {
        $firstLineIndent += $indent
    }
    return $firstLineIndent + ($text -replace "(?<nl>`r`n|`r|`n)", ('${nl}'+$indent))
}

if ($DebugPreference -ne 'SilentlyContinue') {
    $result = ""
    $skipFirstLineIndent = $false
    $indentLevel = 7
    if ($name -ne '') {
        $result += "$($name) = "
        $skipFirstLineIndent = $true
        $indentLevel += $name.Length + 3
    }
    $expression = ConvertTo-Expression $variable

    $result += Format-IndentEachLine $expression $indentLevel -SkipFirstLine $skipFirstLineIndent
    Write-Debug "$result`n"
}

