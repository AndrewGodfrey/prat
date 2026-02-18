BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe "Get-ContainingItem" {
    It "returns null if multiple results found unexpectedly" {
        $warnings = "TestDrive:\Get-ContainingItem_warnings.txt"
        &$scriptToTest "*.ps1" $PSScriptRoot 3>$warnings | Should -Be $null
        Get-Content $warnings | Should -Be "Multiple matches found - ignoring them all"
    }    

    It "Traverses up the directory tree" {
        $result = &$scriptToTest "LICENSE" $PSScriptRoot
        $result | Should -Not -Be $null
    }

    It "Stops at the root and returns null" {
        $result = &$scriptToTest "nonexistentfile.3927015c-c5bf-4e3f-b7b1-7ae6f1bc8277.txt" $PSScriptRoot
        $result | Should -Be $null
    }

    It "returns multiple results when requested" {
        $result = &$scriptToTest "Get-ContainingItem.*ps1" $PSScriptRoot -Multiple
        $result.Count | Should -Be 2
    }

    It "returns an empty array instead of null, if nothing found and -Multiple is used" {
        $result = &$scriptToTest "nonexistentfile.*.3927015c-c5bf-4e3f-b7b1-7ae6f1bc8277.txt" $PSScriptRoot -Multiple
        ($null -eq $result) | Should -BeFalse
        $result.GetType().Name | Should -Be "Object[]"
        $result.Count | Should -Be 0
    }
}
