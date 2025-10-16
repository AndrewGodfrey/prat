param ([string] $nameMatch)
return ,@(
    Get-CimInstance Win32_Process | 
    ? { $_.Name -like $nameMatch } | 
    % { @{ Id=$_.ProcessId; ProcessName=$_.ProcessName; CommandLine=$_.CommandLine } }
    )
# OmitFromCoverageReport: a unit test would just restate it - this is a wrapper for Windows-specific crud