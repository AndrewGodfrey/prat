param ([string] $nameMatch)
return ,@(
    Get-CimInstance Win32_Process | 
    ? { $_.Name -like $nameMatch } | 
    % { [pscustomobject]@{ Id=$_.ProcessId; ProcessName=$_.Name; CommandLine=$_.CommandLine } }
    )
# OmitFromCoverageReport: a unit test would just restate it - this is a wrapper for Windows-specific crud