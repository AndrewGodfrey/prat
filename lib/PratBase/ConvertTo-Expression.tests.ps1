BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    function AssertEqual($a, $b) {
        if ($a -is [array]) {
            $a.Count | Should -Be $b.Count
            for ($i = 0; $i -lt $a.Count; $i++) {
                AssertEqual $a[$i] $b[$i]
            }
            return
        }
        if ($a -is [hashtable]) {
            $a.Keys.Count | Should -Be $b.Keys.Count
            foreach ($k in $a.Keys) {
                AssertEqual $a[$k] $b[$k]
            }
            return
        }
        $a | Should -Be $b
    }

    # Asserts that the roundtrip expression has the same type
    # and value as the original.
    # For nested objects, only supports arrays and hashtables.
    function AssertRoundtrip($expression, $convertedExpression, [switch] $JustCompareTypes) {
        $newExpression = Invoke-Expression $convertedExpression

        # Assert
        $newExpression.GetType().Name | Should -Be $expression.GetType().Name

        if ($JustCompareTypes) {
            return
        }

        if ($expresssion -is [scriptblock]) {
            throw "Can't compare scriptblocks"
        }

        AssertEqual $expression $newExpression

        return
    }
}

Describe "ConvertTo-Expression" {
    It "converts value types" {
        $expressions = @(
            @($true),
            @(42),
            @("foo", "'foo'"),
            @([char] 'a', "[Char]'a'"),
            @([DateTime] "2023-01-01", "[DateTime]'2023-01-01T00:00:00.0000000'"),
            @([TimeSpan] "00:01:00", "[TimeSpan]'00:01:00'"),
            @([Version] "1.0.0", "[Version]'1.0.0'")
        )
        $e = $true

        foreach ($tuple in $expressions) {
            $e = $tuple[0]
            # Act
            $result = ConvertTo-Expression $e

            # Assert
            AssertRoundtrip $e $result -ValueType
            if ($tuple.Count -gt 1) {
                $result | Should -Be $tuple[1]
            } else {
                $result | Should -Be $e
            }
        }
    }

    It "converts a string containing newlines" {
        $e = "a`nb"

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        AssertRoundtrip $e $result -ValueType

        $result -replace "[`r`n]+", "`n" | Should -Be "@'`na`nb`n'@`n"
    }

    It "converts an array" {
        $e = @( 1, 42 )

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        $resultExpression = Invoke-Expression $result

        $resultExpression.Count | Should -Be 2
        $resultExpression[1] | Should -Be 42

        AssertRoundtrip $e $result
    }

    It "converts a hashtable" {
        $e = @{ foo = 1; bar = 42 }

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        $resultExpression = Invoke-Expression $result
        $resultExpression.Count | Should -Be 2
        $resultExpression.foo | Should -Be 1
        $resultExpression.bar | Should -Be 42

        AssertRoundtrip $e $result
    }

    It "converts an Enum" {
        enum Foo {
            Bar = 1
            Baz = 3
        }
        $e = [Foo]::Bar

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        $result | Should -Be "'Bar'"
        
        # Doesn't roundtrip - becomes a string:
        # AssertRoundtrip $e $result -ValueType
    }

    It "converts a DictonaryEntry, for some reason" {
        $table = @{ bar = 42 }

        foreach ($e in $table.GetEnumerator()) { 
            # Act
            $result = ConvertTo-Expression $e

            # Assert
            $e.GetType().Name | Should -Be "DictionaryEntry"
            $e.Name | Should -Be "bar"
            $e.Value | Should -Be 42
            
            # Doesn't roundtrip - becomes a Hashtable:
            # AssertRoundtrip $e $result 
        }
    }

    It "converts a scriptblock" {
        $e = { echo 43  }

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        AssertRoundtrip $e $result -JustCompareTypes
        $resultExpression = Invoke-Expression $result
        &$resultExpression | Should -Be "43"
        $result | Should -Be "{ echo 43  }" # It seems like [scriptblock] records the source code, whitespace included. I didn't know I could rely on that but apparently I can.
    }

    It "converts XML" {
        $e = [xml] "<foo>`n<bar>   42   </bar>  </foo>"

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        AssertRoundtrip $e $result -JustCompareTypes
        $resultExpression = Invoke-Expression $result
        $resultExpression.OuterXml | Should -Be "<foo><bar>   42   </bar></foo>"
    }

    It "converts a PSCustomObject" {
        $e = [pscustomobject] @{ foo = 1; bar = 42 }

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        $resultExpression = Invoke-Expression $result
        $resultExpression.foo | Should -Be 1
        $resultExpression.bar | Should -Be 42
        AssertRoundtrip $e $result -JustCompareTypes
    }

    It "supports TypePrefix 'Cast' (default)" {
        $e = [ordered] @{ foo = 1; bar = 42 }
        $result = ConvertTo-Expression $e
        $result -replace "[`r`n`t]+", "`n" | Should -Be "[ordered]@{`n'foo' = 1`n'bar' = 42`n}"
    }

    It "supports TypePrefix 'None'" {
        $e = [ordered] @{ foo = 1; bar = 42 }

        # Act
        $result = ConvertTo-Expression $e -TypePrefix 'None'

        # Assert
        $result -replace "[`r`n`t]+", "`n" | Should -Be "@{`n'foo' = 1`n'bar' = 42`n}"

        # AssertRoundtrip fails in this case: Gives '[Hashtable]' instead of '[ordered]', which is not equivalent.
        # AssertRoundtrip $e $result
    }

    It "supports TypePrefix 'Native'" {
        $e = "foo"
        
        # Act
        $result = ConvertTo-Expression $e -TypePrefix 'Native'
        $result | Should -Be "[String]'foo'"
        AssertRoundtrip $e $result
    }

    It "supports TypePrefix 'Strict'" {
        $e = @{}

        # Act
        $result = ConvertTo-Expression $e -TypePrefix 'Strict'
        $result2 = ConvertTo-Expression $e -TypePrefix 'Cast'

        # Assert
        # This behavior doesn't make sense to me, but I'll pin it anyway to avoid regressions.
        $result | Should -Be "[Hashtable]@{}"
        $result2 | Should -Be "@{}"

        AssertRoundtrip $e $result
        AssertRoundtrip $e $result2
    }

    It "eliminates spaces past the given 'Expand' depth" {
        $e = @(
            @{ foo = 1 },
            @{ foo = 1; bar = @{ a = 1; b = 2 } }
        )

        # Act
        $result = ConvertTo-Expression $e -Expand 1

        # Assert
        $result2 = $result -replace "[`r`n`t]+", "" # Remove newlines
        $result2 = $result2 -replace "'b'=2;'a'=1", "'a'=1;'b'=2" # Reorder hashtable if needed
        $result2 = $result2 -replace "'bar' = @{'a'=1;'b'=2}; 'foo' = 1", "'foo' = 1; 'bar' = @{'a'=1;'b'=2}" # Reorder hashtable if needed
        $result2 | Should -Be "@(@{'foo' = 1},@{'foo' = 1; 'bar' = @{'a'=1;'b'=2}})"
        AssertRoundtrip $e $result
    }

    It "only expands to the given depth, default 9" {
        $e = @(
            @{ foo = 1 },
            @{ foo = 1; bar = @{ a = 1; b = 2 } }
        )

        # Act
        $result = ConvertTo-Expression $e -Depth 2

        # Assert
        $result2 = $result -replace "[`r`n`t]+", "" # Remove newlines
        $result2 = $result2 -replace "'bar' = @{}'foo' = 1", "'foo' = 1'bar' = @{}" # Reorder hashtable if needed
        $result2 | Should -Be "@(@{'foo' = 1},@{'foo' = 1'bar' = @{}})"

        # And of course, this wouldn't round-trip - data has been lost.
        {AssertRoundtrip $e $result} | Should -Throw
    }
}

