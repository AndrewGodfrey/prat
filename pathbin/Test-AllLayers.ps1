# .SYNOPSIS
# Runs every installed codebase layer's tests concurrently (one Start-Job per layer, all launched
# at once) and prints a merged summary once every layer has finished.
#
# Deliberately dumb: it does not need the output multiplexer (later/testOutputMultiplexer.md) —
# each layer's detail is deferred until every layer has landed, rather than interleaved live.
#
# Exit code: 0 = every non-skipped layer completed with zero failures; 1 = a layer reported test
# failures and no layer was fatal; 2 = a layer was fatal (job Failed, timed out, or Completed with
# no result) — 2 wins when both occur, since a fatal layer means the harness itself broke, not
# that tests are red.
#
# Recommended alias: ta

param([switch] $NoCoverage)

# Make this runnable from a harness that launches `pwsh -NoProfile` (e.g. an agent tool),
# where the prat profile — and functions like Get-PratProject — aren't loaded.
. "$PSScriptRoot\..\lib\profile\Initialize-PratScriptEnvironment.ps1"

$deadlineMinutes = 10

# Mock seam: the only piece of Start-Job orchestration under test. Everything downstream (waiting,
# classification, receive-ordering, Remove-Job) stays in the script body, so tests can observe it.
function Start-LayerTestJob($Layer, [switch] $NoCoverage) {
    Start-Job -Name $Layer.Name -ScriptBlock {
        param($TestScript, $LayerPath, $NoCoverage)
        & $TestScript $LayerPath -PassThru -NoCoverage:$NoCoverage
    } -ArgumentList "$PSScriptRoot/Test-Codebase.ps1", $Layer.Path, ([bool]$NoCoverage)
}

function getRetention() { & (Resolve-PratLibFile "lib/Get-TestRunRetention.ps1") }

# .SYNOPSIS
# A layer's own result: its job's Output hashtable, when the job is Completed and Output holds
# one. Anything else (Failed, Stopped, Completed-but-empty) synthesises a FatalError instead of
# contributing nothing, naming the reason from JobStateInfo.Reason where there is one.
function Get-LayerSummary($LayerName, $Job) {
    if ($Job.State -eq 'Completed' -and @($Job.ChildJobs[0].Output).Count -ge 1) {
        return @($Job.ChildJobs[0].Output)[0]
    }
    $reason = $Job.ChildJobs[0].JobStateInfo.Reason.Message
    $why = if ($reason) { $reason } else { "produced no result" }
    return @{ FatalError = "${LayerName}: $why" }
}

# .SYNOPSIS
# The per-layer line printed as each layer lands — not Write-TestRunResult, which would rewrite
# that layer's own summary.txt with Elapsed = 0 (see "What the coordinator renders" in the plan).
function Format-LayerLine($LayerName, $Summary) {
    if ($Summary.FatalError) {
        return Format-AnsiText "${LayerName}: $($Summary.FatalError)" 91
    }
    $failed    = $Summary.Failed ?? 0
    $threshold = $Summary.FailureThreshold ?? 5
    $color     = if ($failed -gt 0) { if ($failed -ge $threshold) { 91 } else { 93 } } else { 92 }
    return Format-AnsiText "${LayerName}: Passed: $($Summary.Passed), Failed: $failed" $color
}

if ($MyInvocation.InvocationName -ne '.') {
    $startTime = [DateTimeOffset]::UtcNow
    $deadline  = (Get-Date).AddMinutes($deadlineMinutes)

    $layers  = @(Get-CodebaseLayers)
    $records = @()

    # Resolve each layer's test command before launching anything — a layer with none is not a
    # failure, it just has nothing to run.
    foreach ($layer in $layers) {
        $project    = Get-PratProject $layer.Path
        $testScript = if ($project) { Resolve-ProjectTestScript $project } else { $null }
        if (-not $testScript) {
            $reason = if ($project) { "declares no test command" } else { "not a registered project" }
            Write-Host "$($layer.Name): skipped ($reason)"
            continue
        }
        $job = Start-LayerTestJob $layer -NoCoverage:$NoCoverage
        $records += @{ Layer = $layer; Job = $job; Summary = $null }
    }

    try {
        $pending = @($records)
        while ($pending.Count -gt 0) {
            $remainingSec = [Math]::Max(0, [int]($deadline - (Get-Date)).TotalSeconds)
            # -Name (not -Job): -Job is typed [Job[]] and Pester's cmdlet mock proxy enforces that
            # type even under Mock, rejecting the plain test-double objects the tests supply. Every
            # launched job has a unique -Name (assigned in Start-LayerTestJob), so identifying by
            # name works the same in production and gives tests a plain string to match on.
            $doneJob = Wait-Job -Name @($pending | ForEach-Object { $_.Layer.Name }) -Any -Timeout $remainingSec

            if ($null -eq $doneJob) {
                foreach ($r in $pending) {
                    $elapsedSec = [int]([DateTimeOffset]::UtcNow - $startTime).TotalSeconds
                    $r.Summary = @{ FatalError = "$($r.Layer.Name): timed out after ${elapsedSec}s" }
                    Format-LayerLine $r.Layer.Name $r.Summary
                }
                $pending = @()
                break
            }

            $record = $pending | Where-Object { $_.Layer.Name -eq $doneJob.Name } | Select-Object -First 1
            $record.Summary = Get-LayerSummary $record.Layer.Name $record.Job
            Format-LayerLine $record.Layer.Name $record.Summary
            $pending = @($pending | Where-Object { $_.Layer.Name -ne $doneJob.Name })
        }

        # Detail replay happens only after every layer has landed: clean layers first (in
        # Get-CodebaseLayers order), then failing/fatal ones, so failure detail is the last thing
        # on screen. Each Receive-Job is piped to Out-Null — its result hashtable already went
        # into $record.Summary above; this call exists only for the host-side text replay
        # (Invoke-TestWithSummary's -PassThru live failure detail, which never touches the
        # pipeline — see the plan's "Verified mechanics").
        $clean   = @($records | Where-Object { -not $_.Summary.FatalError -and (($_.Summary.Failed ?? 0) -eq 0) })
        $unclean = @($records | Where-Object {      $_.Summary.FatalError -or  (($_.Summary.Failed ?? 0) -gt 0) })
        foreach ($record in @($clean) + @($unclean)) {
            Write-Host "--- $($record.Layer.Name) ---"
            # A Failed job's Receive-Job re-emits a duplicate error record (the reason is already
            # captured in $record.Summary), and would throw under $ErrorActionPreference = 'Stop'.
            try { Receive-Job -Name $record.Layer.Name -ErrorAction SilentlyContinue | Out-Null } catch {}
        }
    } finally {
        # ta runs in the user's interactive session, so leaked jobs would accumulate there, and a
        # Ctrl-C during the wait would otherwise strand whatever is still running.
        if ($records.Count -gt 0) {
            Remove-Job -Name @($records | ForEach-Object { $_.Layer.Name }) -Force
        }
    }

    $merged   = Merge-TestSummary (@($records | ForEach-Object { $_.Summary })) ([TimeSpan]::Zero) -PassThru
    $topLayer = $layers[0]
    $runDir   = Initialize-TestRunDir -OutputDir "$($topLayer.Path)/auto/testRuns/allLayers" -Retention (getRetention)
    $elapsed  = [DateTimeOffset]::UtcNow - $startTime

    Write-TestRunResult `
        -CoverageData     $merged.CoverageData `
        -Passed           $merged.Passed `
        -Failed           $merged.Failed `
        -Elapsed          $elapsed `
        -FailuresSeen     $merged.FailuresSeen `
        -FailureThreshold $merged.FailureThreshold `
        -RunDir           $runDir `
        -FailureLogs      $merged.FailureLogs `
        -FatalError       $merged.FatalError

    $exitCode = if ($merged.FatalError) { 2 } elseif (($merged.Failed ?? 0) -gt 0) { 1 } else { 0 }
    exit $exitCode
}