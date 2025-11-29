using module .\TextFileEditor.psd1

Describe "Find-MatchingPowershellBlock" {
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
    It "finds a multiline block" {
        $result = Find-MatchingPowershellBlock $laTestScript $null "^\s*key2 = "
        $result.idxFirst | Should -Be 4
        $result.idxLast | Should -Be 6
    }
    It "supports subranges" {
        $result = Find-MatchingPowershellBlock $laTestScript @{idxFirst=2; idxLast=7} "^\s*.* = "
        $result.idxFirst | Should -Be 4
        $result.idxLast | Should -Be 6
    }
    It "returns null on no match" {
        $result = Find-MatchingPowershellBlock $laTestScript @{idxFirst=2; idxLast=7} "^\skey3 = "
        ($null -eq $result) | Should -BeTrue
    }
}

Describe "Test-IsSingleLinePowershellBlock" {
    It "detects a simple unfinished definition" {
        Test-IsSingleLinePowershellBlock " a = " | Should -BeFalse
    }
    It "detects unfinished arrays and hashtables" {
        Test-IsSingleLinePowershellBlock " a = @(1, " | Should -BeFalse
        Test-IsSingleLinePowershellBlock " a = @{a=1 " | Should -BeFalse
    }
    It "detects simple one-line arrays and hashtables" {
        Test-IsSingleLinePowershellBlock " a = @(1, 2)" | Should -BeTrue
        Test-IsSingleLinePowershellBlock " a = @{a=1;b=2} " | Should -BeTrue
    }
    It "detects string values" {
        Test-IsSingleLinePowershellBlock 'a = "foo"' | Should -BeTrue
        Test-IsSingleLinePowershellBlock "a = 'foo'" | Should -BeTrue
    }
    It "detects numbers" {
        Test-IsSingleLinePowershellBlock 'a = 4' | Should -BeTrue
        Test-IsSingleLinePowershellBlock 'a = .4' | Should -BeTrue
        Test-IsSingleLinePowershellBlock 'a = 1e4' | Should -BeTrue

        Test-IsSingleLinePowershellBlock 'a = e4' | Should -BeFalse
        Test-IsSingleLinePowershellBlock 'a = 1s4' | Should -BeFalse
    }
}

Describe "Add-HashTableItemInPowershellScript" {
    Context "multiline cases" {
        BeforeAll {
            $testScript = @'
$table1 = @{
    key1 = @(
        4, 5, 6
    )
    key2 = @{
        a=2
    }
}
$table2 = @{
    key1 = @(
        1, 2, 3
    )
    key2 = @{
        a=1
    }
}
'@
        }

        It "throws if the table is not found" {
            $laTestScript = [LineArray]::new($testScript)
            { Add-HashTableItemInPowershellScript $laTestScript "table3" "key1" "value" } | 
                Should -Throw "Initialization not found for table 'table3'"
        }
        It "adds a new key at the end of the table" {
            $laTestScript = [LineArray]::new($testScript)
            Add-HashTableItemInPowershellScript $laTestScript "table2" "key3" "@{`n    foo=2`n}"
            $laTestScript | Should -Be @'
$table1 = @{
    key1 = @(
        4, 5, 6
    )
    key2 = @{
        a=2
    }
}
$table2 = @{
    key1 = @(
        1, 2, 3
    )
    key2 = @{
        a=1
    }
    key3 = @{
        foo=2
    }
}
'@
        }

        It "replaces an existing key" {
            $laTestScript = [LineArray]::new($testScript)
            Add-HashTableItemInPowershellScript $laTestScript "table2" "key2" "@{`n    foo=2`n}"
            $laTestScript | Should -Be @'
$table1 = @{
    key1 = @(
        4, 5, 6
    )
    key2 = @{
        a=2
    }
}
$table2 = @{
    key1 = @(
        1, 2, 3
    )
    key2 = @{
        foo=2
    }
}
'@
        }

        It "replaces an existing key - another pattern, which currently fails" {
            $script = @'
$a = @{
    key1 = 4
}
'@
            $laTestScript = [LineArray]::new($script)
            Add-HashTableItemInPowershellScript $laTestScript "a" "key1" "4"
            $laTestScript | Should -Be $script
        }

        It "... whereas this one passes" {
            $script = @'
$a = @{
    key1 = @(4)
}
'@
            $laTestScript = [LineArray]::new($script)
            Add-HashTableItemInPowershellScript $laTestScript "a" "key1" "@(4)"
            $laTestScript | Should -Be $script
        }

        It "deletes a key entirely if given a null value" {
            $laTestScript = [LineArray]::new($testScript)
            Add-HashTableItemInPowershellScript $laTestScript "table2" "key2" $null
            $laTestScript | Should -Be @'
$table1 = @{
    key1 = @(
        4, 5, 6
    )
    key2 = @{
        a=2
    }
}
$table2 = @{
    key1 = @(
        1, 2, 3
    )
}
'@
        }
    }
}



Describe "Test-HashTableItemInPowershellScript" {
    BeforeAll {
        $testScript = @'
$table1 = @{
    key1 = @(
        4, 5, 6
    )
    key2 = @{
        a=2
    }
}
'@
        $laTestScript = [LineArray]::new($testScript)
    }

    It "throws if the table is not found" {
        $laTestScript = [LineArray]::new($testScript)
        { Test-HashTableItemInPowershellScript $laTestScript "table3" "key" } | 
            Should -Throw "Initialization not found for table 'table3'"
    }

    It "detects keys but doesn't return their values" {
        Test-HashTableItemInPowershellScript $laTestScript "table1" "key3" | Should -BeFalse
        Test-HashTableItemInPowershellScript $laTestScript "table1" "key2" | Should -BeTrue
    }
}


Describe "Edit-HashOfArraysItemInPowershellScript" {
    BeforeAll {
        $testScript = @'
$table1 = @{
    key1 = @(
        "one"
    )
}
$table2 = @{
    key1 = @(
        "one"
        "two"
    )
    key2 = @(
        "ten"
    )
}
'@
    }

    Context "exception cases" {
        It "throws if the table is not found" {
            $laTestScript = [LineArray]::new($testScript)
            { Edit-HashOfArraysItemInPowershellScript $true $laTestScript "table3" "key" "value" } | 
                Should -Throw "Initialization not found for table 'table3'"
        }
    }

    Context "add cases" {
        It "adds a new item at the end of the array" {
            $laTestScript = [LineArray]::new($testScript)
            Edit-HashOfArraysItemInPowershellScript $true $laTestScript "table2" "key1" "three"
            $laTestScript | Should -Be @'
$table1 = @{
    key1 = @(
        "one"
    )
}
$table2 = @{
    key1 = @(
        "one"
        "two"
        "three"
    )
    key2 = @(
        "ten"
    )
}
'@
        }

        It "creates a new key if needed" {
            $laTestScript = [LineArray]::new($testScript)
            Edit-HashOfArraysItemInPowershellScript $true $laTestScript "table2" "key3" "three"
            $laTestScript | Should -Be @'
$table1 = @{
    key1 = @(
        "one"
    )
}
$table2 = @{
    key1 = @(
        "one"
        "two"
    )
    key2 = @(
        "ten"
    )
    key3 = @(
        "three"
    )
}
'@
        }

        It "makes no change if the item is already present" {
            $laTestScript = [LineArray]::new($testScript)
            Edit-HashOfArraysItemInPowershellScript $true $laTestScript "table2" "key1" "one"
            $laTestScript | Should -Be $testScript
        }
    }

    Context "remove cases" {
        It "removes the specified item" {
            $laTestScript = [LineArray]::new($testScript)
            Edit-HashOfArraysItemInPowershellScript $false $laTestScript "table2" "key1" "one"
            $laTestScript | Should -Be @'
$table1 = @{
    key1 = @(
        "one"
    )
}
$table2 = @{
    key1 = @(
        "two"
    )
    key2 = @(
        "ten"
    )
}
'@
        }

        It "leaves empty arrays alone - does NOT remove the key" {
            $laTestScript = [LineArray]::new($testScript)
            Edit-HashOfArraysItemInPowershellScript $false $laTestScript "table2" "key2" "ten"
            $laTestScript | Should -Be @'
$table1 = @{
    key1 = @(
        "one"
    )
}
$table2 = @{
    key1 = @(
        "one"
        "two"
    )
    key2 = @(
    )
}
'@
        }

        It "makes no change if the item is not present" {
            $laTestScript = [LineArray]::new($testScript)
            Edit-HashOfArraysItemInPowershellScript $false $laTestScript "table2" "key1" "three"
            $laTestScript | Should -Be $testScript
        }
    }
}

