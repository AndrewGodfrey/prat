BeforeAll {
    $script = "$PSScriptRoot/Invoke-WithOutputFilter.ps1"
}

Describe "Invoke-WithOutputFilter" {
    It "suppresses all output when ProcessLine always returns null" {
        $result = & $script `
            -Command      { "a"; "b"; "c" } `
            -ProcessLine  { param($line, $state) $null } `
            -RenderResult { param($state) }

        $result | Should -HaveCount 0
    }

    It "emits live output for lines where ProcessLine returns a string" {
        $result = & $script `
            -Command      { "line1"; "line2" } `
            -ProcessLine  { param($line, $state) "[$line]" } `
            -RenderResult { param($state) }

        $result | Should -HaveCount 2
        $result[0] | Should -Be "[line1]"
        $result[1] | Should -Be "[line2]"
    }

    It "RenderResult output appears after live output" {
        $result = & $script `
            -Command      { "a" } `
            -ProcessLine  { param($line, $state) $line } `
            -RenderResult { param($state) "DONE" }

        $result | Should -HaveCount 2
        $result[0] | Should -Be "a"
        $result[1] | Should -Be "DONE"
    }

    It "delivers Write-Error output to ProcessLine as ErrorRecord" {
        $result = & $script `
            -Command      { Write-Error "oops" } `
            -ProcessLine  { param($line, $state) $line.GetType().Name } `
            -RenderResult { param($state) }

        $result | Should -Be "ErrorRecord"
    }

    It "delivers Write-Output to ProcessLine as String" {
        $result = & $script `
            -Command      { Write-Output "hello" } `
            -ProcessLine  { param($line, $state) $line.GetType().Name } `
            -RenderResult { param($state) }

        $result | Should -Be "String"
    }

    It "ProcessLine accumulates state that RenderResult reads" {
        $result = & $script `
            -Command      { "x"; "y"; "z" } `
            -ProcessLine  { param($line, $state) $state.lineCount = ($state.lineCount ?? 0) + 1; $null } `
            -RenderResult { param($state) "lineCount=$($state.lineCount)" }

        $result | Should -Be "lineCount=3"
    }

    It "passes a thrown exception through ProcessLine as ErrorRecord" {
        $initialState = @{ exceptionSeen = $false }
        try {
            & $script `
                -Command      { throw "crash" } `
                -ProcessLine  { param($line, $state)
                    if ($line -is [System.Management.Automation.ErrorRecord]) { $state.exceptionSeen = $true }
                    $null } `
                -RenderResult { param($state) } `
                -InitialState $initialState
        } catch { }

        $initialState.exceptionSeen | Should -Be $true
    }

    It "RenderResult runs even when the command throws" {
        $initialState = @{}
        try {
            & $script `
                -Command      { throw "boom" } `
                -ProcessLine  { param($line, $state) $null } `
                -RenderResult { param($state) $state.rendered = $true } `
                -InitialState $initialState
        } catch { }

        $initialState.rendered | Should -Be $true
    }

    It "re-throws the command exception after RenderResult completes" {
        { & $script `
            -Command      { throw "kaboom" } `
            -ProcessLine  { param($line, $state) $null } `
            -RenderResult { param($state) }
        } | Should -Throw "kaboom"
    }

    Context "-StripAnsi" {
        It "strips ANSI codes from strings before passing to ProcessLine" {
            $result = & $script `
                -Command      { "`e[32mhello`e[0m" } `
                -ProcessLine  { param($line, $state) "$($line.GetType().Name):$line" } `
                -RenderResult { param($state) } `
                -StripAnsi

            $result | Should -Be "String:hello"
        }

        It "passes ErrorRecord through unchanged so ProcessLine can still detect stderr" {
            $result = & $script `
                -Command      { Write-Error "oops" } `
                -ProcessLine  { param($line, $state) $line.GetType().Name } `
                -RenderResult { param($state) } `
                -StripAnsi

            $result | Should -Be "ErrorRecord"
        }

        It "does not strip ANSI from ErrorRecord messages (e.g. coloured stderr from rustc/clang)" {
            $result = & $script `
                -Command      { Write-Error "`e[31mred error`e[0m" } `
                -ProcessLine  { param($line, $state) $line.Exception.Message } `
                -RenderResult { param($state) } `
                -StripAnsi

            $result | Should -Match '\x1B\['
        }
    }
}
