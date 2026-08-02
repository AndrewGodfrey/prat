BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1" -Force
    $script = (Resolve-Path "$PSScriptRoot\..\Test-AllLayers.ps1").Path

    # Builds a fake job object shaped like a real PowerShell Job: .Name, .State, and
    # .ChildJobs[0].Output / .ChildJobs[0].JobStateInfo.Reason.Message.
    function makeJob([string] $State, $Output = @(), [string] $ReasonMessage = $null, [string] $Name = 'layer') {
        $reason = if ($ReasonMessage) { [PSCustomObject]@{ Message = $ReasonMessage } } else { $null }
        [PSCustomObject]@{
            Name      = $Name
            State     = $State
            ChildJobs = @([PSCustomObject]@{
                Output       = @($Output)
                JobStateInfo = [PSCustomObject]@{ Reason = $reason }
            })
        }
    }
}

Describe "Test-AllLayers" {
    BeforeEach {
        Mock Write-Host {}

        function Get-CodebaseLayers {}
        Mock Get-CodebaseLayers {
            @(
                @{ Name = 'a'; Path = 'C:/fake/a' }
                @{ Name = 'b'; Path = 'C:/fake/b' }
            )
        }

        # Every layer resolves to a registered project with a test command, by default.
        Mock Get-PratProject { @{ id = (Split-Path $Location -Leaf); root = $Location } }
        Mock Resolve-ProjectTestScript { "C:/fake/testscript.ps1" }

        # Launch seam: every layer's job completes immediately with 1 passed, 0 failed.
        function Start-LayerTestJob {}
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Completed' -Output @(@{ Passed = 1; Failed = 0; FailureThreshold = 5 }) -Name $Layer.Name
        }

        # Wait-Job -Any over the pending set: hand back whichever job is first in the array,
        # draining the pending set one at a time regardless of real completion order (final
        # receive-ordering below is independent of this order, so this is a sufficient fake).
        Mock Wait-Job { param($Name) [PSCustomObject]@{ Name = $Name[0] } }
        Mock Receive-Job {}
        Mock Remove-Job {}
        # getRetention's own body resolves via the (also mocked, for the layers above) Get-CodebaseLayers,
        # so it can't run for real here without hitting fake layer paths — same seam as Start-LayerTestJob.
        function getRetention {}
        Mock getRetention { 10 }

        Mock Initialize-TestRunDir { 'C:/fake/rundir' }
        Mock Write-TestRunResult {}
    }

    It "merges Passed/Failed across layers" {
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Completed' -Output @(@{ Passed = 4; Failed = 1; FailureThreshold = 5 }) -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'a' }
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Completed' -Output @(@{ Passed = 2; Failed = 0; FailureThreshold = 5 }) -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'b' }

        & $script -NoCoverage

        Should -Invoke Write-TestRunResult -ParameterFilter { $Passed -eq 6 -and $Failed -eq 1 }
    }

    It "prints a per-layer summary line for every layer" {
        $output = & $script -NoCoverage

        $output -join "`n" | Should -Match 'a: Passed: 1, Failed: 0'
        $output -join "`n" | Should -Match 'b: Passed: 1, Failed: 0'
    }

    It "exits 0 when every layer is clean" {
        & $script -NoCoverage

        $LASTEXITCODE | Should -Be 0
    }

    It "exits 1 when a layer has failures and no layer is fatal" {
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            # Failed >= FailureThreshold, so this also exercises Format-LayerLine's red-vs-yellow branch.
            makeJob -State 'Completed' -Output @(@{ Passed = 0; Failed = 10; FailureThreshold = 5 }) -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'a' }

        & $script -NoCoverage

        $LASTEXITCODE | Should -Be 1
    }

    It "exits 2 when a layer is fatal, even if none have failures" {
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Failed' -ReasonMessage 'boom' -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'a' }

        & $script -NoCoverage

        $LASTEXITCODE | Should -Be 2
    }

    It "exits 2 when both a layer is fatal and another has failures (2 wins)" {
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Failed' -ReasonMessage 'boom' -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'a' }
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Completed' -Output @(@{ Passed = 0; Failed = 3; FailureThreshold = 5 }) -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'b' }

        & $script -NoCoverage

        $LASTEXITCODE | Should -Be 2
    }

    It "does not swallow a FatalError in one layer behind two passing ones" {
        Mock Get-CodebaseLayers {
            @(
                @{ Name = 'a'; Path = 'C:/fake/a' }
                @{ Name = 'b'; Path = 'C:/fake/b' }
                @{ Name = 'c'; Path = 'C:/fake/c' }
            )
        }
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Failed' -ReasonMessage 'boom' -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'c' }

        & $script -NoCoverage

        Should -Invoke Write-TestRunResult -ParameterFilter { $FatalError -match 'c: boom' }
    }

    It "surfaces a Failed job's JobStateInfo.Reason.Message as the FatalError" {
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Failed' -ReasonMessage 'exit code: 1' -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'a' }

        & $script -NoCoverage

        Should -Invoke Write-TestRunResult -ParameterFilter { $FatalError -match 'a: exit code: 1' }
    }

    It "treats a Completed job with no Output as a FatalError ('produced no result')" {
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Completed' -Output @() -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'a' }

        & $script -NoCoverage

        Should -Invoke Write-TestRunResult -ParameterFilter { $FatalError -match 'a: produced no result' }
    }

    It "treats a timed-out layer as a FatalError" {
        Mock Wait-Job { $null }

        & $script -NoCoverage

        Should -Invoke Write-TestRunResult -ParameterFilter { $FatalError -match 'timed out after' }
        $LASTEXITCODE | Should -Be 2
    }

    Context "receive ordering" {
        It "receives failing layers after clean ones" {
            # Captured via a plain closed-over variable, not $script: — $script: inside a Mock
            # scriptblock resolves against whichever .ps1 file is executing when the mock fires,
            # not this test file, so it comes back $null when the call crosses into another script.
            $receiveOrder = [System.Collections.Generic.List[string]]::new()
            Mock Receive-Job { param($Name) $receiveOrder.Add($Name[0]) }
            Mock Start-LayerTestJob {
                param($Layer, [switch] $NoCoverage)
                makeJob -State 'Failed' -ReasonMessage 'boom' -Name $Layer.Name
            } -ParameterFilter { $Layer.Name -eq 'a' }
            Mock Start-LayerTestJob {
                param($Layer, [switch] $NoCoverage)
                makeJob -State 'Completed' -Output @(@{ Passed = 1; Failed = 0; FailureThreshold = 5 }) -Name $Layer.Name
            } -ParameterFilter { $Layer.Name -eq 'b' }

            & $script -NoCoverage

            $receiveOrder.IndexOf('b') | Should -BeLessThan $receiveOrder.IndexOf('a')
        }
    }

    Context "skipped layers" {
        It "reports a layer with no registered project as skipped, without launching a job" {
            Mock Get-PratProject { $null } -ParameterFilter { $Location -eq 'C:/fake/a' }

            & $script -NoCoverage

            Should -Invoke Write-Host -ParameterFilter { $Object -match 'a: skipped \(not a registered project\)' }
            Should -Invoke Start-LayerTestJob -Times 0 -ParameterFilter { $Layer.Name -eq 'a' }
        }

        It "reports a layer with no test command as skipped, without launching a job" {
            Mock Resolve-ProjectTestScript { $null } -ParameterFilter { $Project.root -eq 'C:/fake/a' }

            & $script -NoCoverage

            Should -Invoke Write-Host -ParameterFilter { $Object -match 'a: skipped \(declares no test command\)' }
            Should -Invoke Start-LayerTestJob -Times 0 -ParameterFilter { $Layer.Name -eq 'a' }
        }

        It "excludes a skipped layer from the merge and the exit code" {
            Mock Resolve-ProjectTestScript { $null } -ParameterFilter { $Project.root -eq 'C:/fake/a' }

            & $script -NoCoverage

            Should -Invoke Write-TestRunResult -ParameterFilter { $Passed -eq 1 -and $Failed -eq 0 -and -not $FatalError }
            $LASTEXITCODE | Should -Be 0
        }
    }

    It "removes jobs even when the run throws" {
        Mock Wait-Job { throw "boom" }

        { & $script -NoCoverage } | Should -Throw

        Should -Invoke Remove-Job
    }

    It "does not leak Receive-Job's output onto the pipeline" {
        Mock Receive-Job { @{ Marker = 'leak' } }

        $output = & $script -NoCoverage

        $output | Where-Object { $_.Marker -eq 'leak' } | Should -BeNullOrEmpty
    }

    It "calls Write-TestRunResult once with ta's own RunDir, a non-zero Elapsed, and FatalError/FailureThreshold populated" {
        Mock Start-LayerTestJob {
            param($Layer, [switch] $NoCoverage)
            makeJob -State 'Failed' -ReasonMessage 'boom' -Name $Layer.Name
        } -ParameterFilter { $Layer.Name -eq 'a' }

        & $script -NoCoverage

        Should -Invoke Write-TestRunResult -Exactly 1 -ParameterFilter {
            $RunDir -eq 'C:/fake/rundir' -and $Elapsed -gt [TimeSpan]::Zero -and
            $FatalError -match 'a: boom' -and $FailureThreshold -ge 5
        }
    }
}
