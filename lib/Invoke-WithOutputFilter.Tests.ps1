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
            -ProcessLine  { param($line, $state) "[$($line.line)]" } `
            -RenderResult { param($state) }

        $result | Should -HaveCount 2
        $result[0] | Should -Be "[line1]"
        $result[1] | Should -Be "[line2]"
    }

    It "RenderResult output appears after live output" {
        $result = & $script `
            -Command      { "a" } `
            -ProcessLine  { param($line, $state) $line.line } `
            -RenderResult { param($state) "DONE" }

        $result | Should -HaveCount 2
        $result[0] | Should -Be "a"
        $result[1] | Should -Be "DONE"
    }

    It "delivers Write-Error output to ProcessLine with .object as ErrorRecord" {
        $result = & $script `
            -Command      { Write-Error "oops" } `
            -ProcessLine  { param($line, $state) $line.object.GetType().Name } `
            -RenderResult { param($state) }

        $result | Should -Be "ErrorRecord"
    }

    It "delivers Write-Output to ProcessLine with .object as String" {
        $result = & $script `
            -Command      { Write-Output "hello" } `
            -ProcessLine  { param($line, $state) $line.object.GetType().Name } `
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

    It "passes a thrown exception through ProcessLine with .object as ErrorRecord" {
        $initialState = @{ exceptionSeen = $false }
        try {
            & $script `
                -Command      { throw "crash" } `
                -ProcessLine  { param($line, $state)
                    if ($line.object -is [System.Management.Automation.ErrorRecord]) { $state.exceptionSeen = $true }
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

    Context "item wrapping protocol" {
        It "wraps every item as {line, object, noNewLine}" {
            $result = & $script `
                -Command      { "hello" } `
                -ProcessLine  { param($line, $state)
                    $hasLine     = $null -ne $line.PSObject.Properties['line']
                    $hasObject   = $null -ne $line.PSObject.Properties['object']
                    $hasNoNL     = $null -ne $line.PSObject.Properties['noNewLine']
                    "$hasLine,$hasObject,$hasNoNL" } `
                -RenderResult { param($state) }

            $result | Should -Be "True,True,True"
        }

        It "always strips ANSI codes from .line" {
            $result = & $script `
                -Command      { "`e[32mhello`e[0m" } `
                -ProcessLine  { param($line, $state) $line.line } `
                -RenderResult { param($state) }

            $result | Should -Be "hello"
        }

        It "preserves ANSI codes in .object for Write-Output strings" {
            $result = & $script `
                -Command      { "`e[32mhello`e[0m" } `
                -ProcessLine  { param($line, $state) $line.object } `
                -RenderResult { param($state) }

            $result | Should -Match '\x1B\['
        }

        It "noNewLine is false for Write-Output" {
            $result = & $script `
                -Command      { "hello" } `
                -ProcessLine  { param($line, $state) $line.noNewLine.ToString() } `
                -RenderResult { param($state) }

            $result | Should -Be "False"
        }

        It "wraps ErrorRecord in {line, object} with stripped message in .line" {
            $result = & $script `
                -Command      { Write-Error "oops" } `
                -ProcessLine  { param($line, $state) "$($line.line)|$($line.object.GetType().Name)" } `
                -RenderResult { param($state) }

            $result | Should -Be "oops|ErrorRecord"
        }

        It "preserves ANSI codes in ErrorRecord .object, strips them from .line" {
            $result = & $script `
                -Command      { Write-Error "`e[31mred error`e[0m" } `
                -ProcessLine  { param($line, $state) "$($line.line)|$($line.object.Exception.Message)" } `
                -RenderResult { param($state) }

            ($result -split '\|')[0] | Should -Not -Match '\x1B\['
            ($result -split '\|')[1] | Should -Match '\x1B\['
        }

        It "wraps Write-Host as InformationRecord with noNewLine=false" {
            $result = & $script `
                -Command      { Write-Host "hello" 6>&1 } `
                -ProcessLine  { param($line, $state) "$($line.line)|$($line.noNewLine)|$($line.object.GetType().Name)" } `
                -RenderResult { param($state) }

            $result | Should -Be "hello|False|InformationRecord"
        }

        It "wraps Write-Host -NoNewLine with noNewLine=true" {
            $result = & $script `
                -Command      { Write-Host "hello" -NoNewLine 6>&1 } `
                -ProcessLine  { param($line, $state) "$($line.line)|$($line.noNewLine)" } `
                -RenderResult { param($state) }

            $result | Should -Be "hello|True"
        }

        It "wraps Write-Information with .object as InformationRecord preserving MessageData" {
            $result = & $script `
                -Command      { Write-Information "info-msg" 6>&1 } `
                -ProcessLine  { param($line, $state) "$($line.line)|$($line.object.MessageData)" } `
                -RenderResult { param($state) }

            $result | Should -Be "info-msg|info-msg"
        }

        It "detects noNewLine=true from a deserialized HostInformationMessage (as produced by background jobs)" {
            $job = Start-Job { Write-Host "hello" -NoNewLine }
            Wait-Job $job | Out-Null
            $deserializedRecord = @($job.ChildJobs[0].Information.ReadAll())[0]
            Remove-Job $job -Force

            $result = & $script `
                -Command      { $deserializedRecord } `
                -ProcessLine  { param($line, $state) "$($line.line)|$($line.noNewLine)" } `
                -RenderResult { param($state) }

            $result | Should -Be "hello|True"
        }
    }
}
