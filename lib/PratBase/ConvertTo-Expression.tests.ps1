BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    function AssertRoundtrip($expression, $convertedExpression, [switch] $ValueType = $false) {
        $newExpression = Invoke-Expression $convertedExpression

        # Assert
        $newExpression.GetType().Name | Should -Be $expression.GetType().Name
        if ($ValueType) {
            $expression -eq $newExpression | Should -BeTrue
        }

        # Optionally return the expression, in case caller wants to do more validation
        return $newExpression
    }
}

Describe "ConvertTo-Expression" {
    It "converts a basic integer" {
        $e = 42

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        AssertRoundtrip $e $result -ValueType
        $result | Should -Be "42"
    }

    It "converts a basic string" {
        $e = "foo"

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        AssertRoundtrip $e $result -ValueType
    }

    It "converts a hashtable" {
        $e = @{ foo = 1; bar = 42 }

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        $resultExpression = AssertRoundtrip $e $result

        $resultExpression.Count | Should -Be 2
        $resultExpression.foo | Should -Be 1
        $resultExpression.bar | Should -Be 42
    }

    # Can't run this, because it hangs
    It "converts a scriptblock" {
        $e = { echo 43  }

        # Act
        $result = ConvertTo-Expression $e

        # Assert
        $resultExpression = AssertRoundtrip $e $result
        &$resultExpression | Should -Be "43"
        $result | Should -Be "{ echo 43  }" # It seems like [scriptblock] records the source code, whitespace included. I didn't know I could rely on that but apparently I can.
    }
}

