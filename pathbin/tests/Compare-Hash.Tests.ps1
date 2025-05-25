Describe "Compare-Hash" {
    It "Compares" {
        $hash = '9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08'
        $wrongHash = '9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A09'
        Compare-Hash $PSScriptRoot\testHash.txt $hash | Should -Be $true
        Compare-Hash $PSScriptRoot\testHash.txt $wrongHash | Should -Be $false
    }
}
