BeforeAll {
    $pratImplementation = Resolve-Path "$PSScriptRoot\..\Get-CodebaseLayers.ps1"
    $overriddenImplementation = (Get-Command Get-CodebaseLayers).Source

    function test_returnsExpectedFormat($ACT) {
        $result = @( &$ACT )

        foreach ($cb in $result) {
            $cb.GetType().Name | Should -Be "Hashtable"
            $cb.Name | Should -Not -BeNullOrEmpty
            $cb.Path | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Get-CodebaseLayers" {
    It "Returns the expected format" {
        test_returnsExpectedFormat $pratImplementation
    }
    It "If overridden - it meets the same criteria as the base implementation" {
        test_returnsExpectedFormat $overriddenImplementation
    }
}
