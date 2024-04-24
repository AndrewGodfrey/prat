using module .\TextFileEditor.psd1

Describe "Get-IndentLevel" {
    It "is trivial" {
        Get-IndentLevel "  foo bar" | Should -Be 2
    }
    It "handles 0" {
        Get-IndentLevel "foo bar" | Should -Be 0
    }
    It "returns 0 for empty string" {
        Get-IndentLevel "" | Should -Be 0
    }
}

Describe "Get-SubIndent" {
    It "returns the indent of the second line" {
        $la = [LineArray]::new(" a`n  b`n   c`n d`ne`n")
        Get-SubIndent $la @{idxFirst=0; idxLast=4} | Should -Be 2
    }
    It "guesses +4, when only given 1 line" {
        $la = [LineArray]::new(" a`n  b`n   c`n d`ne`n")
        Get-SubIndent $la @{idxFirst=0; idxLast=0} | Should -Be 5
    }
}

Describe "Find-MatchingLine" {
    BeforeAll {
        $testScript = @'
$table = @{
    key1 = @(
        1, 2, 3
    )
    key2 = @{
        a=1
    }
}
'@
        $laTestScript = [LineArray]::new($testScript)
    }
    It "finds a line" {
        Find-MatchingLine $laTestScript $null "^\s*key2 = " | Should -Be 4
    }
    It "supports subranges" {
        Find-MatchingLine $laTestScript @{idxFirst=2; idxLast=7} "^\s*.* = " | Should -Be 4
    }
    It "returns -1 on no match" {
        Find-MatchingLine $laTestScript @{idxFirst=2; idxLast=7} "^\skey3 = " | Should -Be -1
    }
}

Describe "Find-CorrespondingIndent" {
    BeforeAll {
        $testScript = @'
$table = @{
    key1 = @(
        1, 2, 3
    )

    key2 = @{
        a=1
    }
}
'@
        $laTestScript = [LineArray]::new($testScript)
    }
    It "finds the matching indent" {
        Find-CorrespondingIndent $laTestScript 4 @{idxFirst=2; idxLast=8} | Should -Be 3
    }
    It "returns the first line found" {
        Find-CorrespondingIndent $laTestScript 4 @{idxFirst=1; idxLast=8} | Should -Be 1
    }
    It "returns null on no match" {
        Find-CorrespondingIndent $laTestScript 0 @{idxFirst=1; idxLast=7} | Should -Be -1
    }
    It "ignores blank lines" {
        Find-CorrespondingIndent $laTestScript 0 @{idxFirst=2; idxLast=8} | Should -Be 8
    }
}

Describe "Format-ReplaceMatchingLines" {
    BeforeAll {
        $testScript = @'
$table = @{
    key1 = @(
        1, 2, 3
    )
    key2 = @{
        a=1
    }
}
'@
    }
    It "replaces a line" {
        $laTestScript = [LineArray]::new($testScript)
        Format-ReplaceMatchingLines $laTestScript $null "key1 =" "key3 =" | Should -Be 1
        $laTestScript | Should -Be @'
$table = @{
    key3 = @(
        1, 2, 3
    )
    key2 = @{
        a=1
    }
}
'@
    }
    It "edits every matching line" {
        $laTestScript = [LineArray]::new($testScript)
        Format-ReplaceMatchingLines $laTestScript $null "key" "foo" | Should -Be 2
    }
    It "supports subranges" {
        $laTestScript = [LineArray]::new($testScript)
        Format-ReplaceMatchingLines $laTestScript @{idxFirst=2; idxLast=7} "key" "foo" | Should -Be 1
    }
    It "returns 0 on match" {
        $laTestScript = [LineArray]::new($testScript)
        Format-ReplaceMatchingLines $laTestScript $null "hamster" "foo" | Should -Be 0
    }
    It "can replace multiple patterns per line, but the return value counts lines, not replacements" {
        $laTestScript = [LineArray]::new($testScript)
        Format-ReplaceMatchingLines $laTestScript $null "," " ," | Should -Be 1
        $laTestScript | Should -Be @'
$table = @{
    key1 = @(
        1 , 2 , 3
    )
    key2 = @{
        a=1
    }
}
'@
    }
}
