Describe "Write-DebugValue" {
    It "Does nothing if DebugPreference is SilentlyContinue" {
        $DebugPreference = 'SilentlyContinue'
        function Write-Debug {}
        Mock Write-Debug -Verifiable {}
        
        Write-DebugValue "foo"

        Should -Invoke Write-Debug -Times 0
    }

    It "Converts to an expression and writes that to debug output" {
        $DebugPreference = 'Continue'

        $written = @()
        $ref_written = [ref] $written

        function Write-Debug {}
        Mock Write-Debug {$ref_written.Value += $args[0]}
        
        Write-DebugValue "foo"

        $written.Count | Should -Be 1
        $written[0] | Should -Be ("'foo'" + "`n")
    }

    It "Can label with a name" {
        $DebugPreference = 'Continue'

        $written = @()
        $ref_written = [ref] $written

        function Write-Debug {}
        Mock Write-Debug {$ref_written.Value += $args[0]}
        
        Write-DebugValue "foo" -Name "myVar"

        $written.Count | Should -Be 1
        $written[0] | Should -Be ("myVar = 'foo'" + "`n")
    }

    It "Indents multi-line values" {
        $DebugPreference = 'Continue'

        $written = @()
        $ref_written = [ref] $written

        function Write-Debug {}
        Mock Write-Debug {$ref_written.Value += "DEBUG: " + $args[0]}
        
        Write-DebugValue @(1, 2) -Name "myVar"

        $written.Count | Should -Be 1
        $expected = @"        
DEBUG: myVar = @(
               `t1,
               `t2
               )
"@
        $written[0] | Should -Be ($expected + "`n")
    }

}
