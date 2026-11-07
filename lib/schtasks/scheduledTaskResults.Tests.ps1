BeforeAll {
    . "$PSScriptRoot/scheduledTaskResults.ps1"
    $script:now = [datetime] '2026-11-05T09:00:00'
}

Describe "scheduledTaskResults" {
    It "alerts on a task whose last result is a failure" {
        $dir = "TestDrive:\failure"
        Save-ScheduledTaskResult 'myTask' Failure 'boom' -ResultDir $dir -Now $script:now.AddHours(-1)

        Get-ScheduledTaskAlerts -ResultDir $dir -Now $script:now | Should -Be "'myTask' failed 11/05 08:00: boom"
    }

    It "clears the alert once the task next succeeds" {
        $dir = "TestDrive:\recovered"
        Save-ScheduledTaskResult 'myTask' Failure 'boom' -ResultDir $dir -Now $script:now.AddHours(-2)
        Save-ScheduledTaskResult 'myTask' Success 'ok' -ResultDir $dir -Now $script:now.AddHours(-1)

        Get-ScheduledTaskAlerts -ResultDir $dir -Now $script:now | Should -BeNullOrEmpty
    }

    It "alerts on a task that hasn't reported within the stale period" {
        $dir = "TestDrive:\stale"
        Save-ScheduledTaskResult 'fresh' Success 'ok' -ResultDir $dir -Now $script:now.AddDays(-2.9)
        Save-ScheduledTaskResult 'stale' Success 'ok' -ResultDir $dir -Now $script:now.AddDays(-3.1)

        Get-ScheduledTaskAlerts -ResultDir $dir -Now $script:now | Should -Be "'stale' hasn't reported since 11/02 06:36"
    }

    It "reports each alerting task" {
        $dir = "TestDrive:\several"
        Save-ScheduledTaskResult 'a' Failure 'x' -ResultDir $dir -Now $script:now
        Save-ScheduledTaskResult 'b' Success 'ok' -ResultDir $dir -Now $script:now
        Save-ScheduledTaskResult 'c' Failure 'y' -ResultDir $dir -Now $script:now

        (Get-ScheduledTaskAlerts -ResultDir $dir -Now $script:now) -join '|' | Should -Be "'a' failed 11/05 09:00: x|'c' failed 11/05 09:00: y"
    }

    It "shows only the first line of a long failure message, truncated" {
        $dir = "TestDrive:\long"
        Save-ScheduledTaskResult 'myTask' Failure "$('x' * 300)`nsecond line" -ResultDir $dir -Now $script:now

        $alert = Get-ScheduledTaskAlerts -ResultDir $dir -Now $script:now
        $alert | Should -Not -Match 'second line'
        $alert | Should -Match '^''myTask'' failed 11/05 09:00: x{117}\.\.\.$'
    }

    It "alerts rather than throws on an unreadable result file" {
        $dir = "TestDrive:\corrupt"
        New-Item "$dir\myTask.json" -Value '{ not json' -Force | Out-Null

        Get-ScheduledTaskAlerts -ResultDir $dir -Now $script:now | Should -Be "'myTask' has an unreadable result file"
    }

    It "returns nothing when no task has reported" {
        Get-ScheduledTaskAlerts -ResultDir "TestDrive:\none" -Now $script:now | Should -BeNullOrEmpty
    }

    It "rejects a task name that could escape the result dir" {
        { Save-ScheduledTaskResult '..\evil' Failure 'x' -ResultDir "TestDrive:\evil\inner" } | Should -Throw '*Invalid task name*'
        Test-Path "TestDrive:\evil\evil.json" | Should -BeFalse
    }

    It "is recorded by Report-ScheduledTaskResult" {
        $dir = (New-Item -ItemType Directory "TestDrive:\report").FullName
        & "$PSScriptRoot/../../pathbin/Report-ScheduledTaskResult.ps1" -TaskName 'myTask' -Status Failure -Message 'boom' -ResultDir $dir 6> $null

        Get-ScheduledTaskAlerts -ResultDir $dir | Should -Match "^'myTask' failed .*: boom$"
    }
    Context "Invoke-ReportedScheduledTask" {
        It "records success when the task's script block completes" {
            $dir = "TestDrive:\reportedOk"
            $script:ran = $false
            Invoke-ReportedScheduledTask 'myTask' { $script:ran = $true } -ResultDir $dir 6> $null

            $script:ran | Should -BeTrue
            (Get-Content "$dir\myTask.json" -Raw | ConvertFrom-Json).status | Should -Be 'Success'
        }

        It "records failure with the error, and rethrows, when the script block throws" {
            $dir = "TestDrive:\reportedFail"

            { Invoke-ReportedScheduledTask 'myTask' { throw 'boom' } -ResultDir $dir 6> $null } | Should -Throw 'boom'
            Get-ScheduledTaskAlerts -ResultDir $dir | Should -Match "^'myTask' failed .*: boom$"
        }
    }

    Context "Write-ScheduledTaskAlerts" {
        It "writes each alert, and where the results are, in yellow" {
            $dir = "TestDrive:\written"
            Save-ScheduledTaskResult 'myTask' Failure 'boom' -ResultDir $dir -Now $script:now
            Mock Write-Host {}

            Write-ScheduledTaskAlerts -ResultDir $dir -Now $script:now

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { ($ForegroundColor -eq 'Yellow') -and ("$Object" -like "*'myTask' failed 11/05 09:00: boom*") }
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { ($ForegroundColor -eq 'Yellow') -and ("$Object" -like "*next succeeds*delete*$dir*") }
        }

        It "writes nothing when there are no alerts" {
            $dir = "TestDrive:\quiet"
            Save-ScheduledTaskResult 'myTask' Success 'ok' -ResultDir $dir -Now $script:now
            Mock Write-Host {}

            Write-ScheduledTaskAlerts -ResultDir $dir -Now $script:now

            Should -Invoke Write-Host -Times 0
        }
    }
    Context "Remove-ScheduledTaskResult" {
        It "removes the task's result, so it no longer alerts, and returns true" {
            $dir = "TestDrive:\removed"
            Save-ScheduledTaskResult 'myTask' Failure 'boom' -ResultDir $dir -Now $script:now
            Save-ScheduledTaskResult 'other' Failure 'x' -ResultDir $dir -Now $script:now

            Remove-ScheduledTaskResult 'myTask' -ResultDir $dir | Should -BeTrue
            Get-ScheduledTaskAlerts -ResultDir $dir -Now $script:now | Should -Be "'other' failed 11/05 09:00: x"
        }

        It "returns false when the task has no result" {
            Remove-ScheduledTaskResult 'myTask' -ResultDir "TestDrive:\noResult" | Should -BeFalse
        }

        It "rejects a task name that could escape the result dir" {
            { Remove-ScheduledTaskResult '..\evil' -ResultDir "TestDrive:\evil2\inner" } | Should -Throw '*Invalid task name*'
        }
    }
}
