param ([string] $nameMatch)
Get-CimInstance Win32_Process | ? { $_.Name -like $nameMatch } | % { @{ Id=$_.ProcessId; ProcessName=$_.ProcessName; CommandLine=$_.CommandLine } }

