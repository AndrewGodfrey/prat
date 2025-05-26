BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe "Get-ContainingItem" {
    It "returns null if multiple results found unexpectedly" {
        $warnings = "TestDrive:\Get-ContainingItem_warnings.txt"
        &$scriptToTest "*.ps1" $PSScriptRoot 3>$warnings | Should -Be $null
        Get-Content $warnings | Should -Be "Multiple matches found - ignoring them all"
    }    
}
