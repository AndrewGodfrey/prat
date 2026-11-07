echo "daily_test.ps1 last ran at: $(Get-Date)" | Out-file -encoding UTF8 $home\prat\auto\log\test_schtask.txt
# Left unreported on purpose: wrapping this always-failing test task would alert at every shell start.
# Other tasks should run their body under Invoke-ReportedScheduledTask (scheduledTaskResults.ps1), as
# daily_cleanManagedDirectories.ps1 does, so a new shell warns about this kind of failure.
throw "test failure"

# OmitFromCoverageReport: a unit test would just restate it