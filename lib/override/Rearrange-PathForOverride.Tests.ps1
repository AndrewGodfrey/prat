BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe "Rearrange-PathForOverride" {
    It "Leaves other paths alone" {
        &$scriptToTest "C:\foo;C:\bar;c:\pratfalls;C:\baz baz" | Should -Be "C:\foo;C:\bar;c:\pratfalls;C:\baz baz"
    }
    It "Moves Prat paths to the end" {
        &$scriptToTest "C:\foo;C:\bar;c:\prat;C:\baz" | Should -Be "C:\foo;C:\bar;C:\baz;c:\prat"
    }
}
