echo "daily_test.ps1 last ran at: $(Get-Date)" | Out-file -encoding UTF8 $home\prat\auto\log\test_schtask.txt
throw "test failure" # This failure doesn't appear anywhere that I can see.

# OmitFromCoverageReport: a unit test would just restate it